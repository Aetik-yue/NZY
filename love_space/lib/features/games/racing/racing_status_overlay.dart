import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import 'racing_model.dart';

/// 准备、倒计时、暂停、碰撞和结算状态覆盖层。
class RacingStatusOverlay extends StatelessWidget {
  const RacingStatusOverlay({
    super.key,
    required this.status,
    required this.countdown,
    required this.distance,
    required this.bestDistance,
    required this.newRecord,
    required this.onStart,
    required this.onResume,
    required this.onRestart,
    required this.onExit,
  });

  final RacingStatus status;
  final int countdown;
  final int distance;
  final int bestDistance;
  final bool newRecord;
  final VoidCallback onStart;
  final VoidCallback onResume;
  final VoidCallback onRestart;
  final VoidCallback onExit;

  @override
  Widget build(BuildContext context) {
    if (status == RacingStatus.playing) return const SizedBox.shrink();
    if (status == RacingStatus.countdown) {
      return IgnorePointer(
        child: Center(
          child: Text(
            '$countdown',
            key: const ValueKey('racing_countdown'),
            style: AppTextStyles.heroNumber.copyWith(
              fontSize: 88,
              shadows: const [
                Shadow(color: AppColors.shadowPinkStrong, blurRadius: 18),
              ],
            ),
          ),
        ),
      );
    }
    if (status == RacingStatus.crashed) {
      return IgnorePointer(
        child: Center(
          child: Text(
            '碰撞！',
            style: AppTextStyles.titleLarge.copyWith(
              color: AppColors.textOnPink,
            ),
          ),
        ),
      );
    }

    return ColoredBox(
      color: AppColors.gameScrim,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Container(
            width: 340,
            padding: const EdgeInsets.all(26),
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(AppColors.radiusCard),
              boxShadow: const [
                BoxShadow(color: AppColors.shadowPinkHero, blurRadius: 30),
              ],
            ),
            child: switch (status) {
              RacingStatus.ready => _ready(),
              RacingStatus.paused => _paused(),
              RacingStatus.gameOver => _gameOver(),
              _ => const SizedBox.shrink(),
            },
          ),
        ),
      ),
    );
  }

  Widget _ready() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.directions_car_filled_rounded,
            color: AppColors.racingPlayerCar,
            size: 54,
          ),
          const SizedBox(height: 14),
          Text('公路闪避', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          Text(
            '在屏幕下半部分左右拖动赛车\n躲开车辆和施工障碍',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(height: 1.55),
          ),
          const SizedBox(height: 10),
          Text('历史最佳 $bestDistance m', style: AppTextStyles.titleXs),
          const SizedBox(height: 22),
          _primaryButton('开始游戏', onStart, const ValueKey('racing_start')),
        ],
      );

  Widget _paused() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.pause_circle_rounded,
              color: AppColors.accentRose, size: 52),
          const SizedBox(height: 12),
          Text('已暂停', style: AppTextStyles.titleLarge),
          const SizedBox(height: 6),
          Text('当前里程 $distance m', style: AppTextStyles.bodySmall),
          const SizedBox(height: 22),
          _primaryButton('继续游戏', onResume, const ValueKey('racing_resume')),
          const SizedBox(height: 10),
          TextButton(onPressed: onExit, child: const Text('结束本局')),
        ],
      );

  Widget _gameOver() => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (newRecord) ...[
            const Icon(Icons.emoji_events_rounded,
                color: AppColors.accentGold, size: 48),
            const SizedBox(height: 8),
            Text('新纪录！',
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.accentRose)),
          ] else
            const Icon(Icons.flag_rounded,
                color: AppColors.racingPlayerCar, size: 48),
          const SizedBox(height: 12),
          Text('本局结束', style: AppTextStyles.titleLarge),
          const SizedBox(height: 10),
          Text('$distance m',
              key: const ValueKey('racing_result'),
              style: AppTextStyles.heroNumber
                  .copyWith(color: AppColors.textPrimary, fontSize: 52)),
          Text('历史最佳 $bestDistance m', style: AppTextStyles.bodySmall),
          const SizedBox(height: 22),
          _primaryButton('再来一局', onRestart, const ValueKey('racing_restart')),
          const SizedBox(height: 10),
          TextButton(onPressed: onExit, child: const Text('返回小游戏')),
        ],
      );

  Widget _primaryButton(String label, VoidCallback onTap, Key key) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          key: key,
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentRose,
            foregroundColor: AppColors.textOnPink,
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: Text(label),
        ),
      );
}
