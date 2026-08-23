import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/focus_session.dart';
import '../../../data/providers/data_providers.dart';

/// 专注统计页（二级页）
///
/// 今日/累计统计 + 最近 10 条专注记录。从 [focusSessionsProvider] 内存聚合，
/// 避免单独查询；记录变化时通过流自动刷新。
class PomodoroStatsPage extends ConsumerWidget {
  const PomodoroStatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(focusSessionsProvider);
    final today = ref.watch(todayFocusProvider);
    final streak = ref.watch(focusStreakProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('专注统计', style: AppTextStyles.titleMedium),
      ),
      body: sessionsAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, __) => const Center(child: Text('加载失败')),
        data: (sessions) {
          // 累计专注时长（所有 completed focus 的 actualMin 之和）
          final totalMin = sessions
              .where((s) => s.type == FocusType.focus && s.completed)
              .fold<int>(0, (sum, s) => sum + s.actualMin);
          final recent = sessions.take(10).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _StatsRow(
                todayMinutes: today.minutes,
                todayCount: today.count,
                totalMinutes: totalMin,
                streak: streak,
              ),
              const SizedBox(height: 24),
              Text('最近记录', style: AppTextStyles.titleSmall),
              const SizedBox(height: 12),
              if (recent.isEmpty)
                const _EmptyRecords()
              else
                ...recent.map((s) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _SessionTile(session: s),
                    )),
            ],
          );
        },
      ),
    );
  }
}

/// 统计卡行（今日时长 / 今日次数 / 累计时长 / 连续天数）
class _StatsRow extends StatelessWidget {
  final int todayMinutes;
  final int todayCount;
  final int totalMinutes;
  final int streak;

  const _StatsRow({
    required this.todayMinutes,
    required this.todayCount,
    required this.totalMinutes,
    required this.streak,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
            child: _StatCard('今日时长', '$todayMinutes 分', Icons.timer_outlined)),
        const SizedBox(width: 8),
        Expanded(
            child:
                _StatCard('今日次数', '$todayCount 次', Icons.check_circle_outline)),
        const SizedBox(width: 8),
        Expanded(
            child: _StatCard('累计专注', '$totalMinutes 分',
                Icons.local_fire_department_outlined)),
        const SizedBox(width: 8),
        Expanded(child: _StatCard('连续天数', '$streak 天', Icons.bolt_outlined)),
      ],
    );
  }
}

/// 单个统计卡
class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;

  const _StatCard(this.label, this.value, this.icon);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 12,
            offset: Offset(0, 3),
            spreadRadius: -3,
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppColors.accentRose),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: AppTextStyles.statNumber.copyWith(fontSize: 15)),
          ),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.label, textAlign: TextAlign.center),
        ],
      ),
    );
  }
}

/// 单条专注记录
class _SessionTile extends StatelessWidget {
  final FocusSession session;
  const _SessionTile({required this.session});

  @override
  Widget build(BuildContext context) {
    final t = session.startTime;
    final time =
        '${_two(t.month)}/${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}';
    final completed = session.completed;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 10,
            offset: Offset(0, 2),
            spreadRadius: -2,
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(
            completed
                ? Icons.check_circle_rounded
                : Icons.remove_circle_rounded,
            size: 20,
            color: completed ? AppColors.accentRose : AppColors.textTertiary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(session.tag ?? '专注', style: AppTextStyles.body),
                const SizedBox(height: 2),
                Text(time, style: AppTextStyles.label),
              ],
            ),
          ),
          Text(
            '${session.actualMin} min',
            style: AppTextStyles.bodySmall.copyWith(
              color: completed ? AppColors.textPrimary : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  /// 两位补零
  String _two(int v) => v.toString().padLeft(2, '0');
}

/// 空记录占位
class _EmptyRecords extends StatelessWidget {
  const _EmptyRecords();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32),
      alignment: Alignment.center,
      child: Text('还没有专注记录', style: AppTextStyles.caption),
    );
  }
}
