import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import '../../../app/theme/app_colors.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/models/novel.dart';
import '../../../data/models/novel_chapter.dart';
import '../../../data/models/reader_settings.dart';
import '../../../shared/widgets/app_snackbar.dart';
import 'widgets/chapter_list_sheet.dart';
import 'widgets/novel_paginator.dart';
import 'widgets/reader_controls.dart';
import 'widgets/reader_page_mode.dart';
import 'widgets/reader_placeholders.dart';
import 'widgets/reader_scroll_mode.dart';
import 'widgets/reader_settings_sheet.dart';

part 'reader_chapter_fetcher.dart';
part 'reader_interaction.dart';
part 'reader_progress.dart';

/// 距列表底部多少像素内视为"读到章尾"，触发自动追加下一章
const double _appendThreshold = 240;

/// 沉浸式阅读页（核心）
///
/// 支持滚动 / 翻页两种模式，进度按 0..1 记忆。渲染层
/// （ReaderScrollMode/ReaderPageMode）为 StatelessWidget；紧耦合逻辑
/// （抓取/进度/交互）放在 part 文件 mixin 中与主 State 同库，保留私有
/// 可见性。build 不执行副作用（赋值/回调注册已移至 initState 的 listen）。
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

class _NovelReaderPageState extends ConsumerState<NovelReaderPage>
    with _ReaderProgress, _ReaderChapterFetcher, _ReaderInteraction {
  @override
  late final ScrollController _scrollController;
  @override
  late final PageController _pageController;

  @override
  int _currentChapterIndex = 0;
  @override
  bool _showToolbars = true;
  @override
  Novel? _novel;
  @override
  ReaderSettings? _settings;
  @override
  List<NovelChapter> _latestChapters = [];

  /// post-frame 调度守卫（恢复进度 / 抓取正文 / 预取，仅每帧注册一次）
  bool _postFrameScheduled = false;

  @override
  void initState() {
    super.initState();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    _currentChapterIndex = widget.initialChapterIndex;
    _scrollController = ScrollController()..addListener(_onScroll);
    _pageController = PageController();
    ref.read(readerSettingsRepositoryProvider).getOrCreate();
    ref.listenManual<AsyncValue<ReaderSettings?>>(
      readerSettingsProvider,
      (prev, next) {
        next.whenData((s) {
          _settings = s;
          _schedulePostFrameWork();
        });
        final keep = next.valueOrNull?.keepScreenOn ?? false;
        if (keep) {
          WakelockPlus.enable();
        } else {
          WakelockPlus.disable();
        }
      },
      fireImmediately: true,
    );
    ref.listenManual<AsyncValue<List<NovelChapter>>>(
      chaptersProvider(widget.novelId),
      (prev, next) {
        next.whenData((list) {
          _latestChapters = [...list]
            ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
          _schedulePostFrameWork();
        });
      },
      fireImmediately: true,
    );
    ref.read(novelRepositoryProvider).getById(widget.novelId).then((n) {
      if (!mounted) return;
      _novel = n;
      setState(() {});
      _schedulePostFrameWork();
    });
  }

  /// 调度 post-frame 工作（恢复进度 + 按需抓取正文 + 预取下一章）
  ///
  /// 用 _postFrameScheduled 守卫每帧仅注册一次；回调在帧末布局完成后执行。
  /// 由 listen 回调 / _novel 就绪 / _goToChapter / _retryChapter 触发。
  @override
  void _schedulePostFrameWork() {
    if (_postFrameScheduled) return;
    _postFrameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postFrameScheduled = false;
      if (!mounted) return;
      final s = _settings;
      final chapters = _latestChapters;
      if (s == null || chapters.isEmpty || _novel == null) return;
      final idx = _currentChapterIndex.clamp(0, chapters.length - 1);
      _maybeRestore(s, idx);
      _ensureChapterContent(chapters, idx);
      _prefetchNextChapter(chapters, idx);
    });
  }

  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(chaptersProvider(widget.novelId));
    final settingsAsync = ref.watch(readerSettingsProvider);
    return chaptersAsync.when(
      data: (chapters) {
        final sorted = [...chapters]
          ..sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
        final effectiveIndex = sorted.isEmpty
            ? 0
            : _currentChapterIndex.clamp(0, sorted.length - 1);
        return settingsAsync.when(
          data: (settings) => (settings == null)
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator(strokeWidth: 2)))
              : _buildReader(context, settings, sorted, effectiveIndex),
          loading: () => const Scaffold(
              body: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (_, __) =>
              const Scaffold(body: Center(child: Text('设置加载失败'))),
        );
      },
      loading: () => const Scaffold(
          body: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const Scaffold(body: Center(child: Text('加载失败'))),
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

    final Widget readingArea;
    if (settings.pageMode == 0) {
      _syncScrollChapters(settings, chapters, effectiveIndex);
      final showEmpty =
          _scrollChapters.isEmpty || _scrollChapters.first.content.isEmpty;
      readingArea = showEmpty
          ? _buildEmptyContent(settings, textColor, chapterTitle)
          : ReaderScrollMode(
              settings: settings,
              textColor: textColor,
              scrollChapters: _scrollChapters,
              showEndHint: _scrollLastIndex >= chapters.length - 1,
              fetchingNext: _scrollFetchingNext,
              controller: _scrollController,
            );
    } else if (content.isEmpty) {
      readingArea = _buildEmptyContent(settings, textColor, chapterTitle);
    } else {
      readingArea = LayoutBuilder(
        builder: (context, constraints) {
          final availWidth = constraints.maxWidth - 48;
          final availHeight = constraints.maxHeight - 48;
          final pages =
              _computePages(content, settings, availWidth, availHeight);
          return ReaderPageMode(
            settings: settings,
            textColor: textColor,
            pages: pages,
            isLastChapter: effectiveIndex >= chapters.length - 1,
            controller: _pageController,
            onPageChanged: _onPageChanged,
            onChapterEnd: () => _handleNextChapterPage(chapters, effectiveIndex),
            onChapterEndRetry: _autoAdvanceFailed
                ? () => _handleNextChapterPage(chapters, effectiveIndex)
                : null,
            autoAdvancing: _autoAdvancing,
            autoAdvanceFailed: _autoAdvanceFailed,
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
                chapterCount: chapters.length,
                currentChapter: chapters.isEmpty ? 0 : effectiveIndex,
                onPrev: (chapters.isEmpty || effectiveIndex <= 0)
                    ? null
                    : () => _goToChapter(effectiveIndex - 1, chapters),
                onSettings: () => ReaderSettingsSheet.show(context),
                onNext: (chapters.isEmpty ||
                        effectiveIndex >= chapters.length - 1)
                    ? null
                    : () => _goToChapter(effectiveIndex + 1, chapters),
                onSeekChapter: (i) => _goToChapter(i, chapters),
              ),
            ),
        ],
      ),
    );
  }
}
