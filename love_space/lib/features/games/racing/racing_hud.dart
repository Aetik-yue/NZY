import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// 游戏中始终可见的距离、阶段、纪录和导航控制。
class RacingHud extends StatelessWidget {
  const RacingHud({
    super.key,
    required this.distance,
    required this.bestDistance,
    required this.stage,
    required this.onBack,
    required this.onPause,
    required this.canPause,
  });

  final int distance;
  final int bestDistance;
  final int stage;
  final VoidCallback onBack;
  final VoidCallback onPause;
  final bool canPause;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 0),
      child: Row(
        children: [
          _circleButton(Icons.arrow_back_ios_new_rounded, onBack, '返回'),
          const SizedBox(width: 8),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: AppColors.bgCard.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(AppColors.radiusPill),
                boxShadow: const [
                  BoxShadow(color: AppColors.shadowCard, blurRadius: 12),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _metric(
                      '里程', '$distance m', const ValueKey('racing_distance')),
                  _metric('阶段', '$stage', const ValueKey('racing_stage')),
                  _metric(
                      '最佳', '$bestDistance m', const ValueKey('racing_best')),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          _circleButton(
            Icons.pause_rounded,
            canPause ? onPause : null,
            '暂停',
          ),
        ],
      ),
    );
  }

  Widget _metric(String label, String value, Key key) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTextStyles.label),
          const SizedBox(height: 2),
          Text(
            value,
            key: key,
            style: AppTextStyles.titleXs.copyWith(fontSize: 13),
          ),
        ],
      );

  Widget _circleButton(
    IconData icon,
    VoidCallback? onPressed,
    String tooltip,
  ) =>
      Container(
        decoration: const BoxDecoration(
          color: AppColors.bgCard,
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: AppColors.shadowCard, blurRadius: 12)],
        ),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          color: AppColors.textPrimary,
          icon: Icon(icon, size: 20),
        ),
      );
}
