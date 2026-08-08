import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/models/novel.dart';
import '../../../data/models/novel_chapter.dart';
import '../../../data/models/reader_settings.dart';
import '../../../shared/widgets/app_snackbar.dart';
import 'widgets/chapter_list_sheet.dart';
import 'widgets/novel_paginator.dart';
import 'widgets/reader_controls.dart';
import 'widgets/reader_placeholders.dart';
import 'widgets/reader_settings_sheet.dart';

/// 沉浸式阅读页（核心）
///
/// 支持滚动 / 翻页两种模式，进度按 0..1 记忆，背景与文字色取自 AppColors。
class NovelReaderPage extends ConsumerStatefulWidget {
  final int novelId;
  final int initialChapterIndex;

  const NovelReaderPage({
    super.key,
    required this.novelId,
    this.initialChapterIndex = 0,
  });

  @override
  ConsumerState<NovelReaderPage> createState() => _NovelReaderPageState();
}

class _NovelReaderPageState extends ConsumerState<NovelReaderPage> {
  late final ScrollController _scrollController;
  late final PageController _pageController;

  int _currentChapterIndex = 0;
  bool _showToolbars = true;
  bool _restored = false;
  List<String> _pages = [];
  Novel? _novel;
  ReaderSettings? _settings;
  Timer? _saveTimer;

  // 按需抓取正文状态（正文为空时抓取，避免预取不足导致整章空白）
  int? _loadingChapterId;
  bool _chapterLoadFailed = false;
  String? _chapterLoadMessage;

  // 分页缓存（避免每次 rebuild 重复计算 TextPainter 布局）
  String? _paginateContent;
  double? _paginateWidth;
  double? _paginateHeight;
  double? _paginateFontSize;
  double? _paginateLineHeight;

  // 滚动模式连续阅读：已追加渲染的章节 + 每章起始滚动偏移（用于章内进度换算）
  List<NovelChapter> _scrollChapters = [];
  List<double> _chapterBases = [];
  bool _scrollFetchingNext = false;

  // 翻页模式自动翻章：到达章末“下一章”页时的加载状态
  bool _autoAdvancing = false;
  bool _autoAdvanceFailed = false;

  // 最近一次构建的章节列表（滚动监听里做自动追加时需要）
  List<NovelChapter> _latestChapters = [];

  // 连续阅读列表构建时的字号/行距（变化时重置高度基准）
  double? _scrollFontSize;
  double? _scrollLineHeight;

