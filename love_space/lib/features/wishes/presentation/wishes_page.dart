import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/models/wish.dart';
import '../../../data/models/timeline_event.dart';
import 'widgets/add_wish_sheet.dart';
import 'wishes_all_page.dart';

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
                  decoration: const BoxDecoration(
                    gradient: AppColors.pinkButtonGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowPinkStrong,
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
              borderRadius: BorderRadius.circular(AppColors.radiusCard),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowPinkMedium,
                  blurRadius: 24,
                  offset: Offset(0, 8),
                  spreadRadius: -4,
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('愿望完成进度',
                    style: AppTextStyles.onPink.copyWith(fontSize: 13).copyWith(
                          color: Colors.white.withValues(alpha: 0.9),
                        )),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('${stats.percentInt}%',
                        style: AppTextStyles.heroNumber.copyWith(fontSize: 40)),
                    const SizedBox(width: 6),
                    Text('已完成',
                        style: AppTextStyles.onPink
                            .copyWith(fontSize: 14)
                            .copyWith(
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
                    valueColor:
                        const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionHeader(
            title: '进行中',
            actionText: '全部',
            // 跳转全部愿望页（全部/进行中/已完成 + 已完成回看）
            onAction: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const WishesAllPage()),
            ),
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
class _WishList extends ConsumerStatefulWidget {
  const _WishList();

  @override
  ConsumerState<_WishList> createState() => _WishListState();
}

class _WishListState extends ConsumerState<_WishList> {
  /// 防连点：正在切换状态的愿望 id
  int? _busyWishId;

  @override
  Widget build(BuildContext context) {
    final wishesAsync = ref.watch(wishesProvider);
    return wishesAsync.when(
      data: (wishes) {
        if (wishes.isEmpty) {
          // 区分「无数据」与「全部完成」
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text('还没有愿望，点右上角 ＋ 添加第一个吧'),
          );
        }
        final undone = wishes.where((w) => !w.done).take(3).toList();
        if (undone.isEmpty) {
          // 全部完成：引导去全部页回看/取消
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              children: [
                const Text('太棒了！所有愿望都已完成 🎉'),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WishesAllPage()),
                  ),
                  child: Text(
                    '查看全部愿望',
                    style: AppTextStyles.label
                        .copyWith(color: AppColors.accentRose),
                  ),
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < undone.length; i++) ...[
              if (i > 0) const SizedBox(height: 12),
              _WishItem(
                wish: undone[i],
                onToggle: () async {
                  final wish = undone[i];
                  // 防连点：切换进行中时忽略重复点击
                  if (_busyWishId == wish.id) return;
                  setState(() => _busyWishId = wish.id);
                  try {
                    await ref
                        .read(wishRepositoryProvider)
                        .toggleDone(wish.id);
                  } catch (e) {
                    debugPrint('[WishesPage] 切换失败: $e');
                    if (context.mounted) {
                      AppSnackbar.show(context, '操作失败，请重试');
                    }
                    return;
                  } finally {
                    if (mounted) setState(() => _busyWishId = null);
                  }
                  if (!context.mounted) return;
                  // 完成愿望：庆祝 + 可选记录到时光线
                  _celebrate(context, ref, wish);
                },
                onLongPress: () => _showActions(context, undone[i]),
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

  /// 长按操作单：编辑 / 删除
  Future<void> _showActions(BuildContext context, Wish wish) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: AppColors.accentRose),
              title: const Text('编辑愿望'),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.accentRose),
              title: const Text('删除愿望'),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'edit':
        await AddWishSheet.show(context, initial: wish);
      case 'delete':
        await _delete(context, wish);
    }
  }

  Future<void> _delete(BuildContext context, Wish wish) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      content: '确定要删除这个愿望吗？',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(wishRepositoryProvider).delete(wish.id);
      if (!context.mounted) return;
      AppSnackbar.showUndo(context, '愿望已删除', () async {
        try {
          await ref.read(wishRepositoryProvider).add(wish);
        } catch (e) {
          debugPrint('[WishesPage] 撤销删除失败: $e');
        }
      });
    } catch (e) {
      debugPrint('[WishesPage] 删除失败: $e');
      if (context.mounted) AppSnackbar.show(context, '删除失败，请重试');
    }
  }

  /// 完成愿望庆祝：询问是否记录到时光线作为回忆里程碑
  Future<void> _celebrate(
    BuildContext context,
    WidgetRef ref,
    Wish wish,
  ) async {
    final record = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('🎉 愿望完成！'),
        content: Text('「${wish.title}」已达成，要把这一刻记录进时光线吗？'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('不用了'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRose,
            ),
            child: const Text('记录到时光线'),
          ),
        ],
      ),
    );
    if (record != true || !context.mounted) return;
    try {
      await ref.read(timelineRepositoryProvider).add(TimelineEvent()
        ..date = DateTime.now()
        ..title = '完成愿望：${wish.title}'
        ..description = '我们一起完成了这个愿望 ✨'
        ..dotColorValue = AppColors.accentRose.toARGB32());
      if (context.mounted) AppSnackbar.show(context, '已记录到时光线 💕');
    } catch (e) {
      debugPrint('[WishesPage] 记录时光线失败: $e');
      if (context.mounted) AppSnackbar.show(context, '记录失败，请重试');
    }
  }
}

class _WishItem extends StatelessWidget {
  final Wish wish;
  final VoidCallback onToggle;
  final VoidCallback onLongPress;

  const _WishItem({
    required this.wish,
    required this.onToggle,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onToggle,
      onLongPress: onLongPress,
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
                // 愿望图标存的是运行时 codePoint；IconData 的 codePoint 带
                // @mustBeConst（为图标 tree-shaking 设计），此处必须忽略 lint
                // ignore: non_const_argument_for_const_parameter
                IconData(wish.iconCodePoint),
                color: AppColors.accentRose,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(wish.title,
                      style: AppTextStyles.titleSmall.copyWith(fontSize: 15)),
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
