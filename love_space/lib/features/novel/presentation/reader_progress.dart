part of 'novel_reader_page.dart';

/// 阅读器进度换算 / 保存 / 恢复 / 滚动连续阅读初始化 / 分页缓存（mixin）
///
/// 与主 State 同库（part）。主 State 提供的共享字段/方法以抽象声明访问。
/// _ReaderChapterFetcher on 本 mixin，可直接访问本 mixin 的字段与方法。
mixin _ReaderProgress on ConsumerState<NovelReaderPage> {
  Novel? get _novel;
  ReaderSettings? get _settings;
  List<NovelChapter> get _latestChapters;
  int get _currentChapterIndex;
  set _currentChapterIndex(int v);
  ScrollController get _scrollController;
  PageController get _pageController;
  bool get _showToolbars;
  set _showToolbars(bool v);
  void _schedulePostFrameWork();

  Timer? _saveTimer;
  bool _restored = false;
  bool _jumpToEndOnRestore = false;
  List<NovelChapter> _scrollChapters = [];
  List<double> _chapterBases = [];
  bool _scrollFetchingNext = false;
  double? _scrollFontSize;
  double? _scrollLineHeight;
  List<String> _pages = [];
  String? _paginateContent;
  double? _paginateWidth;
  double? _paginateHeight;
  double? _paginateFontSize;
  double? _paginateLineHeight;
  double? _paginateParagraphSpacing;

  double _currentRatio() {
    if (_settings?.pageMode == 1) {
      if (_pages.isEmpty) return 0.0;
      final page = _pageController.page ?? 0;
      final denom = _pages.length - 1;
      return denom <= 0 ? 0.0 : (page / denom).clamp(0.0, 1.0);
    }
    if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      return _computeScrollProgress().$2;
    }
    return 0.0;
  }

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
      extent = pos.maxScrollExtent - base;
    }
    if (extent <= 0) return (_currentChapterIndex, 0.0);
    final ratio = ((pixels - base) / extent).clamp(0.0, 1.0);
    return (_scrollChapters[listIdx].chapterIndex, ratio);
  }

  int get _scrollLastIndex =>
      _scrollChapters.isEmpty ? -1 : _scrollChapters.last.chapterIndex;

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

  void _onPageChanged(int page) {
    if (_pages.isEmpty) return;
    final denom = _pages.length - 1;
    final ratio = denom <= 0 ? 0.0 : (page / denom).clamp(0.0, 1.0);
    _saveProgress(ratio);
  }

  void _maybeRestore(ReaderSettings settings, int effectiveIndex) {
    if (_restored) return;
    if (_novel == null) return;
    final restoreRatio = effectiveIndex == _novel!.lastChapterIndex
        ? _novel!.lastPosition
        : 0.0;
    if (settings.pageMode == 1) {
      if (_pages.isNotEmpty && _pageController.hasClients) {
        final target = _jumpToEndOnRestore
            ? _pages.length - 1
            : (restoreRatio * _pages.length).round().clamp(0, _pages.length - 1);
        _pageController.jumpToPage(target);
        _jumpToEndOnRestore = false;
      }
    } else if (_scrollController.hasClients &&
        _scrollController.position.maxScrollExtent > 0) {
      final max = _scrollController.position.maxScrollExtent;
      _scrollController.jumpTo((restoreRatio * max).clamp(0.0, max));
    }
    _saveProgress(restoreRatio);
    if (mounted) setState(() => _restored = true);
  }

  void _syncScrollChapters(
    ReaderSettings settings,
    List<NovelChapter> chapters,
    int effectiveIndex,
  ) {
    if (chapters.isEmpty) return;
    if (_scrollChapters.isEmpty) {
      _scrollChapters = [chapters[effectiveIndex]];
      _chapterBases = [0.0];
      _scrollFontSize = settings.fontSize;
      _scrollLineHeight = settings.lineHeight;
    } else if (_scrollFontSize != settings.fontSize ||
        _scrollLineHeight != settings.lineHeight) {
      _scrollChapters = [chapters[effectiveIndex]];
      _chapterBases = [0.0];
      _scrollFontSize = settings.fontSize;
      _scrollLineHeight = settings.lineHeight;
    }
    if (_scrollChapters.isNotEmpty && _scrollChapters.first.content.isEmpty) {
      final firstIdx = _scrollChapters.first.chapterIndex;
      if (firstIdx >= 0 &&
          firstIdx < chapters.length &&
          chapters[firstIdx].content.isNotEmpty) {
        _scrollChapters = [chapters[firstIdx]];
        _chapterBases = [0.0];
      }
    }
  }

  List<String> _computePages(
    String content,
    ReaderSettings settings,
    double availWidth,
    double availHeight,
  ) {
    if (_pages.isEmpty ||
        _paginateContent != content ||
        _paginateWidth != availWidth ||
        _paginateHeight != availHeight ||
        _paginateFontSize != settings.fontSize ||
        _paginateLineHeight != settings.lineHeight ||
        _paginateParagraphSpacing != settings.paragraphSpacing) {
      _pages = paginateChapter(
        content,
        availWidth,
        availHeight,
        settings.fontSize,
        settings.lineHeight,
        settings.paragraphSpacing,
      );
      _paginateContent = content;
      _paginateWidth = availWidth;
      _paginateHeight = availHeight;
      _paginateFontSize = settings.fontSize;
      _paginateLineHeight = settings.lineHeight;
      _paginateParagraphSpacing = settings.paragraphSpacing;
    }
    return _pages;
  }
}
