part of 'novel_reader_page.dart';

/// 阅读器章节抓取 / 预取 / 自动翻章 / 滚动追加逻辑（mixin）
///
/// on _ReaderProgress，可直接访问进度 mixin 的字段与方法。
mixin _ReaderChapterFetcher on _ReaderProgress {
  int? _loadingChapterId;
  bool _chapterLoadFailed = false;
  String? _chapterLoadMessage;
  bool _autoAdvancing = false;
  bool _autoAdvanceFailed = false;

  void _onScroll() {
    if (!_restored || !_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.maxScrollExtent <= 0) return;
    if (pos.maxScrollExtent - pos.pixels < _appendThreshold) {
      _maybeAppendNextChapter();
    }
    final (idx, ratio) = _computeScrollProgress();
    if (idx != _currentChapterIndex) {
      setState(() => _currentChapterIndex = idx);
    }
    _saveProgress(ratio);
  }

  Future<void> _ensureChapterContent(
    List<NovelChapter> chapters,
    int index,
  ) async {
    if (index < 0 || index >= chapters.length) return;
    final chapter = chapters[index];
    if (chapter.content.isNotEmpty) return;
    if (_loadingChapterId == chapter.id) return;
    if (_chapterLoadFailed) return;
    final novel = _novel;
    if (novel == null) return;
    final sourceKey = novel.sourceKey;
    final sourceUrl = chapter.sourceUrl;
    if (sourceKey == null || sourceUrl == null || sourceUrl.isEmpty) {
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
          .fetchChapterContent(
              chapterUrl: sourceUrl, novelSourceKey: sourceKey);
      if (!mounted) return;
      if (content.isEmpty) {
        setState(() {
          _loadingChapterId = null;
          _chapterLoadFailed = true;
          _chapterLoadMessage = '本章暂无内容';
        });
        return;
      }
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

  void _retryChapter() {
    setState(() {
      _chapterLoadFailed = false;
      _chapterLoadMessage = null;
    });
    _schedulePostFrameWork();
  }

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
      return null;
    }
    try {
      final content = await ref
          .read(crawlRepositoryProvider)
          .fetchChapterContent(
              chapterUrl: sourceUrl, novelSourceKey: sourceKey);
      if (content.isEmpty) return null;
      await ref
          .read(novelChapterRepositoryProvider)
          .updateContent(widget.novelId, chapter.chapterIndex, content);
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

  Future<void> _maybeAppendNextChapter() async {
    if (_settings?.pageMode != 0) return;
    if (_scrollFetchingNext) return;
    if (_scrollChapters.isEmpty) return;
    final chapters = _latestChapters;
    final nextIndex = _scrollLastIndex + 1;
    if (nextIndex >= chapters.length) return;
    _scrollFetchingNext = true;
    setState(() {});
    final ready = await _ensureChapterBodyReady(chapters, nextIndex);
    if (!mounted) return;
    if (ready == null) {
      setState(() => _scrollFetchingNext = false);
      AppSnackbar.show(context, '下一章加载失败，请重试');
      return;
    }
    setState(() {
      _scrollFetchingNext = false;
      final base = _scrollController.hasClients
          ? _scrollController.position.maxScrollExtent
          : 0.0;
      _scrollChapters.add(ready);
      _chapterBases.add(base);
      _currentChapterIndex = nextIndex;
    });
    _saveProgress(0.0);
  }

  Future<void> _handleNextChapterPage(
    List<NovelChapter> chapters,
    int effectiveIndex,
  ) async {
    if (_autoAdvancing) return;
    final nextIndex = effectiveIndex + 1;
    if (nextIndex >= chapters.length) {
      if (mounted) AppSnackbar.show(context, '已经是最后一章');
      return;
    }
    _autoAdvancing = true;
    _autoAdvanceFailed = false;
    setState(() {});
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
    final refreshed = List.of(chapters);
    refreshed[nextIndex] = ready;
    _goToChapter(nextIndex, refreshed);
  }

  /// 预取下一章正文（post-frame 钩子调用，fire-and-forget）
  void _prefetchNextChapter(List<NovelChapter> chapters, int index) {
    final next = index + 1;
    if (next >= chapters.length) return;
    final chapter = chapters[next];
    if (chapter.content.isNotEmpty) return;
    unawaited(_ensureChapterBodyReady(chapters, next));
  }

  // ── 章节切换 ──

  void _goToChapter(int index, List<NovelChapter> chapters) {
    final clamped = chapters.isEmpty ? 0 : index.clamp(0, chapters.length - 1);
    setState(() {
      _currentChapterIndex = clamped;
      _restored = false;
      _loadingChapterId = null;
      _chapterLoadFailed = false;
      _chapterLoadMessage = null;
      if (_settings?.pageMode == 0) {
        _scrollChapters = chapters.isEmpty ? [] : [chapters[clamped]];
        _chapterBases = [0.0];
        _scrollFetchingNext = false;
      }
      _autoAdvancing = false;
      _autoAdvanceFailed = false;
    });
    _saveProgress(0.0);
    _schedulePostFrameWork();
  }

  @override
  void dispose() {
    _saveTimer?.cancel();
    WakelockPlus.disable();
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
    unawaited(
      ref
          .read(novelRepositoryProvider)
          .updateProgress(widget.novelId, chapterIndex, ratio)
          .then<void>((_) {}, onError: (Object e) {
        debugPrint('[NovelReaderPage] 退出时保存进度失败: $e');
      }),
    );
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
    super.dispose();
  }
}
