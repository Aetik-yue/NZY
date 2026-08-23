import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/reader_settings.dart';

/// 阅读器正文为空时的占位（按需抓取中 / 抓取失败可重试）
class ReaderEmptyContent extends StatelessWidget {
  final ReaderSettings settings;
  final Color textColor;
  final String chapterTitle;
  final bool loadFailed;
  final String? loadMessage;
  final VoidCallback onRetry;

  const ReaderEmptyContent({
    super.key,
    required this.settings,
    required this.textColor,
    required this.chapterTitle,
    required this.loadFailed,
    required this.loadMessage,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (chapterTitle.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                chapterTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: settings.fontSize + 4,
                  fontWeight: FontWeight.w700,
                  color: textColor,
                  fontFamily: AppTextStyles.cjkFontFamily,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (loadFailed)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    loadMessage ?? '本章暂无内容',
                    style: AppTextStyles.body.copyWith(color: textColor),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: onRetry,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentRose,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppColors.radiusMd),
                      ),
                    ),
                    child: const Text('重试'),
                  ),
                ],
              ),
            )
          else
            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.accentRose,
              ),
            ),
        ],
      ),
    );
  }
}

/// 翻页模式章末的“下一章”页（加载中 / 失败提示）
class ReaderChapterEndPage extends StatelessWidget {
  final bool autoAdvancing;
  final bool autoAdvanceFailed;
  final Color textColor;
  final VoidCallback? onRetry;

  const ReaderChapterEndPage({
    super.key,
    required this.autoAdvancing,
    required this.autoAdvanceFailed,
    required this.textColor,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Center(
        child: autoAdvancing
            ? const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: AppColors.accentRose,
                ),
              )
            : autoAdvanceFailed
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '下一章加载失败，请重试',
                        style: AppTextStyles.body.copyWith(color: textColor),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: onRetry,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentRose,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusMd),
                          ),
                        ),
                        child: const Text('重试'),
                      ),
                    ],
                  )
                : Text(
                    '正在加载下一章…',
                    style: AppTextStyles.body.copyWith(color: textColor),
                    textAlign: TextAlign.center,
                  ),
      ),
    );
  }
}
