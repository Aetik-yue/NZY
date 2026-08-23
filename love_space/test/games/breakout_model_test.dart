import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/features/games/breakout/breakout_model.dart';

void main() {
  group('BrickKind', () {
    test('分值按颜色递减', () {
      expect(BrickKind.rose.score, 50);
      expect(BrickKind.mauve.score, 10);
    });
  });

  group('collideBrick', () {
    const brickW = 0.125, brickH = 0.04, top = 0.1;
    test('球从下方击中砖块底部 -> 返回该砖 + bounceY', () {
      final bricks = [Brick(row: 0, col: 0, kind: BrickKind.rose)];
      final ball =
          Ball(x: 0.06, y: top + brickH + 0.005, vx: 0, vy: -0.02, r: 0.015);
      final hit = collideBrick(ball, bricks, brickW, brickH, top);
      expect(hit, isNotNull);
      expect(hit!.brick, same(bricks[0]));
      expect(hit.bounceY, isTrue);
    });

    test('球未触及砖块 -> 返回 null', () {
      final bricks = [Brick(row: 0, col: 0, kind: BrickKind.rose)];
      final ball = Ball(x: 0.5, y: 0.5, vx: 0, vy: -0.02, r: 0.015);
      expect(collideBrick(ball, bricks, brickW, brickH, top), isNull);
    });

    test('球从侧面击中 -> bounceX', () {
      final bricks = [Brick(row: 0, col: 0, kind: BrickKind.rose)];
      final ball =
          Ball(x: -0.01, y: top + brickH / 2, vx: 0.02, vy: 0, r: 0.015);
      final hit = collideBrick(ball, bricks, brickW, brickH, top);
      expect(hit, isNotNull);
      expect(hit!.bounceX, isTrue);
    });

    test('已 dead 的砖块不命中', () {
      final bricks = [
        Brick(row: 0, col: 0, kind: BrickKind.rose)..alive = false
      ];
      final ball =
          Ball(x: 0.06, y: top + brickH + 0.005, vx: 0, vy: -0.02, r: 0.015);
      expect(collideBrick(ball, bricks, brickW, brickH, top), isNull);
    });

    test('高屏 aspectRatio 下 y 方向碰撞按比例缩放（与视觉正圆一致）', () {
      // 球画成半径 r*w 像素的正圆；高屏（h>w）下逻辑 y 半径 r 对应 r*h 像素 > r*w，
      // 原碰撞在 y 方向“提前命中”。修复后 dy 乘 aspectRatio(h/w) 缩放，使碰撞圆
      // 等效于半径 r*w 像素。此处验证：同一 y 距离，aspectRatio=1 命中、=2 不命中。
      // 坐标：ball 在砖块正下方，dy=0.012，r=0.015（r²=2.25e-4）
      //   aspectRatio=1: 0 + 0.012² = 1.44e-4 ≤ 2.25e-4 -> 命中
      //   aspectRatio=2: 0 + (0.012*2)² = 5.76e-4 > 2.25e-4 -> 不命中
      final bricks = [Brick(row: 0, col: 0, kind: BrickKind.rose)];
      final ball = Ball(
        x: 0.06,
        y: top + brickH + 0.012,
        vx: 0,
        vy: -0.02,
        r: 0.015,
      );
      expect(collideBrick(ball, bricks, brickW, brickH, top), isNotNull);
      expect(
        collideBrick(ball, bricks, brickW, brickH, top, aspectRatio: 2),
        isNull,
      );
    });
  });

  group('collidePaddle', () {
    final paddle = Paddle(x: 0.4, y: 0.92, width: 0.2);
    test('球从上方正面击中挡板 -> bounceY', () {
      final ball = Ball(x: 0.5, y: 0.915, vx: 0, vy: 0.02, r: 0.015);
      final hit = collidePaddle(ball, paddle);
      expect(hit, isNotNull);
      expect(hit!.bounceY, isTrue);
    });

    test('球从侧面击中挡板 -> bounceX', () {
      final ball = Ball(x: 0.39, y: 0.932, vx: 0.02, vy: 0, r: 0.015);
      final hit = collidePaddle(ball, paddle);
      expect(hit, isNotNull);
      expect(hit!.bounceX, isTrue);
    });

    test('球未接触挡板 -> 返回 null', () {
      final ball = Ball(x: 0.5, y: 0.3, vx: 0, vy: 0.02, r: 0.015);
      expect(collidePaddle(ball, paddle), isNull);
    });

    test('球在挡板边界外（水平范围外）-> 不命中', () {
      final ball = Ball(x: 0.1, y: 0.93, vx: 0, vy: 0.02, r: 0.015);
      expect(collidePaddle(ball, paddle), isNull);
    });
  });

  group('levelCleared', () {
    test('全部砖块被清除时返回 true', () {
      final bricks = [
        Brick(row: 0, col: 0, kind: BrickKind.rose)..alive = false,
        Brick(row: 0, col: 1, kind: BrickKind.peach)..alive = false,
      ];
      expect(levelCleared(bricks), isTrue);
    });

    test('仍有砖块存活时返回 false', () {
      final bricks = [
        Brick(row: 0, col: 0, kind: BrickKind.rose)..alive = false,
        Brick(row: 0, col: 1, kind: BrickKind.peach),
      ];
      expect(levelCleared(bricks), isFalse);
    });
  });
}
