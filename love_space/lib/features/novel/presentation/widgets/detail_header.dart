import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/novel.dart';

/// 小说详情页头部：封面 + 标题/作者/章数 + 标签 + 简介
class DetailHeader extends StatelessWidget {
  final Novel novel;
  final int chapterCount;

  const DetailHeader({
    super.key,
    required this.novel,
    required this.chapterCount,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 110,
              height: 150,
              decoration: BoxDecoration(
                color: Color(novel.coverColorValue),
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowCard,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ],
              ),
              child: const Center(
                child: Icon(Icons.menu_book_rounded,
                    color: AppColors.textOnPink, size: 44),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 6),
                  Text(novel.title, style: AppTextStyles.titleMedium),
                  const SizedBox(height: 6),
                  Text(novel.author, style: AppTextStyles.caption),
                  const SizedBox(height: 10),
                  Text('共 $chapterCount 章', style: AppTextStyles.label),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in novel.tags)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.accentPinkSoft,
                  borderRadius: BorderRadius.circular(AppColors.radiusXs),
                ),
                child: Text(tag,
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.accentRose)),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text('简介', style: AppTextStyles.titleSmall),
        const SizedBox(height: 8),
        Text(novel.intro, style: AppTextStyles.body),
      ],
    );
  }
}
