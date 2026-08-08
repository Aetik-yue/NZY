import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';

/// 砖块颜色（按行/分值，经典打砖块彩色行）
enum BrickKind { rose, pink, coral, peach, mauve }

extension BrickKindX on BrickKind {
  Color get color => switch (this) {
        BrickKind.rose => AppColors.accentRose,
        BrickKind.pink => AppColors.accentPink,
        BrickKind.coral => AppColors.accentCoral,
        BrickKind.peach => AppColors.accentPeach,
        BrickKind.mauve => AppColors.accentMauve,
      };
  int get score => switch (this) {
        BrickKind.rose => 50,
        BrickKind.pink => 40,
        BrickKind.coral => 30,
        BrickKind.peach => 20,
        BrickKind.mauve => 10,
      };
}

/// 单个砖块（逻辑坐标，row/col 网格定位）
class Brick {
  final int row;
  final int col;
  final BrickKind kind;
  bool alive;
  Brick({required this.row, required this.col, required this.kind, this.alive = true});
}

/// 球（逻辑坐标 0..1，r 为半径）
class Ball {
  double x, y;
  double vx, vy;
  final double r;
  Ball({required this.x, required this.y, required this.vx, required this.vy, required this.r});
}

/// 挡板（x 为左边缘，width 为宽）
class Paddle {
  double x;
  final double width;
  Paddle({required this.x, required this.width});
}

/// 游戏状态
enum BreakoutStatus { ready, playing, paused, levelClear, gameWin, gameOver }

/// 关卡布局：0=无砖，1..5 对应 BrickKind.index+1
class Level {
  final List<List<int>> bricks;
  final double ballSpeed; // 逻辑单位/帧
  const Level({required this.bricks, required this.ballSpeed});
}

/// 3 关递进布局（8 列，行数/密度递增，球速递增）
const kBreakoutLevels = <Level>[
  Level(bricks: [
    [1, 1, 1, 1, 1, 1, 1, 1],
    [2, 2, 2, 2, 2, 2, 2, 2],
    [3, 3, 3, 3, 3, 3, 3, 3],
    [4, 4, 4, 4, 4, 4, 4, 4],
  ], ballSpeed: 0.0045),
  Level(bricks: [
    [1, 1, 1, 1, 1, 1, 1, 1],
    [2, 2, 2, 2, 2, 2, 2, 2],
    [3, 3, 3, 3, 3, 3, 3, 3],
    [4, 4, 4, 4, 4, 4, 4, 4],
    [5, 5, 5, 5, 5, 5, 5, 5],
  ], ballSpeed: 0.0055),
  Level(bricks: [
    [1, 1, 1, 1, 1, 1, 1, 1],
    [2, 2, 0, 0, 0, 0, 2, 2],
    [3, 3, 3, 3, 3, 3, 3, 3],
    [4, 4, 0, 0, 0, 0, 4, 4],
    [5, 5, 5, 5, 5, 5, 5, 5],
    [1, 2, 3, 4, 4, 3, 2, 1],
  ], ballSpeed: 0.0065),
];

/// 关卡砖块顶部偏移（逻辑 y）
const kBrickTop = 0.12;
/// 砖块高度（逻辑）
const kBrickHeight = 0.035;
/// 砖块列间距系数（gap = brickH * 0.08）
const kBrickGapRatio = 0.08;

/// 把关卡布局转为 Brick 列表
List<Brick> buildBricks(Level level) {
  final result = <Brick>[];
  for (var r = 0; r < level.bricks.length; r++) {
    final row = level.bricks[r];
    for (var c = 0; c < row.length; c++) {
      final v = row[c];
      if (v == 0) continue;
      result.add(Brick(row: r, col: c, kind: BrickKind.values[v - 1]));
    }
  }
  return result;
}

/// 球与砖块碰撞结果
class BrickHit {
  final Brick brick;
  final bool bounceX;
  final bool bounceY;
  BrickHit({required this.brick, this.bounceX = false, this.bounceY = false});
}

/// 检测球与砖块碰撞（纯函数）
///
/// 返回命中的砖块（alive=true 且矩形与球圆相交）+ 反弹方向。
/// 反弹方向：用球中心相对砖块中心的方向（|relX|>|relY| -> bounceX，否则 bounceY）。
BrickHit? collideBrick(Ball ball, List<Brick> bricks, double brickW, double brickH, double top) {
  for (final b in bricks) {
    if (!b.alive) continue;
    final bx = b.col * brickW;
    final by = top + b.row * (brickH + brickH * kBrickGapRatio);
    final nearestX = ball.x.clamp(bx, bx + brickW);
    final nearestY = ball.y.clamp(by, by + brickH);
    final dx = ball.x - nearestX;
    final dy = ball.y - nearestY;
    if (dx * dx + dy * dy <= ball.r * ball.r) {
      final cx = bx + brickW / 2;
      final cy = by + brickH / 2;
      final relX = (ball.x - cx) / (brickW / 2);
      final relY = (ball.y - cy) / (brickH / 2);
      if (relX.abs() > relY.abs()) {
        return BrickHit(brick: b, bounceX: true);
      } else {
        return BrickHit(brick: b, bounceY: true);
      }
    }
  }
  return null;
}

/// 关卡是否清除（所有砖块 alive=false）
bool levelCleared(List<Brick> bricks) => bricks.every((b) => !b.alive);
