import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/models/novel.dart';
import '../../../data/models/novel_chapter.dart';
import '../../../data/models/reader_settings.dart';
import 'widgets/chapter_list_sheet.dart';
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

  // 分页缓存（避免每次 rebuild 重复计算 TextPainter 布局）
  String? _paginateContent;
  double? _paginateWidth;
  double? _paginateHeight;
  double? _paginateFontSize;
  double? _paginateLineHeight;

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
    // 读取小说初始进度用于恢复
    ref.read(novelRepositoryProvider).getById(widget.novelId).then((n) {
      if (!mounted) return;
      _novel = n;
      setState(() {});
    });
  }

  @override
  void dispose() {
    final ratio = _currentRatio();
    _saveTimer?.cancel();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _pageController.dispose();
    // 末次保存进度
    ref
        .read(novelRepositoryProvider)
        .updateProgress(widget.novelId, _currentChapterIndex, ratio);
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
      return (_scrollController.offset / _scrollController.position.maxScrollExtent)
          .clamp(0.0, 1.0);
    }
    return 0.0;
  }

  void _saveProgress(double ratio) {
    if (!mounted) return;
    _saveTimer?.cancel();
    _saveTimer = Timer(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      ref.read(novelRepositoryProvider).updateProgress(
            widget.novelId,
            _currentChapterIndex,
            ratio,
          );
    });
  }

  void _onScroll() {
    if (!_restored || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    _saveProgress((pos.pixels / pos.maxScrollExtent).clamp(0.0, 1.0));
  }

  void _onPageChanged(int page) {
    if (_pages.isEmpty) return;
    final denom = _pages.length - 1;
    final ratio = denom <= 0 ? 0.0 : (page / denom).clamp(0.0, 1.0);
    _saveProgress(ratio);
  }

  // ──────── 章节切换 ────────

  void _goToChapter(int index, List<NovelChapter> chapters) {
    // 如果传入了 chapters 列表则校验范围，否则直接跳转（由调用方保证范围）
    final clamped = chapters.isEmpty
        ? index.clamp(0, 0)
        : index.clamp(0, chapters.length - 1);
    setState(() {
      _currentChapterIndex = clamped;
      _restored = true;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_settings?.pageMode == 1) {
        if (_pages.isNotEmpty) _pageController.jumpToPage(0);
      } else {
        if (_scrollController.hasClients) _scrollController.jumpTo(0);
      }
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
      if (_pageController.page != null &&
          _pageController.page! < _pages.length - 1) {
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

  // ──────── 分页算法（翻页模式）────────

  List<String> _paginate(
    String content,
    double width,
    double availHeight,
    double fontSize,
    double lineHeight,
  ) {
    if (content.isEmpty) return [''];
    final painter = TextPainter(
      text: TextSpan(
        text: content,
        style: TextStyle(
          fontSize: fontSize,
          height: lineHeight,
          fontFamily: AppTextStyles.cjkFontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: null,
    );
    painter.layout(maxWidth: width);
    final metrics = painter.computeLineMetrics();
    if (metrics.isEmpty) return [content];
    final lineHeightPx = metrics.first.height;
    if (lineHeightPx <= 0) return [content];
    final linesPerPage = (availHeight / lineHeightPx).floor();
    if (linesPerPage <= 0) return [content];

    final pages = <String>[];
    for (var start = 0; start < metrics.length; start += linesPerPage) {
      final end = (start + linesPerPage) < metrics.length
          ? start + linesPerPage
          : metrics.length;
      final startOffset = painter
          .getPositionForOffset(
              Offset(0, metrics[start].baseline - lineHeightPx * 0.5))
          .offset;
      final endOffset = end < metrics.length
          ? painter
              .getPositionForOffset(
                  Offset(0, metrics[end].baseline - lineHeightPx * 0.5))
              .offset
          : content.length;
      pages.add(content.substring(startOffset, endOffset));
    }
    return pages;
  }

  // ──────── 进度恢复（仅进入时一次）────────

  void _maybeRestore(ReaderSettings settings, int effectiveIndex) {
    if (_restored) return;
    if (_novel == null) return; // 等小说进度就绪后再恢复
    final restoreRatio =
        effectiveIndex == _novel!.lastChapterIndex
            ? _novel!.lastPosition
            : 0.0;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (settings.pageMode == 1) {
        if (_pages.isNotEmpty) {
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
      if (mounted) setState(() => _restored = true);
    });
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

    final size = MediaQuery.of(context).size;
    final paddingTop = MediaQuery.of(context).padding.top;
    final paddingBottom = MediaQuery.of(context).padding.bottom;

    // 仅在翻页模式且分页输入变化时重算，避免每次 rebuild 重复计算
    if (settings.pageMode == 1) {
      final availWidth = size.width - 48;
      final availHeight =
          size.height - paddingTop - paddingBottom - 52 - 60 - 48;
      if (_pages.isEmpty ||
          _paginateContent != content ||
          _paginateWidth != availWidth ||
          _paginateHeight != availHeight ||
          _paginateFontSize != settings.fontSize ||
          _paginateLineHeight != settings.lineHeight) {
        _pages = _paginate(
          content, availWidth, availHeight,
          settings.fontSize, settings.lineHeight,
        );
        _paginateContent = content;
        _paginateWidth = availWidth;
        _paginateHeight = availHeight;
        _paginateFontSize = settings.fontSize;
        _paginateLineHeight = settings.lineHeight;
      }
    } else {
      _pages = [];
    }

    _maybeRestore(settings, effectiveIndex);

    final readingArea = settings.pageMode == 0
        ? SingleChildScrollView(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  chapterTitle,
                  style: TextStyle(
                    fontSize: settings.fontSize + 4,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    fontFamily: AppTextStyles.cjkFontFamily,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  content,
                  style: TextStyle(
                    fontSize: settings.fontSize,
                    height: settings.lineHeight,
                    color: textColor,
                    fontFamily: AppTextStyles.cjkFontFamily,
                  ),
                ),
                const SizedBox(height: 48),
              ],
            ),
          )
        : PageView.builder(
            controller: _pageController,
            itemCount: _pages.length,
            onPageChanged: _onPageChanged,
            itemBuilder: (_, i) => Padding(
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
            ),
          );

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
          if (_showToolbars) _buildTopBar(context, theme, chapterTitle),
          if (_showToolbars)
            _buildBottomBar(context, theme, chapters, effectiveIndex),
        ],
      ),
    );
  }

  Widget _buildTopBar(
    BuildContext context,
    int theme,
    String title,
  ) {
    final textColor = AppColors.readerTextOn(theme);
    final paddingTop = MediaQuery.of(context).padding.top;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: paddingTop + 8,
          bottom: 8,
          left: 8,
          right: 8,
        ),
        color: AppColors.readerBg(theme).withValues(alpha: 0.95),
        child: Row(
          children: [
            IconButton(
              icon: Icon(Icons.arrow_back_rounded, color: textColor),
              onPressed: () => Navigator.of(context).pop(),
            ),
            Expanded(
              child: Text(
                title,
                style: AppTextStyles.body.copyWith(color: textColor),
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
            ),
            IconButton(
              icon: Icon(Icons.format_list_bulleted_rounded,
                  color: textColor),
              onPressed: () => ChapterListSheet.show(
                context,
                novelId: widget.novelId,
                currentIndex: _currentChapterIndex,
                onSelect: (i) => _goToChapter(i, []),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar(
    BuildContext context,
    int theme,
    List<NovelChapter> chapters,
    int effectiveIndex,
  ) {
    final textColor = AppColors.readerTextOn(theme);
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    final percent = (_currentRatio() * 100).round();
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          bottom: paddingBottom + 8,
          top: 8,
          left: 12,
          right: 12,
        ),
        color: AppColors.readerBg(theme).withValues(alpha: 0.95),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _barBtn(
              Icons.chevron_left_rounded,
              '上一章',
              textColor,
              (chapters.isEmpty || effectiveIndex <= 0)
                  ? null
                  : () => _goToChapter(effectiveIndex - 1, chapters),
            ),
            Text(
              '第 ${chapters.isEmpty ? 0 : effectiveIndex + 1}/${chapters.length} 章 · $percent%',
              style: AppTextStyles.label.copyWith(color: textColor),
            ),
            Row(
              children: [
                _barBtn(
                  Icons.settings_rounded,
                  '设置',
                  textColor,
                  () => ReaderSettingsSheet.show(context),
                ),
                const SizedBox(width: 4),
                _barBtn(
                  Icons.chevron_right_rounded,
                  '下一章',
                  textColor,
                  (chapters.isEmpty ||
                          effectiveIndex >= chapters.length - 1)
                      ? null
                      : () => _goToChapter(effectiveIndex + 1, chapters),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _barBtn(
    IconData icon,
    String label,
    Color color,
    VoidCallback? onTap,
  ) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon,
                color: active ? color : color.withValues(alpha: 0.4), size: 18),
            const SizedBox(width: 2),
            Text(label,
                style: AppTextStyles.label
                    .copyWith(color: active ? color : color.withValues(alpha: 0.4))),
          ],
        ),
      ),
    );
  }
}
