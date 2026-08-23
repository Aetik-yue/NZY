import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/memo.dart';

/// 优先级色点颜色映射（high=玫瑰粉 / medium=珊瑚 / low=桃色 / none=透明）
Color priorityColor(TodoPriority p) => switch (p) {
      TodoPriority.high => AppColors.accentRose,
      TodoPriority.medium => AppColors.accentCoral,
      TodoPriority.low => AppColors.accentPeach,
      TodoPriority.none => Colors.transparent,
    };

/// 截止日期选择行
///
/// 左侧标签「截止日期」+ 右侧当前值（无/今天/明天/本周/自定义日期），
/// 点击弹 showDatePicker 选择日期，支持清除。逾期高亮在卡片层展示，
/// 此处编辑态只做日期展示。
class DueDateField extends StatelessWidget {
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  const DueDateField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return _FieldRow(
      label: '截止日期',
      trailing: Text(
        value == null ? '无' : _format(value!),
        style: AppTextStyles.body.copyWith(
          color: value == null ? AppColors.textTertiary : AppColors.textPrimary,
        ),
      ),
      onTap: () => _pickDate(context),
      onClear: value == null ? null : () => onChanged(null),
    );
  }

  /// 弹日期选择器；选中后归一化到 00:00:00，避免时分秒影响逾期判断
  Future<void> _pickDate(BuildContext context) async {
    final today = DateTime.now();
    final today0 = DateTime(today.year, today.month, today.day);
    final picked = await showDatePicker(
      context: context,
      initialDate: value ?? today0,
      firstDate: today0.subtract(const Duration(days: 365)),
      lastDate: today0.add(const Duration(days: 365 * 3)),
      helpText: '选择截止日期',
      confirmText: '确定',
      cancelText: '取消',
    );
    if (picked != null) {
      onChanged(DateTime(picked.year, picked.month, picked.day));
    }
  }

  /// 友好展示：今天 / 明天 / 本周内显示周几+日期 / 其余显示 M月D日
  String _format(DateTime d) {
    final today = DateTime.now();
    final today0 = DateTime(today.year, today.month, today.day);
    final due0 = DateTime(d.year, d.month, d.day);
    final diff = due0.difference(today0).inDays;
    if (diff == 0) return '今天';
    if (diff == 1) return '明天';
    if (diff > 0 && diff < 7) {
      const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return '${weekdays[due0.weekday]} ${d.month}/${d.day}';
    }
    return '${d.month}月${d.day}日';
  }
}

/// 优先级选择行（无 / 高 / 中 / 低）
///
/// 4 个胶囊 chip，选中态以对应优先级色着色边框与浅底；非「无」项带色点。
class PriorityField extends StatelessWidget {
  final TodoPriority value;
  final ValueChanged<TodoPriority> onChanged;

  const PriorityField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _options = <(TodoPriority, String)>[
    (TodoPriority.none, '无'),
    (TodoPriority.high, '高'),
    (TodoPriority.medium, '中'),
    (TodoPriority.low, '低'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('优先级', style: AppTextStyles.label),
        const SizedBox(height: 8),
        Wrap(
          spacing: 10,
          children: [
            for (final (p, label) in _options)
              GestureDetector(
                onTap: () => onChanged(p),
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: value == p
                        ? priorityColor(p).withValues(alpha: 0.18)
                        : AppColors.bgCard,
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    border: Border.all(
                      color:
                          value == p ? priorityColor(p) : AppColors.borderSoft,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (p != TodoPriority.none) ...[
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: priorityColor(p),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      Text(
                        label,
                        style: AppTextStyles.caption.copyWith(
                          color: value == p
                              ? AppColors.textPrimary
                              : AppColors.textSecondary,
                          fontWeight:
                              value == p ? FontWeight.w600 : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// 截止日期标签（卡片展示用）
///
/// 逾期且未完成用 accentRose 高亮 + error 图标，否则 textSecondary +
/// 日历图标。逾期按天数提示，近未来用周几+日期，远期用 M月D日。
class DueDateLabel extends StatelessWidget {
  final DateTime dueDate;
  final bool done;
  const DueDateLabel({super.key, required this.dueDate, required this.done});

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final today0 = DateTime(today.year, today.month, today.day);
    final due0 = DateTime(dueDate.year, dueDate.month, dueDate.day);
    final isOverdue = due0.isBefore(today0) && !done;
    final (text, color) = _format(due0, today0, isOverdue);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isOverdue
              ? Icons.error_outline_rounded
              : Icons.event_available_rounded,
          size: 13,
          color: color,
        ),
        const SizedBox(width: 4),
        Text(
          text,
          style: AppTextStyles.label.copyWith(
            color: color,
            fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }

  /// 返回 (展示文本, 颜色)
  (String, Color) _format(DateTime due0, DateTime today0, bool isOverdue) {
    if (isOverdue) {
      final days = today0.difference(due0).inDays;
      return ('逾期 $days 天', AppColors.accentRose);
    }
    final diff = due0.difference(today0).inDays;
    if (diff == 0) return ('今天截止', AppColors.textSecondary);
    if (diff == 1) return ('明天截止', AppColors.textSecondary);
    if (diff > 0 && diff < 7) {
      const weekdays = ['', '周一', '周二', '周三', '周四', '周五', '周六', '周日'];
      return (
        '${weekdays[due0.weekday]} ${due0.month}/${due0.day} 截止',
        AppColors.textSecondary
      );
    }
    return ('${due0.month}月${due0.day}日 截止', AppColors.textSecondary);
  }
}

/// 通用字段行：左标签 + 右侧值 + 点击进入 + 可选清除
class _FieldRow extends StatelessWidget {
  final String label;
  final Widget trailing;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FieldRow({
    required this.label,
    required this.trailing,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Row(
        children: [
          Text(label, style: AppTextStyles.label),
          const SizedBox(width: 12),
          Expanded(child: trailing),
          if (onClear != null)
            GestureDetector(
              onTap: onClear,
              behavior: HitTestBehavior.opaque,
              child: const Icon(
                Icons.close_rounded,
                size: 18,
                color: AppColors.textTertiary,
              ),
            ),
          const SizedBox(width: 4),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: AppColors.textTertiary,
          ),
        ],
      ),
    );
  }
}
