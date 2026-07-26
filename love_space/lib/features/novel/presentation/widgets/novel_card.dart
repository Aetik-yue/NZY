import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/novel.dart';

/// 书架卡片
///
/// 展示封面色块、标题、作者、标签与最近阅读进度，整卡可点击进入详情。
class NovelCard extends StatelessWidget {
  final Novel novel;
  final VoidCallback onTap;

  const NovelCard({
    super.key,
    required this.novel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final percent = (novel.lastPosition * 100).round();
    final progressText = novel.lastChapterIndex < 0
        ? '未读'
        : (percent >= 100 ? '已读完' : '读到 $percent%');

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        height: 132,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowCard,
              blurRadius: 16,
              offset: Offset(0, 4),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 封面色块（运行时从数据读取色值，非硬编码）
            Container(
              width: 96,
              decoration: BoxDecoration(
                color: Color(novel.coverColorValue),
                borderRadius: BorderRadius.horizontal(
                  left: Radius.circular(AppColors.radiusCard),
                ),
              ),
              child: Center(
                child: Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.textOnPink,
                  size: 36,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(vertical: 16, horizontal: 4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(novel.title, style: AppTextStyles.titleSmall),
                    const SizedBox(height: 4),
                    Text(novel.author, style: AppTextStyles.caption),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in novel.tags.take(3))
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.accentPinkSoft,
                              borderRadius:
                                  BorderRadius.circular(AppColors.radiusXs),
                            ),
                            child: Text(
                              tag,
                              style: AppTextStyles.label
                                  .copyWith(color: AppColors.accentRose),
                            ),
                          ),
                      ],
                    ),
                    const Spacer(),
                    Text(progressText, style: AppTextStyles.caption),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
