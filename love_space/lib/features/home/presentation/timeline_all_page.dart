import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/timeline_event.dart';
import '../../../data/providers/data_providers.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_dialog.dart';

/// 时光线全量页（二级页）
///
/// 按年月分组展示全部时光事件，长按可删除（确认 + 撤销）。
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
                  _TimelineRow(event: event, onDelete: () => _delete(context, ref, event)),
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
    await ref.read(timelineRepositoryProvider).delete(event.id);
    if (!context.mounted) return;
    AppSnackbar.showUndo(context, '时光已删除', () async {
      await ref.read(timelineRepositoryProvider).add(event);
    });
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
  final VoidCallback onDelete;

  const _TimelineRow({required this.event, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onDelete,
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
