import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/timeline_event.dart';
import '../../../data/providers/data_providers.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import 'widgets/add_timeline_sheet.dart';
import 'widgets/timeline_detail_sheet.dart';

/// 时光线全量页（二级页）
///
/// 按年月分组展示全部时光事件，长按可编辑/删除（确认 + 撤销）。
class TimelineAllPage extends ConsumerWidget {
  const TimelineAllPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(timelineEventsProvider);
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
        title: Text('我们的时光', style: AppTextStyles.titleMedium),
        centerTitle: true,
      ),
      body: eventsAsync.when(
        data: (events) {
          if (events.isEmpty) {
            return const Center(child: Text('还没有时光记录'));
          }
          final groups = _groupByMonth(events);
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              for (final group in groups) ...[
                if (group != groups.first) const SizedBox(height: 24),
                Text(group.label, style: AppTextStyles.titleSmall),
                const SizedBox(height: 12),
                for (final event in group.events) ...[
                  _TimelineRow(
                    event: event,
                    onTap: () =>
                        TimelineDetailSheet.show(context, event: event),
                    onLongPress: () => _showActions(context, ref, event),
                  ),
                  const SizedBox(height: 16),
                ],
              ],
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, __) => const Center(child: Text('加载失败')),
      ),
    );
  }

  /// 按年月分组（降序，最新在前）
  List<_MonthGroup> _groupByMonth(List<TimelineEvent> events) {
    final sorted = [...events]..sort((a, b) => b.date.compareTo(a.date));
    final map = <String, List<TimelineEvent>>{};
    for (final e in sorted) {
      final key = '${e.date.year}年${e.date.month}月';
      map.putIfAbsent(key, () => []).add(e);
    }
    return map.entries
        .map((e) => _MonthGroup(label: e.key, events: e.value))
        .toList();
  }

  /// 长按操作单：编辑 / 删除（与首页时光线交互一致）
  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    TimelineEvent event,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
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
        await AddTimelineSheet.show(context, initial: event);
      case 'delete':
        await _delete(context, ref, event);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    TimelineEvent event,
  ) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      content: '确定要删除这条时光记录吗？',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(timelineRepositoryProvider).delete(event.id);
      if (!context.mounted) return;
      AppSnackbar.showUndo(context, '时光已删除', () async {
        try {
          await ref.read(timelineRepositoryProvider).add(event);
        } catch (e) {
          debugPrint('[TimelineAllPage] 撤销删除失败: $e');
        }
      });
    } catch (e) {
      debugPrint('[TimelineAllPage] 删除失败: $e');
      if (context.mounted) AppSnackbar.show(context, '删除失败，请重试');
    }
  }
}

/// 年月分组
class _MonthGroup {
  final String label;
  final List<TimelineEvent> events;
  const _MonthGroup({required this.label, required this.events});
}

/// 单条时光行
class _TimelineRow extends StatelessWidget {
  final TimelineEvent event;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TimelineRow({
    required this.event,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 14,
            child: Column(
              children: [
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: Color(event.dotColorValue),
                    shape: BoxShape.circle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${event.date.year}.${event.date.month.toString().padLeft(2, '0')}.${event.date.day.toString().padLeft(2, '0')}',
                  style: AppTextStyles.dateLabel,
                ),
                const SizedBox(height: 3),
                Text(event.title, style: AppTextStyles.titleSmall),
                if (event.description.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  Text(event.description, style: AppTextStyles.caption),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
