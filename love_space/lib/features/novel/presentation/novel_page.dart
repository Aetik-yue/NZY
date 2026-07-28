import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/providers/data_providers.dart';
import 'widgets/novel_card.dart';
import 'widgets/add_novel_sheet.dart';
import 'novel_detail_page.dart';

/// 小说书架页（新 Tab 落地页）
class NovelPage extends ConsumerWidget {
  const NovelPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final novelsAsync = ref.watch(novelsProvider);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('小说', style: AppTextStyles.titleLarge),
                  GestureDetector(
                    onTap: () => AddNovelSheet.show(context),
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.accentRose,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: const Icon(
                        Icons.add_rounded,
                        color: AppColors.textOnPink,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text('一起读一本属于我们的书', style: AppTextStyles.label),
              const SizedBox(height: 20),
              novelsAsync.when(
                data: (novels) {
                  if (novels.isEmpty) {
                    return const _EmptyBookshelf();
                  }
                  return Column(
                    children: [
                      for (var i = 0; i < novels.length; i++) ...[
                        if (i > 0) const SizedBox(height: 14),
                        NovelCard(
                          novel: novels[i],
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) =>
                                  NovelDetailPage(novelId: novels[i].id),
                            ),
                          ),
                        ),
                      ],
                    ],
                  );
                },
                loading: () => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
                error: (_, __) => const Center(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 48),
                    child: Text('书架加载失败'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 空书架提示
class _EmptyBookshelf extends StatelessWidget {
  const _EmptyBookshelf();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 48),
          const Icon(
            Icons.menu_book_rounded,
            size: 56,
            color: AppColors.textTertiary,
          ),
          const SizedBox(height: 12),
          Text('书架还空空的', style: AppTextStyles.titleSmall),
          const SizedBox(height: 6),
          Text('去发现一本好书，一起读吧', style: AppTextStyles.caption),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: () => AddNovelSheet.show(context),
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('添加小说'),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
