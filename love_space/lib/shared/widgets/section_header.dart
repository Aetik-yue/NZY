import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// 区块标题行：左侧标题 + 右侧（可选 trailing + "全部 >"）
class SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback? onAction;

  /// 右侧追加的按钮（如「＋」添加按钮），位于 action 之前
  final Widget? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.actionText = '全部',
    this.onAction,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(title, style: AppTextStyles.titleMedium),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailing != null) trailing!,
            if (onAction != null)
              GestureDetector(
                onTap: onAction,
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(actionText, style: AppTextStyles.label),
                      const SizedBox(width: 2),
                      const Icon(Icons.chevron_right,
                          size: 16, color: AppColors.textTertiary),
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
