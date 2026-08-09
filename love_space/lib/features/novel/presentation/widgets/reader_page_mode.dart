import 'package:flutter/material.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/reader_settings.dart';
import 'reader_placeholders.dart';

/// 翻页模式阅读区渲染（纯展示 StatelessWidget）
///
/// PageView.builder：itemCount = pages.length + (isLastChapter ? 0 : 1)，
/// 末页为"下一章"哨兵页（ReaderChapterEndPage）。分页缓存留主 State。
class ReaderPageMode extends StatelessWidget {
  final ReaderSettings settings;
  final Color textColor;
  final List<String> pages;
  final bool isLastChapter;
  final PageController controller;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onChapterEnd;
  final VoidCallback? onChapterEndRetry;
  final bool autoAdvancing;
  final bool autoAdvanceFailed;

  const ReaderPageMode({
    super.key,
    required this.settings,
    required this.textColor,
    required this.pages,
    required this.isLastChapter,
    required this.controller,
    required this.onPageChanged,
    required this.onChapterEnd,
    this.onChapterEndRetry,
    required this.autoAdvancing,
    required this.autoAdvanceFailed,
  });

  @override
  Widget build(BuildContext context) {
    final itemCount = pages.length + (isLastChapter ? 0 : 1);
    return PageView.builder(
      controller: controller,
      itemCount: itemCount,
      onPageChanged: (page) {
        if (page < pages.length) {
          onPageChanged(page);
        } else {
          onChapterEnd();
        }
      },
      itemBuilder: (_, i) {
        if (i < pages.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Text(
              pages[i],
              style: TextStyle(
                fontSize: settings.fontSize,
                height: settings.lineHeight,
                color: textColor,
                fontFamily: AppTextStyles.cjkFontFamily,
              ),
            ),
          );
        }
        return ReaderChapterEndPage(
          autoAdvancing: autoAdvancing,
          autoAdvanceFailed: autoAdvanceFailed,
          textColor: textColor,
          onRetry: onChapterEndRetry,
        );
      },
    );
  }
}
