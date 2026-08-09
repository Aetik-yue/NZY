import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/novel_chapter.dart';
import '../../../../data/models/reader_settings.dart';

/// 滚动模式阅读区渲染（纯展示 StatelessWidget）
///
/// 已装载章节按顺序渲染（正文按 \n 分段，段间留 paragraphSpacing）；
/// 列表尾部按状态展示"加载中 / 已经读到最后一章"。
class ReaderScrollMode extends StatelessWidget {
  final ReaderSettings settings;
  final Color textColor;
  final List<NovelChapter> scrollChapters;
  final bool showEndHint;
  final bool fetchingNext;
  final ScrollController controller;

  const ReaderScrollMode({
    super.key,
    required this.settings,
    required this.textColor,
    required this.scrollChapters,
    required this.showEndHint,
    required this.fetchingNext,
    required this.controller,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      controller: controller,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final c in scrollChapters) ...[
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
            ..._buildParagraphs(c.content, settings, textColor),
            const SizedBox(height: 32),
          ],
          if (fetchingNext) ...[
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

  /// 按段落（`\n`）分段渲染正文，段间留 paragraphSpacing 间距
  List<Widget> _buildParagraphs(
    String content,
    ReaderSettings settings,
    Color color,
  ) {
    final parts = content.split('\n');
    return [
      for (var i = 0; i < parts.length; i++) ...[
        if (i > 0) SizedBox(height: settings.paragraphSpacing),
        Text(
          parts[i],
          style: TextStyle(
            fontSize: settings.fontSize,
            height: settings.lineHeight,
            color: color,
            fontFamily: AppTextStyles.cjkFontFamily,
          ),
        ),
      ],
    ];
  }
}
