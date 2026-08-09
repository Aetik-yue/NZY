import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import 'tetris_model.dart';
import 'tetris_painter.dart';
import 'tetris_status_overlay.dart';

/// HUD 单元（分数 / 级别 / 行数）
class TetrisHud extends StatelessWidget {
  final String label;
  final String value;

  const TetrisHud({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.label),
        Text(value, style: AppTextStyles.titleSmall),
      ],
    );
  }
}

/// 单块预览面板（Hold 用）：标题 + spawn 态方块绘制
class TetrisHoldPanel extends StatelessWidget {
  final String title;
  final TetrominoType? type;

  const TetrisHoldPanel({super.key, required this.title, required this.type});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(title, style: AppTextStyles.label),
        const SizedBox(height: 4),
        SizedBox(
          width: 56,
          height: 48,
          child: CustomPaint(painter: TetrominoPainter(type: type)),
        ),
      ],
    );
  }
}

/// Next 队列面板：展示前 3 个待出方块
class TetrisNextPanel extends StatelessWidget {
  final List<TetrominoType> queue;

  const TetrisNextPanel({super.key, required this.queue});

  @override
  Widget build(BuildContext context) {
    final next3 = queue.take(3).toList();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('NEXT', style: AppTextStyles.label),
        const SizedBox(height: 4),
        for (final t in next3)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: SizedBox(
              width: 56,
              height: 36,
              child: CustomPaint(painter: TetrominoPainter(type: t)),
            ),
          ),
      ],
    );
  }
}

/// 操作按钮（HOLD / DROP）
class TetrisActionButton extends StatelessWidget {
  final String label;
  final Color background;
  final VoidCallback onTap;

  const TetrisActionButton({
    super.key,
    required this.label,
    required this.background,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: onTap,
        style: FilledButton.styleFrom(
          backgroundColor: background,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusSm)),
        ),
        child: Text(label,
            style: AppTextStyles.titleXs
                .copyWith(color: AppColors.textPrimary)),
      ),
    );
  }
}

/// 侧栏列（Hold+按钮 / Next+按钮）
class TetrisSideColumn extends StatelessWidget {
  final double width;
  final List<Widget> children;

  const TetrisSideColumn({
    super.key,
    required this.width,
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: Column(children: children),
    );
  }
}

/// 游戏场：CustomPaint + 手势 + 状态遮罩
class TetrisGameField extends StatelessWidget {
  final double fieldW;
  final double fieldH;
  final double cellW;
  final TetrisBoard board;
  final Piece? current;
  final int ghostRow;
  final Set<int> clearingRows;
  final double clearProgress;
  final TetrisStatus status;
  final int score;
  final int level;
  final int lines;
  final void Function(DragUpdateDetails) onHorizontalDragUpdate;
  final void Function(DragUpdateDetails) onVerticalDragUpdate;
  final VoidCallback onTap;
  final VoidCallback onStart;
  final VoidCallback onRestart;

  const TetrisGameField({
    super.key,
    required this.fieldW,
    required this.fieldH,
    required this.cellW,
    required this.board,
    required this.current,
    required this.ghostRow,
    required this.clearingRows,
    required this.clearProgress,
    required this.status,
    required this.score,
    required this.level,
    required this.lines,
    required this.onHorizontalDragUpdate,
    required this.onVerticalDragUpdate,
    required this.onTap,
    required this.onStart,
    required this.onRestart,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: fieldW,
      height: fieldH,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // 水平/垂直轴向专用识别器：纯点按不被任一拖动抢占，tap 旋转保留（修复 #9）
        onHorizontalDragUpdate: onHorizontalDragUpdate,
        onVerticalDragUpdate: onVerticalDragUpdate,
        onTap: onTap,
        child: Stack(
          children: [
            CustomPaint(
              size: Size(fieldW, fieldH),
              painter: TetrisPainter(
                board: board,
                current: current,
                ghostRow: ghostRow,
                clearingRows: clearingRows,
                clearProgress: clearProgress,
              ),
            ),
            if (status != TetrisStatus.playing)
              TetrisStatusOverlay(
                status: status,
                score: score,
                level: level,
                lines: lines,
                onStart: onStart,
                onRestart: onRestart,
              ),
          ],
        ),
      ),
    );
  }
}

/// 顶部栏：返回 + 标题 + 播放/暂停切换
class TetrisAppBar extends StatelessWidget implements PreferredSizeWidget {
  final TetrisStatus status;
  final VoidCallback onStart;
  final VoidCallback onPause;

  const TetrisAppBar({
    super.key,
    required this.status,
    required this.onStart,
    required this.onPause,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.bgPrimary,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_ios_new,
            size: 20, color: AppColors.textPrimary),
        onPressed: () => Navigator.of(context).pop(),
      ),
      title: Text('俄罗斯方块', style: AppTextStyles.titleMedium),
      centerTitle: true,
      actions: [
        IconButton(
          icon: Icon(
            status == TetrisStatus.playing
                ? Icons.pause_rounded
                : Icons.play_arrow_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () =>
              status == TetrisStatus.playing ? onPause() : onStart(),
        ),
      ],
    );
  }
}
