import 'package:flutter/material.dart';
import 'breakout_model.dart';

/// 打砖块绘制器（逻辑坐标 0..1 -> 实际像素）
///
/// 经典美术：深色背景、彩色砖块行、白色挡板与球。
/// 砖块绘制与 [collideBrick] 共用同一网格：列宽 = 1/cols，行高 = kBrickHeight，
/// 行间距 = brickH * kBrickGapRatio，顶部偏移 kBrickTop，保证视觉与碰撞一致。
class BreakoutPainter extends CustomPainter {
  final List<Brick> bricks;
  final Ball ball;
  final Paddle paddle;
  final int cols;

  const BreakoutPainter({
    required this.bricks,
    required this.ball,
    required this.paddle,
    required this.cols,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 背景：深色（经典打砖块暗背景；AppColors 无对应深色令牌，此处为例外）
    final bgPaint = Paint()..color = const Color(0xFF1A1220);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final w = size.width;
    final h = size.height;
    final brickW = w / cols;
    final brickH = h * kBrickHeight;
    final gap = brickH * kBrickGapRatio;

    // 砖块（圆角矩形 + 行色）。每块在各自网格单元内居中并留 gap，仅作视觉分隔；
    // 碰撞仍按完整单元计算（见 collideBrick），因 gap 远小于球半径，无可见错位。
    for (final b in bricks) {
      if (!b.alive) continue;
      final rect = Rect.fromLTWH(
        b.col * brickW + gap / 2,
        h * kBrickTop + b.row * (brickH + gap),
        brickW - gap,
        brickH,
      );
      final paint = Paint()..color = b.kind.color;
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(h * 0.012)),
        paint,
      );
    }

    // 挡板：白色圆角矩形（y=0.92 与游戏页碰撞逻辑一致）
    final paddleRect = Rect.fromLTWH(
      paddle.x * w,
      h * 0.92,
      paddle.width * w,
      h * 0.025,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(paddleRect, Radius.circular(h * 0.012)),
      Paint()..color = Colors.white,
    );

    // 球：白色实心圆
    canvas.drawCircle(
      Offset(ball.x * w, ball.y * h),
      ball.r * w,
      Paint()..color = Colors.white,
    );
  }

  /// 游戏循环每帧都会原地修改 ball/paddle/bricks（同一对象引用），
  /// 引用比较会恒为 false 导致不重绘，故此处始终重绘。
  @override
  bool shouldRepaint(covariant BreakoutPainter old) => true;
}
