import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/anniversary_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/anniversary.dart';
import '../../../data/providers/data_providers.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import 'widgets/add_anniversary_sheet.dart';

/// 纪念日管理页（二级页）
///
/// 展示全部纪念日及倒数状态；点击条目弹操作单（编辑/删除），
/// 右上角 ＋ 添加新纪念日。
class AnniversaryPage extends ConsumerWidget {
  const AnniversaryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final anniversariesAsync = ref.watch(anniversariesProvider);
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
        title: Text('纪念日', style: AppTextStyles.titleMedium),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_rounded,
                color: AppColors.accentRose, size: 26),
            tooltip: '添加纪念日',
            onPressed: () => AddAnniversarySheet.show(context),
          ),
        ],
      ),
      body: anniversariesAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return _EmptyState();
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) =>
                _AnniversaryCard(item: items[i], onTap: () => _showActions(context, ref, items[i])),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, __) => const Center(child: Text('加载失败')),
      ),
    );
  }

  /// 点击条目弹操作单：编辑 / 删除
  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    Anniversary item,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppColors.radiusSheet)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: AppColors.textSecondary),
              title: const Text('编辑'),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.accentRose),
              title: const Text('删除'),
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
        await AddAnniversarySheet.show(context, initial: item);
      case 'delete':
        await _delete(context, ref, item);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Anniversary item,
  ) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      content: '确定要删除「${item.title}」吗？',
    );
    if (!confirmed || !context.mounted) return;
    try {
      final repo = ref.read(anniversaryRepositoryProvider);
      await repo.delete(item.id);
      if (!context.mounted) return;
      AppSnackbar.showUndo(context, '已删除', () async {
        try {
          await repo.add(item);
        } catch (e) {
          debugPrint('[AnniversaryPage] 撤销删除失败: $e');
        }
      });
    } catch (e) {
      debugPrint('[AnniversaryPage] 删除失败: $e');
      if (context.mounted) AppSnackbar.show(context, '删除失败，请重试');
    }
  }
}

/// 单条纪念日卡片
class _AnniversaryCard extends StatelessWidget {
  final Anniversary item;
  final VoidCallback onTap;

  const _AnniversaryCard({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final today = DateUtilsX.today();
    final days = AnniversaryUtils.daysUntil(item.date, today);
    final years = AnniversaryUtils.anniversaryYearsOf(item.date, today);

    // 副标题：明年 X 周年（若是周年版式）或直接剩余天数
    final String countdown;
    if (days == 0) {
      countdown = '就是今天 🎉';
    } else if (days == 1) {
      countdown = '明天就是！';
    } else {
      countdown = '还有 $days 天';
    }
    final sub = years != null && years > 0 && days != 0
        ? '$countdown · ${years + 1} 周年'
        : countdown;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
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
          children: [
            // 标记圆点
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: Color(item.colorValue),
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 14),
            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: AppTextStyles.titleSmall),
                  const SizedBox(height: 3),
                  Text(
                    '${item.date.month}月${item.date.day}日 · $sub',
                    style: AppTextStyles.caption,
                  ),
                  if (item.note.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(item.note,
                        style: AppTextStyles.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_border_rounded,
              size: 64, color: AppColors.accentPinkSoft),
          const SizedBox(height: 16),
          Text('还没有纪念日', style: AppTextStyles.titleSmall),
          const SizedBox(height: 6),
          Text('记录在一起、生日等特别的日子吧',
              style: AppTextStyles.caption),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => AddAnniversarySheet.show(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
            ),
            child: const Text('添加第一个'),
          ),
        ],
      ),
    );
  }
}
