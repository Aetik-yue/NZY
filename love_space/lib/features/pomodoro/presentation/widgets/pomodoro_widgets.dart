import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../providers/pomodoro_timer_provider.dart';

/// 标签选择行（学习/工作/陪伴/无）
///
/// [selected] 为 null 表示选中「无」；[locked] 为 true 时禁用点击
/// （running/paused 期间锁定，避免中途改 tag 造成记录归属混乱）。
class PomodoroTagRow extends StatelessWidget {
  final List<String> tags;
  final String? selected;
  final bool locked;
  final ValueChanged<String?> onSelected;

  const PomodoroTagRow({
    super.key,
    required this.tags,
    required this.selected,
    required this.locked,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i <= tags.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          _chip(i == tags.length ? null : tags[i]),
        ],
      ],
    );
  }

  Widget _chip(String? label) {
    final isSelected = selected == label;
    return GestureDetector(
      onTap: locked ? null : () => onSelected(label),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentRose : AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          border: Border.all(
            color: isSelected ? AppColors.accentRose : AppColors.borderSoft,
          ),
        ),
        child: Text(
          label ?? '无',
          style: AppTextStyles.label.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}

/// 阶段卡片：渐变背景 + 阶段文案 + 大倒计时 + 番茄进度点
///
/// focus 用粉色渐变（headerGradient），break 用珊瑚/桃色渐变以视觉区分。
class PomodoroPhaseCard extends StatelessWidget {
  final PomodoroTimerState state;
  final int interval;

  const PomodoroPhaseCard({
    super.key,
    required this.state,
    required this.interval,
  });

  @override
  Widget build(BuildContext context) {
    final isFocus = state.phase == FocusPhase.focus;
    final gradient = isFocus
        ? AppColors.headerGradient
        : const LinearGradient(
            colors: [AppColors.accentCoral, AppColors.accentPeach],
          );
    final phaseText = switch (state.phase) {
      FocusPhase.focus => '专注中',
      FocusPhase.shortBreak => '短休息',
      FocusPhase.longBreak => '长休息',
    };
    final m = (state.remainingSec ~/ 60).toString().padLeft(2, '0');
    final ss = (state.remainingSec % 60).toString().padLeft(2, '0');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 34, horizontal: 24),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowPinkMedium,
            blurRadius: 24,
            offset: Offset(0, 8),
            spreadRadius: -6,
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            phaseText,
            style: AppTextStyles.titleMedium
                .copyWith(color: AppColors.textOnPink),
          ),
          const SizedBox(height: 12),
          Text('$m:$ss', style: AppTextStyles.heroNumber),
          const SizedBox(height: 20),
          _buildDots(),
          const SizedBox(height: 8),
          Text(
            _progressLabel(),
            style: AppTextStyles.label
                .copyWith(color: AppColors.textOnPink.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }

  /// 本轮 cycle 内已完成的番茄数
  int get _filled {
    if (state.phase == FocusPhase.longBreak) return interval;
    return state.completedFocusCount % interval;
  }

  String _progressLabel() {
    if (state.phase == FocusPhase.focus) {
      return '第 ${state.completedFocusCount % interval + 1} 个番茄';
    }
    return '已完成 $_filled / $interval';
  }

  /// 番茄进度点：已完成=实心，当前=描边，未到=半透明
  Widget _buildDots() {
    final current = state.phase == FocusPhase.focus
        ? state.completedFocusCount % interval
        : -1;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (int i = 0; i < interval; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          _dot(i < _filled, i == current),
        ],
      ],
    );
  }

  Widget _dot(bool filled, bool current) {
    if (filled) {
      return Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: AppColors.textOnPink,
          shape: BoxShape.circle,
        ),
      );
    }
    if (current) {
      return Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.textOnPink, width: 2),
        ),
      );
    }
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.textOnPink.withValues(alpha: 0.25),
      ),
    );
  }
}

/// 控制按钮区：大圆按钮（开始/继续/暂停）+ 放弃（仅非 idle）
class PomodoroControls extends StatelessWidget {
  final TimerStatus status;
  final VoidCallback onToggle;
  final VoidCallback onAbort;

  const PomodoroControls({
    super.key,
    required this.status,
    required this.onToggle,
    required this.onAbort,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = status == TimerStatus.running;
    final icon = isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 左：放弃（仅非 idle），固定宽度占位保持大按钮居中
        SizedBox(
          width: 64,
          child: status != TimerStatus.idle
              ? TextButton(
                  onPressed: onAbort,
                  child: Text(
                    '放弃',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textTertiary),
                  ),
                )
              : const SizedBox.shrink(),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              gradient: AppColors.pinkButtonGradient,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.shadowPinkStrong,
                  blurRadius: 16,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 36),
          ),
        ),
        const SizedBox(width: 8),
        // 右占位（与左侧对称）
        const SizedBox(width: 64),
      ],
    );
  }
}

/// 今日专注摘要（时长 + 次数）
class PomodoroTodaySummary extends StatelessWidget {
  final int minutes;
  final int count;

  const PomodoroTodaySummary({
    super.key,
    required this.minutes,
    required this.count,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.local_fire_department_rounded,
              size: 18, color: AppColors.accentRose),
          const SizedBox(width: 8),
          Text('今日专注 $minutes 分钟 · $count 次',
              style: AppTextStyles.bodySmall),
        ],
      ),
    );
  }
}
