import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/crawler/crawler_result.dart';

/// 分类浏览书籍卡片（点击「加入书架」触发爬取）
class CategoryBookCard extends StatelessWidget {
  final CategoryBook book;
  final VoidCallback onTap;

  const CategoryBookCard({
    super.key,
    required this.book,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          children: [
            // 封面占位
            Container(
              width: 56,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.accentPeach.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
              child: const Center(
                child: Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.accentCoral,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    book.title,
                    style: AppTextStyles.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    book.author.isNotEmpty ? '作者：${book.author}' : '作者未知',
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (book.intro.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      book.intro,
                      style: AppTextStyles.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (book.wordCount.isNotEmpty ||
                      book.updateTime.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      [
                        if (book.wordCount.isNotEmpty) book.wordCount,
                        if (book.updateTime.isNotEmpty) book.updateTime,
                      ].join(' · '),
                      style: AppTextStyles.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // 添加按钮
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentPinkSoft,
                borderRadius: BorderRadius.circular(AppColors.radiusPill),
              ),
              child: Text(
                '加入书架',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.accentRose,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
