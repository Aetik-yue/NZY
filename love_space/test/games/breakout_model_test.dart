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
      final ball = Ball(x: 0.06, y: top + brickH + 0.005, vx: 0, vy: -0.02, r: 0.015);
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
      final ball = Ball(x: -0.01, y: top + brickH / 2, vx: 0.02, vy: 0, r: 0.015);
      final hit = collideBrick(ball, bricks, brickW, brickH, top);
      expect(hit, isNotNull);
      expect(hit!.bounceX, isTrue);
    });

    test('已 dead 的砖块不命中', () {
      final bricks = [Brick(row: 0, col: 0, kind: BrickKind.rose)..alive = false];
      final ball = Ball(x: 0.06, y: top + brickH + 0.005, vx: 0, vy: -0.02, r: 0.015);
      expect(collideBrick(ball, bricks, brickW, brickH, top), isNull);
    });
  });

  group('levelCleared', () {
    test('全部 alive=false -> true', () {
      final bricks = [
        Brick(row: 0, col: 0, kind: BrickKind.rose)..alive = false,
        Brick(row: 0, col: 1, kind: BrickKind.rose)..alive = false,
      ];
      expect(levelCleared(bricks), isTrue);
    });
    test('仍有 alive -> false', () {
      final bricks = [
        Brick(row: 0, col: 0, kind: BrickKind.rose)..alive = false,
        Brick(row: 0, col: 1, kind: BrickKind.rose),
      ];
      expect(levelCleared(bricks), isFalse);
    });
  });
}