  @override
  void initState() {
    super.initState();
    // 进入沉浸式阅读
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _currentChapterIndex = widget.initialChapterIndex;
    _scrollController = ScrollController()..addListener(_onScroll);
    _pageController = PageController();
    // 确保存在默认设置
    ref.read(readerSettingsRepositoryProvider).getOrCreate();
    // 屏幕常亮：按阅读设置的 keepScreenOn 启用/释放唤醒锁（设置变化时同步）
    ref.listenManual<AsyncValue<ReaderSettings?>>(
      readerSettingsProvider,
      (prev, next) {
        final keep = next.valueOrNull?.keepScreenOn ?? false;
        if (keep) {
          WakelockPlus.enable();
        } else {
          WakelockPlus.disable();
        }
      },
      fireImmediately: true,
    );
    // 读取小说初始进度用于恢复
    ref.read(novelRepositoryProvider).getById(widget.novelId).then((n) {
      if (!mounted) return;
      _novel = n;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    // 释放屏幕常亮（恢复系统自动锁屏）
    WakelockPlus.disable();
    // 滚动模式连续阅读时，按视口当前所在章节保存进度（先于控制器 dispose 计算）
    int chapterIndex = _currentChapterIndex;
    double ratio = _currentRatio();
    if (_settings?.pageMode == 0 && _scrollController.hasClients) {
      final (idx, r) = _computeScrollProgress();
      chapterIndex = idx;
      ratio = r;
    }
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
    // 末次保存进度（dispose 中无法 await，捕获异常避免未处理错误冒泡）
    unawaited(
      ref
          .read(novelRepositoryProvider)
          .updateProgress(widget.novelId, chapterIndex, ratio)
          .then<void>((_) {}, onError: (Object e) {
        debugPrint('[NovelReaderPage] 退出时保存进度失败: $e');
      }),
    );
    // 恢复系统 UI，否则返回后系统栏丢失
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }

  // ──────── 进度记忆 ────────

  double _currentRatio() {
    if (_settings?.pageMode == 1) {
      if (_pages.isEmpty) return 0.0;
      final page = _pageController.page ?? 0;
      final denom = _pages.length - 1;
      return denom <= 0 ? 0.0 : (page / denom).clamp(0.0, 1.0);
    }
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      // 滚动模式（含连续阅读）：按视口所在章节换算章内进度
      return _computeScrollProgress().$2;
    }
    return 0.0;
  }

  void _saveProgress(double ratio, {int? chapterIndex}) {
    if (!mounted) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      ref.read(novelRepositoryProvider).updateProgress(
            widget.novelId,
            chapterIndex ?? _currentChapterIndex,
            ratio,
          );
    });
  }

  void _onScroll() {
    if (!_restored || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    // 连续阅读：接近列表底部时自动追加下一章
    if (pos.maxScrollExtent - pos.pixels < _appendThreshold) {
      _maybeAppendNextChapter();
    }
    // 按视口所在章节保存进度（连续阅读跨章时进度会指向新章节）
    final (idx, ratio) = _computeScrollProgress();
    if (idx != _currentChapterIndex) {
      setState(() => _currentChapterIndex = idx);
    }
    _saveProgress(ratio);
  }

  void _onPageChanged(int page) {
    if (_pages.isEmpty) return;
    final denom = _pages.length - 1;
    final ratio = denom <= 0 ? 0.0 : (page / denom).clamp(0.0, 1.0);
    _saveProgress(ratio);
  }

  // ──────── 章节切换 ────────

  void _goToChapter(int index, List<NovelChapter> chapters) {
    // 传入的 chapters 用于校验范围；chapters 为空说明没有章节可跳
    final clamped = chapters.isEmpty ? 0 : index.clamp(0, chapters.length - 1);
    setState(() {
      _currentChapterIndex = clamped;
      // 切章后重新定位/恢复（由 _maybeRestore 统一在滚动/翻页两种模式下执行）
      _restored = false;
      // 重置按需抓取状态，为当前章重新评估
      _loadingChapterId = null;
      _chapterLoadFailed = false;
      _chapterLoadMessage = null;
      if (_settings?.pageMode == 0) {
        // 滚动模式：重置连续阅读列表，仅渲染目标章
        _scrollChapters = chapters.isEmpty ? [] : [chapters[clamped]];
        _chapterBases = [0.0];
        _scrollFetchingNext = false;
      }
      _autoAdvancing = false;
      _autoAdvanceFailed = false;
    });
    _saveProgress(0.0);
  }

  // ──────── 点击分区交互 ────────

  void _handleRegionTap(double dx, double width) {
    final third = width / 3;
    if (dx < third) {
      _previous();
    } else if (dx > 2 * third) {
      _next();
    } else {
      setState(() => _showToolbars = !_showToolbars);
    }
  }

  void _previous() {
    if (_settings?.pageMode == 1) {
      if (_pageController.page != null && _pageController.page! > 0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } else if (_scrollController.hasClients) {
      final h = _scrollController.position.viewportDimension;
      _scrollController.animateTo(
        (_scrollController.offset - h).clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  void _next() {
    if (_settings?.pageMode == 1) {
      final page = _pageController.page;
      if (page == null) return;
      final lastRealPage = _pages.length - 1;
      if (page < lastRealPage) {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else if (_isLastChapter) {
        // 已是最后一章的最后一页
        if (mounted) AppSnackbar.show(context, '已经是最后一章');
      } else {
        // 翻到本章末尾的“下一章”哨兵页，触发自动翻章
        _pageController.nextPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    } else if (_scrollController.hasClients) {
      final h = _scrollController.position.viewportDimension;
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.animateTo(
        (_scrollController.offset + h).clamp(0.0, max),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  // ──────── 进度恢复（仅进入时一次）────────

  void _maybeRestore(ReaderSettings settings, int effectiveIndex) {
    if (_restored) return;
    if (_novel == null) return; // 等小说进度就绪后再恢复
    final restoreRatio =
        effectiveIndex == _novel!.lastChapterIndex
            ? _novel!.lastPosition
            : 0.0;
    // 由 build 的 post-frame 钩子调用，此时布局已完成，可直接定位；
    // 滚动 / 翻页两种模式都执行，保证滚动模式进度也能恢复。
    if (settings.pageMode == 1) {
      // hasClients 防御：正文为空时展示占位（无 PageView），此时不可定位
      if (_pages.isNotEmpty && _pageController.hasClients) {
        final target = (restoreRatio * _pages.length)
            .round()
            .clamp(0, _pages.length - 1);
        _pageController.jumpToPage(target);
      }
    } else if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo((restoreRatio * max).clamp(0.0, max));
    }
    // 恢复后立即保存，防止 _onScroll/_onPageChanged 未触发的场景丢进度
    _saveProgress(restoreRatio);
    if (mounted) setState(() => _restored = true);
  }

  // ──────── 正文按需抓取（预取不足的章节）────────

  /// 当前章正文为空时按需抓取并写回数据库
  ///
  /// 由 build 的 post-frame 钩子在每次进入章节时调用；内部有幂等守卫，
  /// 仅在正文为空、未在加载、未失败时真正发起网络请求。
  Future<void> _ensureChapterContent(
    List<NovelChapter> chapters,
    int index,
  ) async {
    if (index < 0 || index >= chapters.length) return;
    final chapter = chapters[index];
    if (chapter.content.isNotEmpty) return; // 已有正文，无需抓取
    if (_loadingChapterId == chapter.id) return; // 正在加载
    if (_chapterLoadFailed) return; // 等待用户手动重试

    final novel = _novel;
    if (novel == null) return; // 小说进度尚未就绪，等下一次构建重试

    final sourceKey = novel.sourceKey;
    final sourceUrl = chapter.sourceUrl;
    if (sourceKey == null || sourceUrl == null || sourceUrl.isEmpty) {
      // 本地书 / 无源站信息：无法按需抓取
      setState(() {
        _chapterLoadFailed = true;
        _chapterLoadMessage = '本章暂无内容';
      });
      return;
    }

    setState(() {
      _loadingChapterId = chapter.id;
      _chapterLoadFailed = false;
      _chapterLoadMessage = null;
    });
    try {
      final content = await ref
          .read(crawlRepositoryProvider)
          .fetchChapterContent(chapterUrl: sourceUrl, novelSourceKey: sourceKey);
      if (!mounted) return;
      if (content.isEmpty) {
        setState(() {
          _loadingChapterId = null;
          _chapterLoadFailed = true;
          _chapterLoadMessage = '本章暂无内容';
        });
        return;
      }
      // 写回数据库，触发 chaptersProvider 流刷新自动渲染
      await ref
          .read(novelChapterRepositoryProvider)
          .updateContent(widget.novelId, chapter.chapterIndex, content);
      if (!mounted) return;
      setState(() => _loadingChapterId = null);
    } catch (e) {
      debugPrint('[NovelReaderPage] 章节正文抓取失败: $e');
      if (!mounted) return;
      setState(() {
        _loadingChapterId = null;
        _chapterLoadFailed = true;
        _chapterLoadMessage = '加载失败，请重试';
      });
    }
  }

  /// 手动重试抓取当前章正文（清空失败状态，触发 post-frame 钩子重新抓取）
  void _retryChapter() {
    setState(() {
      _chapterLoadFailed = false;
      _chapterLoadMessage = null;
    });
  }

  // ──────── 自动翻章（滚动模式追加 / 翻页模式哨兵页） ────────

  /// 距列表底部多少像素内视为“读到章尾”，触发自动追加下一章
  static const double _appendThreshold = 240;

  /// 滚动模式连续阅读已装载到的最后章序号（-1 表示尚未装载）
  int get _scrollLastIndex =>
      _scrollChapters.isEmpty ? -1 : _scrollChapters.last.chapterIndex;

  /// 当前章是否为最后一章（用于自动翻章的“已是最后一章”提示）
  bool get _isLastChapter {
    final chapters = _latestChapters;
    if (chapters.isEmpty) return true;
    final effective = _currentChapterIndex.clamp(0, chapters.length - 1);
    return effective >= chapters.length - 1;
  }

  /// 计算滚动模式下视口当前所在章节及其章内进度（0..1）
  ///
  /// 连续阅读把多章内容顺序拼进同一个滚动列表；借助每章开始时的滚动偏移
  /// （_chapterBases）定位视口所在的章节，并把该章区间内的滚动位置换算成
  /// 章内比例，从而保证自动翻章后进度正确指向新章节。
  (int, double) _computeScrollProgress() {
    final pos = _scrollController.position;
    if (_scrollChapters.isEmpty ||
        _chapterBases.isEmpty ||
        pos.maxScrollExtent <= 0) {
      return (_currentChapterIndex, 0.0);
    }
    final pixels = pos.pixels;
    var listIdx = 0;
    for (var i = 0; i < _chapterBases.length; i++) {
      if (pixels >= _chapterBases[i]) {
        listIdx = i;
      } else {
        break;
      }
    }
    final base = _chapterBases[listIdx];
    final double extent;
    if (listIdx + 1 < _chapterBases.length) {
      extent = _chapterBases[listIdx + 1] - base;
    } else {
      // 最后一章：区间延伸到当前滚动上界
      extent = pos.maxScrollExtent - base;
    }
    if (extent <= 0) return (_currentChapterIndex, 0.0);
    final ratio = ((pixels - base) / extent).clamp(0.0, 1.0);
    return (_scrollChapters[listIdx].chapterIndex, ratio);
  }

  /// 确保指定章节正文已就绪（自动翻章用）
  ///
  /// 正文已在库中直接返回原实例；为空时按需抓取并写回数据库，
  /// 返回携带正文的章节实例（Isar 无对象缓存，watch 流发出的才是
  /// 新反序列化实例，因此这里手动构造，避免调用方用到旧空正文实例）。
  /// 失败（无源站 / 网络错误 / 内容为空）返回 null，由调用方提示用户。
  Future<NovelChapter?> _ensureChapterBodyReady(
    List<NovelChapter> chapters,
    int index,
  ) async {
    if (index < 0 || index >= chapters.length) return null;
    final chapter = chapters[index];
    if (chapter.content.isNotEmpty) return chapter;
    final novel = _novel;
    if (novel == null) return null;
    final sourceKey = novel.sourceKey;
    final sourceUrl = chapter.sourceUrl;
    if (sourceKey == null || sourceUrl == null || sourceUrl.isEmpty) {
      return null; // 本地书 / 无源站信息，无法按需抓取
    }
    try {
      final content = await ref
          .read(crawlRepositoryProvider)
          .fetchChapterContent(chapterUrl: sourceUrl, novelSourceKey: sourceKey);
      if (content.isEmpty) return null;
      await ref
          .read(novelChapterRepositoryProvider)
          .updateContent(widget.novelId, chapter.chapterIndex, content);
      // 构造带正文的实例（保留原 id，仅用于 UI 渲染，不写库）
      return NovelChapter()
        ..id = chapter.id
        ..novelId = chapter.novelId
        ..chapterIndex = chapter.chapterIndex
        ..title = chapter.title
        ..content = content
        ..sourceChapterId = chapter.sourceChapterId
        ..sourceUrl = chapter.sourceUrl;
    } catch (e) {
      debugPrint('[NovelReaderPage] 自动翻章正文抓取失败: $e');
      return null;
    }
  }

  /// 滚动模式连续阅读：将下一章追加到当前列表底部
  ///
  /// 由 _onScroll 在接近底部时触发；正文缺失时先按需抓取，成功后追加，
  /// 并把阅读进度指向新章节。最后一章不再追加（列表尾部显示结尾提示）。
  Future<void> _maybeAppendNextChapter() async {
    if (_settings?.pageMode != 0) return;
    if (_scrollFetchingNext) return; // 幂等守卫
    if (_scrollChapters.isEmpty) return;
    final chapters = _latestChapters;
    final nextIndex = _scrollLastIndex + 1;
    if (nextIndex >= chapters.length) return; // 已是最后一章

    _scrollFetchingNext = true;
    setState(() {}); // 列表底部显示加载占位
    final ready = await _ensureChapterBodyReady(chapters, nextIndex);
    if (!mounted) return;
    if (ready == null) {
      setState(() => _scrollFetchingNext = false);
      AppSnackbar.show(context, '下一章加载失败，请重试');
      return;
    }
    setState(() {
      _scrollFetchingNext = false;
      // 新章起始滚动偏移 = 追加前的最大滚动距离；
      // 追加带正文的实例，避免渲染到旧空正文
      final base = _scrollController.hasClients
          ? _scrollController.position.maxScrollExtent
          : 0.0;
      _scrollChapters.add(ready);
      _chapterBases.add(base);
      _currentChapterIndex = nextIndex;
    });
    _saveProgress(0.0);
  }

  /// 翻页模式：滑到本章末尾的“下一章”页时，加载并切换到下一章第一页
  Future<void> _handleNextChapterPage(
    List<NovelChapter> chapters,
    int effectiveIndex,
  ) async {
    if (_autoAdvancing) return; // 幂等守卫
    final nextIndex = effectiveIndex + 1;
    if (nextIndex >= chapters.length) {
      if (mounted) AppSnackbar.show(context, '已经是最后一章');
      return;
    }
    _autoAdvancing = true;
    _autoAdvanceFailed = false;
    setState(() {}); // 哨兵页显示加载中
    final ready = await _ensureChapterBodyReady(chapters, nextIndex);
    if (!mounted) return;
    if (ready == null) {
      setState(() {
        _autoAdvancing = false;
        _autoAdvanceFailed = true;
      });
      AppSnackbar.show(context, '下一章加载失败，请重试');
      return;
    }
    _autoAdvancing = false;
    // 用带正文的实例替换旧列表项再切章，保证滚动模式立即渲染新正文
    final refreshed = List.of(chapters);
    refreshed[nextIndex] = ready;
    _goToChapter(nextIndex, refreshed);
  }

  // ──────── 构建 ────────

  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(chaptersProvider(widget.novelId));
    final settingsAsync = ref.watch(readerSettingsProvider);

    return chaptersAsync.when(
      data: (chapters) {
        final sorted = [...chapters]
          ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
        // 使用局部变量保存 clamp 后的索引，避免在 build 中修改状态
        final effectiveIndex = sorted.isEmpty
            ? 0
            : _currentChapterIndex.clamp(0, sorted.length - 1);
        return settingsAsync.when(
          data: (settings) {
            if (settings == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            }
            _settings = settings;
            return _buildReader(context, settings, sorted, effectiveIndex);
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => const Scaffold(
            body: Center(child: Text('设置加载失败')),
          ),
        );
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const Scaffold(
        body: Center(child: Text('加载失败')),
      ),
    );
  }

  Widget _buildReader(
    BuildContext context,
    ReaderSettings settings,
    List<NovelChapter> chapters,
    int effectiveIndex,
  ) {
    final theme = settings.bgTheme;
    final bg = AppColors.readerBg(theme);
    final textColor = AppColors.readerTextOn(theme);
    final chapter = chapters.isEmpty ? null : chapters[effectiveIndex];
    final content = chapter?.content ?? '';
    final chapterTitle = chapter?.title ?? '';

    final paddingTop = MediaQuery.of(context).padding.top;
    final paddingBottom = MediaQuery.of(context).padding.bottom;

    // 进入本章后统一处理：恢复进度（滚动/翻页两种模式）+ 按需抓取空正文。
    // 放在 post-frame 而非 build 中执行，避免在 build 内触发副作用。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _maybeRestore(settings, effectiveIndex);
      _ensureChapterContent(chapters, effectiveIndex);
    });

    // 供滚动监听 / 自动翻章使用的最新章节列表
    _latestChapters = chapters;

    final Widget readingArea;
    if (settings.pageMode == 0) {
      // 滚动模式（支持连续阅读：读到章尾自动追加下一章）
      readingArea =
          _buildScrollReader(settings, textColor, chapters, effectiveIndex);
    } else if (content.isEmpty) {
      // 正文为空：展示加载/失败占位（按需抓取中）
      readingArea = _buildEmptyContent(settings, textColor, chapterTitle);
    } else {
      // 翻页模式（章末追加一页“下一章”哨兵页，滑到它即自动翻章）
      readingArea = LayoutBuilder(
        builder: (context, constraints) {
          final availWidth = constraints.maxWidth - 48;
          final availHeight = constraints.maxHeight - 48;
          if (_pages.isEmpty ||
              _paginateContent != content ||
              _paginateWidth != availWidth ||
              _paginateHeight != availHeight ||
              _paginateFontSize != settings.fontSize ||
              _paginateLineHeight != settings.lineHeight) {
            _pages = paginateChapter(
              content, availWidth, availHeight,
              settings.fontSize, settings.lineHeight,
            );
            _paginateContent = content;
            _paginateWidth = availWidth;
            _paginateHeight = availHeight;
            _paginateFontSize = settings.fontSize;
            _paginateLineHeight = settings.lineHeight;
          }
          final isLastChapter = effectiveIndex >= chapters.length - 1;
          final itemCount = _pages.length + (isLastChapter ? 0 : 1);
          return PageView.builder(
            controller: _pageController,
            itemCount: itemCount,
            onPageChanged: (page) {
              if (page < _pages.length) {
                _onPageChanged(page);
              } else {
                // 已滑到本章末尾的“下一章”页：自动加载并切换下一章
                _handleNextChapterPage(chapters, effectiveIndex);
              }
            },
            itemBuilder: (_, i) {
              if (i < _pages.length) {
                return Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Text(
                    _pages[i],
                    style: TextStyle(
                      fontSize: settings.fontSize,
                      height: settings.lineHeight,
                      color: textColor,
                      fontFamily: AppTextStyles.cjkFontFamily,
                    ),
                  ),
                );
              }
              return _buildChapterEndPage(textColor);
            },
          );
        },
      );
    }

    return Scaffold(
      backgroundColor: bg,
      body: Stack(
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (d) => _handleRegionTap(
              d.localPosition.dx,
              MediaQuery.of(context).size.width,
            ),
            child: Container(
              color: bg,
              padding: EdgeInsets.only(top: paddingTop, bottom: paddingBottom),
              child: readingArea,
            ),
          ),
          if (_showToolbars)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: ReaderTopBar(
                theme: theme,
                title: chapterTitle,
                onBack: () => Navigator.of(context).pop(),
                onOpenChapterList: () => ChapterListSheet.show(
                  context,
                  novelId: widget.novelId,
                  currentIndex: _currentChapterIndex,
                  // 传入章节列表，确保跳章时按真实章节数做范围校验（而非 clamp 恒为 0）
                  onSelect: (i) => _goToChapter(i, chapters),
                ),
              ),
            ),
          if (_showToolbars)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: ReaderBottomBar(
                theme: theme,
                progressLabel:
                    '第 ${chapters.isEmpty ? 0 : effectiveIndex + 1}/${chapters.length} 章 · ${(_currentRatio() * 100).round()}%',
                onPrev: (chapters.isEmpty || effectiveIndex <= 0)
                    ? null
                    : () => _goToChapter(effectiveIndex - 1, chapters),
                onSettings: () => ReaderSettingsSheet.show(context),
                onNext: (chapters.isEmpty ||
                        effectiveIndex >= chapters.length - 1)
                    ? null
                    : () => _goToChapter(effectiveIndex + 1, chapters),
              ),
            ),
        ],
      ),
    );
  }

  /// 正文为空的占位（按需抓取中 / 抓取失败）
  Widget _buildEmptyContent(
    ReaderSettings settings,
    Color textColor,
    String chapterTitle,
  ) {
    return ReaderEmptyContent(
      settings: settings,
      textColor: textColor,
      chapterTitle: chapterTitle,
      loadFailed: _chapterLoadFailed,
      loadMessage: _chapterLoadMessage,
      onRetry: _retryChapter,
    );
  }

  /// 滚动模式阅读区（支持连续阅读：读到章尾自动追加下一章）
  ///
  /// 已装载章节按顺序渲染；列表尾部按状态展示“加载中 / 已经读到最后一章”。
  Widget _buildScrollReader(
    ReaderSettings settings,
    Color textColor,
    List<NovelChapter> chapters,
    int effectiveIndex,
  ) {
    if (chapters.isEmpty) {
      return Center(
        child:
            Text('暂无章节', style: AppTextStyles.body.copyWith(color: textColor)),
      );
    }
    // 初始化连续阅读列表（首次进入 / 从翻页模式切回时）
    if (_scrollChapters.isEmpty) {
      _scrollChapters = [chapters[effectiveIndex]];
      _chapterBases = [0.0];
      _scrollFontSize = settings.fontSize;
      _scrollLineHeight = settings.lineHeight;
    } else if (_scrollFontSize != settings.fontSize ||
        _scrollLineHeight != settings.lineHeight) {
      // 字号/行距变化会使已追加章节的高度基准失效，重置为当前章重新累计
      _scrollChapters = [chapters[effectiveIndex]];
      _chapterBases = [0.0];
      _scrollFontSize = settings.fontSize;
      _scrollLineHeight = settings.lineHeight;
    }
    // 起始章正文已按需抓取到时，用最新章节对象刷新（保证正文可渲染）
    if (_scrollChapters.isNotEmpty && _scrollChapters.first.content.isEmpty) {
      final firstIdx = _scrollChapters.first.chapterIndex;
      if (firstIdx >= 0 &&
          firstIdx < chapters.length &&
          chapters[firstIdx].content.isNotEmpty) {
        _scrollChapters = [chapters[firstIdx]];
        _chapterBases = [0.0];
      }
    }
    // 起始章正文未就绪（按需抓取中 / 失败）：沿用现有加载/失败占位
    if (_scrollChapters.isEmpty || _scrollChapters.first.content.isEmpty) {
      return _buildEmptyContent(
        settings,
        textColor,
        chapters[effectiveIndex].title,
      );
    }
    final showEndHint = _scrollLastIndex >= chapters.length - 1;
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in _scrollChapters) ...[
            Text(
              c.title,
              style: TextStyle(
                fontSize: settings.fontSize + 4,
                fontWeight: FontWeight.w700,
                color: textColor,
                fontFamily: AppTextStyles.cjkFontFamily,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              c.content,
              style: TextStyle(
                fontSize: settings.fontSize,
                height: settings.lineHeight,
                color: textColor,
                fontFamily: AppTextStyles.cjkFontFamily,
              ),
            ),
            const SizedBox(height: 32),
          ],
          if (_scrollFetchingNext) ...[
            const SizedBox(height: 8),
            const Center(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentRose,
                ),
              ),
            ),
          ] else if (showEndHint) ...[
            const SizedBox(height: 24),
            Center(
              child: Text(
                '已经读到最后一章',
                style: AppTextStyles.caption
                    .copyWith(color: textColor.withValues(alpha: 0.6)),
              ),
            ),
          ],
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  /// 翻页模式章末的“下一章”页（加载中 / 失败提示）
  Widget _buildChapterEndPage(Color textColor) {
    return ReaderChapterEndPage(
      autoAdvancing: _autoAdvancing,
      autoAdvanceFailed: _autoAdvanceFailed,
      textColor: textColor,
    );
  }
}
