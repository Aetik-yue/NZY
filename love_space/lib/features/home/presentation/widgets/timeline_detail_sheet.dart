import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/timeline_event.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import 'add_timeline_sheet.dart';

/// 时光事件详情底部弹层
///
/// 展示单条时光的完整内容（日期 / 标题 / 描述 / 标记色），
/// 并提供「编辑」与「删除（确认 + 撤销）」操作。
class TimelineDetailSheet extends ConsumerWidget {
  final TimelineEvent event;

  const TimelineDetailSheet({super.key, required this.event});

  /// 弹出详情弹层
  static Future<void> show(
    BuildContext context, {
    required TimelineEvent event,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppColors.radiusCard)),
      ),
      builder: (_) => TimelineDetailSheet(event: event),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 标题栏
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('时光详情', style: AppTextStyles.titleMedium),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // 日期 + 标记色
            Row(
              children: [
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Color(event.dotColorValue),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(_formatDate(event.date), style: AppTextStyles.dateLabel),
              ],
            ),
            const SizedBox(height: 14),
            Text(event.title, style: AppTextStyles.titleMedium),
            if (event.description.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(event.description, style: AppTextStyles.body),
            ],
            const SizedBox(height: 20),
            // 操作按钮
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      // 先关闭详情，再打开编辑表单（复用新增/编辑二合一表单）
                      Navigator.of(context).pop();
                      AddTimelineSheet.show(context, initial: event);
                    },
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('编辑'),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.accentRose),
                      foregroundColor: AppColors.accentRose,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppColors.radiusMd),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => _delete(context, ref),
                    icon: const Icon(Icons.delete_outline, size: 18),
                    label: const Text('删除'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentRose,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppColors.radiusMd),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// 删除（确认 + 撤销），成功后关闭详情弹层
  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      content: '确定要删除这条时光记录吗？',
    );
    if (!confirmed || !context.mounted) return;
    try {
      final repo = ref.read(timelineRepositoryProvider);
      await repo.delete(event.id);
      if (!context.mounted) return;
      Navigator.of(context).pop();
      AppSnackbar.showUndo(context, '时光已删除', () async {
        try {
          await repo.add(event);
        } catch (e) {
          debugPrint('[TimelineDetailSheet] 撤销删除失败: $e');
        }
      });
    } catch (e) {
      debugPrint('[TimelineDetailSheet] 删除失败: $e');
      if (context.mounted) AppSnackbar.show(context, '删除失败，请重试');
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}年${date.month}月${date.day}日';
  }
}
