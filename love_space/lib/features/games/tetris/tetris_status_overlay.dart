import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import 'tetris_model.dart';

/// 俄罗斯方块状态遮罩（准备 / 暂停 / 结束）
class TetrisStatusOverlay extends StatelessWidget {
  final TetrisStatus status;
  final int score;
  final int level;
  final int lines;
  final VoidCallback onStart;
  final VoidCallback onRestart;

  const TetrisStatusOverlay({
    super.key,
    required this.status,
    required this.score,
    required this.level,
    required this.lines,
    required this.onStart,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    final (title, hint, action, onTap) = switch (status) {
      TetrisStatus.ready => ('准备好了吗', '点击开始 / 拖动或按钮操作', '开始', onStart),
      TetrisStatus.paused => ('已暂停', '继续游戏', '继续', onStart),
      TetrisStatus.gameOver => (
          '游戏结束',
          '得分 $score · L$level · $lines' '行',
          '重新开始',
          onRestart
        ),
      TetrisStatus.playing => ('', '', '', null),
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
              onPressed: onTap,
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
