part of 'novel_reader_page.dart';

/// 阅读器翻页交互 / 点击分区 / 空正文占位逻辑（mixin）
///
/// on _ReaderChapterFetcher，可访问进度与抓取 mixin 的全部成员。
mixin _ReaderInteraction on _ReaderChapterFetcher {
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
      final page = _pageController.page ?? 0;
      if (page > 0) {
        _pageController.previousPage(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      } else {
        _goToPreviousChapterLastPage();
      }
    } else if (_scrollController.hasClients) {
      final h = _scrollController.position.viewportDimension;
      _scrollController.animateTo(
        (_scrollController.offset - h)
            .clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  /// 翻页模式：page==0 时回退上一章末页
  Future<void> _goToPreviousChapterLastPage() async {
    final chapters = _latestChapters;
    if (chapters.isEmpty) return;
    final effectiveIndex =
        _currentChapterIndex.clamp(0, chapters.length - 1);
    if (effectiveIndex <= 0) {
      if (mounted) AppSnackbar.show(context, '已经是第一章');
      return;
    }
    final prevIndex = effectiveIndex - 1;
    final ready = await _ensureChapterBodyReady(chapters, prevIndex);
    if (!mounted) return;
    if (ready == null) {
      if (mounted) AppSnackbar.show(context, '上一章加载失败，请重试');
      return;
    }
    final refreshed = List.of(chapters);
    refreshed[prevIndex] = ready;
    _jumpToEndOnRestore = true;
    _goToChapter(prevIndex, refreshed);
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
        if (mounted) AppSnackbar.show(context, '已经是最后一章');
      } else {
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

  bool get _isLastChapter {
    final chapters = _latestChapters;
    if (chapters.isEmpty) return true;
    final effective = _currentChapterIndex.clamp(0, chapters.length - 1);
    return effective >= chapters.length - 1;
  }

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
}
