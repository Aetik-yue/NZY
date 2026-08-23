import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import 'breakout_model.dart';

/// 打砖块状态遮罩（准备 / 暂停 / 过关 / 通关 / 结束）
///
/// 根据 [status] 显示标题、提示与动作按钮；按钮按下后按状态路由到对应回调。
class BreakoutStatusOverlay extends StatelessWidget {
  final BreakoutStatus status;
  final int levelIndex;
  final int score;
  final VoidCallback onStart;
  final VoidCallback onNextLevel;
  final VoidCallback onRestart;

  const BreakoutStatusOverlay({
    super.key,
    required this.status,
    required this.levelIndex,
    required this.score,
    required this.onStart,
    required this.onNextLevel,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final (title, hint, action) = switch (status) {
      BreakoutStatus.ready => ('准备好了吗', '点击屏幕或拖动开始', '开始'),
      BreakoutStatus.paused => ('已暂停', '点击继续', '继续'),
      BreakoutStatus.levelClear => ('过关！', '第 ${levelIndex + 1} 关完成', '下一关'),
      BreakoutStatus.gameWin => ('通关啦 🎉', '总分 $score', '再玩一次'),
      BreakoutStatus.gameOver => ('游戏结束', '得分 $score', '重新开始'),
      BreakoutStatus.playing => ('', '', ''),
    };
    return Container(
      color: AppColors.gameScrim,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title,
                style: AppTextStyles.titleLarge.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text(hint,
                style: AppTextStyles.body.copyWith(color: Colors.white70)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                switch (status) {
                  case BreakoutStatus.ready:
                  case BreakoutStatus.paused:
                    onStart();
                    break;
                  case BreakoutStatus.levelClear:
                    onNextLevel();
                    break;
                  case BreakoutStatus.gameWin:
                  case BreakoutStatus.gameOver:
                    onRestart();
                    break;
                  case BreakoutStatus.playing:
                    break;
                }
              },
              style:
                  FilledButton.styleFrom(backgroundColor: AppColors.accentRose),
              child: Text(action,
                  style: AppTextStyles.body.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
