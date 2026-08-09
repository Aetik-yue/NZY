import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import 'tetris_model.dart';

/// 俄罗斯方块主绘制器
///
/// 棋盘 10×20，cellSize = width/10。绘制顺序：深底 -> 网格细线 ->
/// 已锁定格 -> Ghost 轮廓 -> 当前方块 -> 消行闪光（动画期间）。
class TetrisPainter extends CustomPainter {
  final TetrisBoard board;
  final Piece? current;
  final int ghostRow; // Ghost 方块 origin 行
  final Set<int> clearingRows;
  final double clearProgress; // 0..1

  const TetrisPainter({
    required this.board,
    required this.current,
    required this.ghostRow,
    this.clearingRows = const {},
    this.clearProgress = 0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bgPaint = Paint()..color = AppColors.gameBgDark;
    canvas.drawRect(Offset.zero & size, bgPaint);

    final cell = size.width / kTetrisCols;
    // 网格细线
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var c = 1; c < kTetrisCols; c++) {
      canvas.drawLine(Offset(c * cell, 0), Offset(c * cell, size.height), gridPaint);
    }
    for (var r = 1; r < kTetrisRows; r++) {
      canvas.drawLine(Offset(0, r * cell), Offset(size.width, r * cell), gridPaint);
    }

    // 已锁定格
    for (var r = 0; r < kTetrisRows; r++) {
      for (var c = 0; c < kTetrisCols; c++) {
        final t = board[r][c];
        if (t == null) continue;
        final flash = clearingRows.contains(r);
        _drawBlock(canvas, _rect(c, r, cell), t.color,
            flash ? 1.0 - clearProgress : 1.0, flash);
      }
    }

    // Ghost（落点预览）：半透明轮廓
    if (current != null && clearingRows.isEmpty) {
      final ghost = current!.copyWith(row: ghostRow);
      for (final p in ghost.absoluteCells()) {
        if (p.r < 0 || p.r >= kTetrisRows) continue;
        final rect = _rect(p.c, p.r, cell).deflate(cell * 0.08);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, Radius.circular(cell * 0.18)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = cell * 0.08
            ..color = current!.type.color.withValues(alpha: 0.22),
        );
      }
    }

    // 当前方块
    if (current != null) {
      for (final p in current!.absoluteCells()) {
        if (p.r < 0 || p.r >= kTetrisRows) continue;
        _drawBlock(canvas, _rect(p.c, p.r, cell), current!.type.color, 1.0, false);
      }
    }
  }

  Rect _rect(int c, int r, double cell) =>
      Rect.fromLTWH(c * cell, r * cell, cell, cell);

  /// 绘制单格：2-stop 渐变 + 圆角 + 内高光描边；[flash] 时叠加白色闪光
  void _drawBlock(Canvas canvas, Rect rect, Color color, double alpha, bool flash) {
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(rect.width * 0.04),
      Radius.circular(rect.width * 0.16),
    );
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          color.withValues(alpha: 0.95 * alpha),
          color.withValues(alpha: 0.72 * alpha),
        ],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);
    canvas.drawRRect(
      rrect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = rect.width * 0.05
        ..color = Colors.white.withValues(alpha: 0.28 * alpha),
    );
    if (flash) {
      canvas.drawRRect(
        rrect,
        Paint()..color = Colors.white.withValues(alpha: clearProgress * 0.8),
      );
    }
  }

  /// 游戏循环每帧原地改写 board/current（同引用），引用比较恒 false，故始终重绘
  @override
  bool shouldRepaint(covariant TetrisPainter old) => true;
}

/// 单块预览绘制器（Hold / Next 面板用）
///
/// 在给定 [size] 内居中绘制 spawn 态方块，自动按 box size 缩放。
class TetrominoPainter extends CustomPainter {
  final TetrominoType? type;

  const TetrominoPainter({required this.type});

  @override
  void paint(Canvas canvas, Size size) {
    if (type == null) return;
    final cells = cellsOf(type!, 0);
    final boxSize = kBoxSize[type!]!;
    // 紧凑包围盒：按实际 cells 的行列范围居中（修复 I 型预览偏下）
    // I spawn cells 全在 row 1，按含空行的 box 居中会整体偏下；
    // 改用 min/max 实际占用范围，去空行/空列后居中。
    final minR = cells.map((p) => p.r).reduce((a, b) => a < b ? a : b);
    final maxR = cells.map((p) => p.r).reduce((a, b) => a > b ? a : b);
    final minC = cells.map((p) => p.c).reduce((a, b) => a < b ? a : b);
    final maxC = cells.map((p) => p.c).reduce((a, b) => a > b ? a : b);
    final rows = maxR - minR + 1;
    final cols = maxC - minC + 1;
    final cell = size.shortestSide / boxSize * 0.8;
    final offsetX = (size.width - cols * cell) / 2;
    final offsetY = (size.height - rows * cell) / 2;
    for (final p in cells) {
      final rect = Rect.fromLTWH(
        offsetX + (p.c - minC) * cell,
        offsetY + (p.r - minR) * cell,
        cell,
        cell,
      );
      final rrect = RRect.fromRectAndRadius(
        rect.deflate(cell * 0.06),
        Radius.circular(cell * 0.16),
      );
      canvas.drawRRect(
        rrect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [type!.color.withValues(alpha: 0.95), type!.color.withValues(alpha: 0.72)],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(covariant TetrominoPainter old) => old.type != type;
}
