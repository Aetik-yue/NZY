import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/models/wish.dart';
import '../../../features/wishes/presentation/widgets/add_wish_sheet.dart';

/// 愿望清单页
/// 设计稿未绘制此页，此处提供与整体风格一致的骨架
class WishesPage extends ConsumerWidget {
  const WishesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(wishStatsProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('愿望清单', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 2),
                  Text('一起完成 ${stats.done} / ${stats.total} 个愿望',
                      style: AppTextStyles.label),
                ],
              ),
              GestureDetector(
                onTap: () => AddWishSheet.show(context),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: AppColors.pinkButtonGradient,
                    shape: BoxShape.circle,
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x59FF6B9D),
                        blurRadius: 16,
                        offset: Offset(0, 6),
                        spreadRadius: -2,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 22),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 进度卡片
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.headerGradient,
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x33FF6B8F),
                  blurRadius: 24,
                  offset: Offset(0, 8),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('愿望完成进度', style: AppTextStyles.onPink.copyWith(fontSize: 13).copyWith(
                  color: Colors.white.withValues(alpha: 0.9),
                )),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${stats.percentInt}%', style: AppTextStyles.heroNumber.copyWith(fontSize: 40)),
                    const SizedBox(width: 6),
                    Text('已完成', style: AppTextStyles.onPink.copyWith(fontSize: 14).copyWith(
                      color: Colors.white.withValues(alpha: 0.85),
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: stats.percent,
                    minHeight: 6,
                    backgroundColor: Colors.white.withValues(alpha: 0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(
            title: '待实现',
            actionText: '全部',
            onAction: () => AppSnackbar.show(context, '即将上线 ⭐'),
          ),
          const SizedBox(height: 14),
          // 愿望列表（动态渲染前 3 条未完成的愿望）
          const _WishList(),
        ],
      ),
    );
  }
}

/// 愿望列表（动态渲染前 3 条未完成的愿望）
class _WishList extends ConsumerWidget {
  const _WishList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wishesAsync = ref.watch(wishesProvider);
    return wishesAsync.when(
      data: (wishes) {
        final undone = wishes.where((w) => !w.done).take(3).toList();
        if (undone.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('太棒了！所有愿望都已完成 🎉'),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < undone.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _WishItem(
                wish: undone[i],
                onToggle: () => ref
                    .read(wishRepositoryProvider)
                    .toggleDone(undone[i].id),
                onDelete: () async {
                  final confirmed = await showConfirmDeleteDialog(
                    context,
                    content: '确定要删除这个愿望吗？',
                  );
                  if (confirmed && context.mounted) {
                    final wishToDelete = undone[i];
                    await ref.read(wishRepositoryProvider).delete(undone[i].id);
                    if (context.mounted) {
                      AppSnackbar.showUndo(context, '愿望已删除', () async {
                        await ref.read(wishRepositoryProvider).add(wishToDelete);
                      });
                    }
                  }
                },
              ),
            ],
          ],
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 12),
        child: Text('加载失败'),
      ),
    );
  }
}

class _WishItem extends StatelessWidget {
  final Wish wish;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _WishItem({
    required this.wish,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      onLongPress: onDelete,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(20),
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
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.accentPinkSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                IconData(wish.iconCodePoint, fontFamily: 'MaterialIcons'),
                color: AppColors.accentRose,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(wish.title, style: AppTextStyles.titleSmall.copyWith(fontSize: 15)),
                  const SizedBox(height: 3),
                  Text(wish.description, style: AppTextStyles.caption),
                ],
              ),
            ),
            Icon(
              wish.done ? Icons.check_circle : Icons.radio_button_unchecked,
              color: wish.done ? AppColors.accentRose : AppColors.textTertiary,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}
