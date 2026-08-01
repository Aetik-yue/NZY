import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/wish.dart';
import '../../../data/providers/data_providers.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_dialog.dart';

/// 全部愿望页（二级页）
///
/// 顶部 Tab 切换：全部 / 进行中 / 已完成。
/// 已完成愿望可回看并取消勾选；长按删除（确认 + 撤销）。
class WishesAllPage extends ConsumerStatefulWidget {
  const WishesAllPage({super.key});

  @override
  ConsumerState<WishesAllPage> createState() => _WishesAllPageState();
}

class _WishesAllPageState extends ConsumerState<WishesAllPage> {
  int _tab = 0; // 0=全部 1=进行中 2=已完成

  @override
  Widget build(BuildContext context) {
    final wishesAsync = ref.watch(wishesProvider);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('全部愿望', style: AppTextStyles.titleMedium),
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Tab 切换
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Container(
              height: 36,
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: AppColors.bgBlush,
                borderRadius: BorderRadius.circular(AppColors.radiusPill),
              ),
              child: Row(
                children: [
                  _buildTab(0, '全部'),
                  _buildTab(1, '进行中'),
                  _buildTab(2, '已完成'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 4),
          // 列表
          Expanded(
            child: wishesAsync.when(
              data: (wishes) {
                final filtered = switch (_tab) {
                  1 => wishes.where((w) => !w.done).toList(),
                  2 => wishes.where((w) => w.done).toList(),
                  _ => wishes,
                };
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_border_rounded,
                            size: 48, color: AppColors.textTertiary),
                        const SizedBox(height: 12),
                        Text(
                          _tab == 2 ? '还没有已完成的愿望' : '这里空空如也',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final wish = filtered[i];
                    return _WishRow(
                      wish: wish,
                      onToggle: () => _toggle(context, wish),
                      onDelete: () => _delete(context, wish),
                    );
                  },
                );
              },
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (_, __) => const Center(child: Text('加载失败')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab(int index, String label) {
    final isActive = _tab == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _tab = index),
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppColors.bgCard : Colors.transparent,
            borderRadius: BorderRadius.circular(AppColors.radiusPill),
          ),
          child: Text(
            label,
            style: AppTextStyles.caption.copyWith(
              color: isActive ? AppColors.accentRose : AppColors.textTertiary,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  /// 勾选/取消勾选（已完成也可取消，误触可逆）
  Future<void> _toggle(BuildContext context, Wish wish) async {
    try {
      await ref.read(wishRepositoryProvider).toggleDone(wish.id);
    } catch (e) {
      debugPrint('[WishesAllPage] 切换失败: $e');
      if (context.mounted) AppSnackbar.show(context, '操作失败，请重试');
    }
  }

  Future<void> _delete(BuildContext context, Wish wish) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      content: '确定要删除这个愿望吗？',
    );
    if (!confirmed || !context.mounted) return;
    await ref.read(wishRepositoryProvider).delete(wish.id);
    if (!context.mounted) return;
    AppSnackbar.showUndo(context, '愿望已删除', () async {
      await ref.read(wishRepositoryProvider).add(wish);
    });
  }
}

/// 单条愿望
class _WishRow extends StatelessWidget {
  final Wish wish;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _WishRow({
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
                color: wish.done
                    ? AppColors.accentPeach
                    : AppColors.accentPinkSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                // 愿望图标存的是运行时 codePoint；IconData 的 codePoint 带
                // @mustBeConst（为图标 tree-shaking 设计），此处必须忽略 lint
                // ignore: non_const_argument_for_const_parameter
                IconData(wish.iconCodePoint),
                color: wish.done ? AppColors.accentCoral : AppColors.accentRose,
                size: 22,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    wish.title,
                    style: AppTextStyles.titleSmall.copyWith(
                      fontSize: 15,
                      decoration:
                          wish.done ? TextDecoration.lineThrough : null,
                      color:
                          wish.done ? AppColors.textTertiary : null,
                    ),
                  ),
                  if (wish.description.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(wish.description, style: AppTextStyles.caption),
                  ],
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
