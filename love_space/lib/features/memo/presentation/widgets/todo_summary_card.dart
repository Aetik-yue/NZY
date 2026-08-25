import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// 待办总览：只回答“还有多少”和“已经完成多少”。
class TodoSummaryCard extends StatelessWidget {
  const TodoSummaryCard({
    super.key,
    required this.active,
    required this.done,
  });

  final int active;
  final int done;

  @override
  Widget build(BuildContext context) {
    final total = active + done;
    final progress = total == 0 ? 0.0 : done / total;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowPinkMedium, blurRadius: 18),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  active == 0 ? '今天的事情都完成了' : '还有 $active 件事等你完成',
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.textOnPink),
                ),
                const SizedBox(height: 6),
                Text(
                  total == 0 ? '写下第一件要做的事吧' : '已经完成 $done 件，继续保持',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textOnPink.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 48,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: progress,
                  strokeWidth: 5,
                  backgroundColor: AppColors.textOnPink.withValues(alpha: 0.28),
                  color: AppColors.textOnPink,
                ),
                Text('$done',
                    style: AppTextStyles.titleXs
                        .copyWith(color: AppColors.textOnPink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
