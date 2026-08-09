import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/features/games/tetris/tetris_model.dart';

void main() {
  group('refillBag', () {
    test('一袋恰好 7 种各一个', () {
      final bag = refillBag(Random(42));
      expect(bag.length, 7);
      expect(bag.toSet().length, 7);
    });
    test('12 块内必见每种（公平性）', () {
      final rng = Random(7);
      final drawn = <TetrominoType>[];
      for (var i = 0; i < 2; i++) {
        drawn.addAll(refillBag(rng));
      }
      for (final t in TetrominoType.values) {
        expect(drawn.where((e) => e == t).length, 2);
      }
    });
  });

  group('cellsOf', () {
    test('I spawn 横排 4 格', () {
      final cells = cellsOf(TetrominoType.I, 0);
      expect(cells.length, 4);
      expect(cells.map((p) => p.r).toSet(), {1});
    });
    test('T 旋转 4 态坐标深比较（修复 #13：校验具体坐标而非引用互异）', () {
      expect(cellsOf(TetrominoType.T, 0), [
        (r: 0, c: 1), (r: 1, c: 0), (r: 1, c: 1), (r: 1, c: 2),
      ]);
      expect(cellsOf(TetrominoType.T, 1), [
        (r: 1, c: 2), (r: 0, c: 1), (r: 1, c: 1), (r: 2, c: 1),
      ]);
      expect(cellsOf(TetrominoType.T, 2), [
        (r: 2, c: 1), (r: 1, c: 2), (r: 1, c: 1), (r: 1, c: 0),
      ]);
      expect(cellsOf(TetrominoType.T, 3), [
        (r: 1, c: 0), (r: 2, c: 1), (r: 1, c: 1), (r: 0, c: 1),
      ]);
    });
    test('I 旋转 4 态坐标深比较（修复 #13）', () {
      expect(cellsOf(TetrominoType.I, 0), [
        (r: 1, c: 0), (r: 1, c: 1), (r: 1, c: 2), (r: 1, c: 3),
      ]);
      expect(cellsOf(TetrominoType.I, 1), [
        (r: 0, c: 2), (r: 1, c: 2), (r: 2, c: 2), (r: 3, c: 2),
      ]);
      expect(cellsOf(TetrominoType.I, 2), [
        (r: 2, c: 3), (r: 2, c: 2), (r: 2, c: 1), (r: 2, c: 0),
      ]);
      expect(cellsOf(TetrominoType.I, 3), [
        (r: 3, c: 1), (r: 2, c: 1), (r: 1, c: 1), (r: 0, c: 1),
      ]);
    });
    test('O 任意旋转态相同', () {
      expect(cellsOf(TetrominoType.O, 0), cellsOf(TetrominoType.O, 2));
    });
  });

  group('isValidPosition', () {
    test('空盘 spawn 合法', () {
      final board = emptyBoard();
      expect(isValidPosition(board, const Piece(type: TetrominoType.T, col: 3)), isTrue);
    });
    test('越左边界非法', () {
      final board = emptyBoard();
      expect(isValidPosition(board, const Piece(type: TetrominoType.T, col: -1)), isFalse);
    });
    test('撞已占格非法', () {
      final board = emptyBoard();
      board[0][4] = TetrominoType.I;
      expect(isValidPosition(board, const Piece(type: TetrominoType.T, col: 3)), isFalse);
    });
    test('底行外非法', () {
      final board = emptyBoard();
      expect(
        isValidPosition(board, const Piece(type: TetrominoType.I, row: 19, col: 0)),
        isFalse,
      );
    });
  });

  group('rotate + wall kick', () {
    test('空盘中央顺时针旋转成功', () {
      final board = emptyBoard();
      const p = Piece(type: TetrominoType.T, row: 5, col: 3);
      final r = rotate(board, p, 1);
      expect(r, isNotNull);
      expect(r!.rotation, 1);
    });
    test('T 旋转撞占位格触发踢墙（非零 kick 偏移，修复 #13）', () {
      final board = emptyBoard();
      // T 在 col=1 spawn 态合法；CW 后 0 偏移态会撞 (7,2)，
      // JLSTZ 表 (0,1) 第 2 项 kick (dc=-1,dr=0) 生效 -> 落到 col=0
      board[7][2] = TetrominoType.I;
      const p = Piece(type: TetrominoType.T, rotation: 0, row: 5, col: 1);
      expect(isValidPosition(board, p), isTrue);
      final r = rotate(board, p, 1);
      expect(r, isNotNull);
      expect(r!.rotation, 1);
      expect(r.col, 0); // kick dc=-1
      expect(r.row, 5); // dr=0
    });
    test('I 靠右墙旋转踢墙使用非零偏移', () {
      final board = emptyBoard();
      // I 竖态（rotation 1）贴右墙 col=7 合法（绝对列 9）；
      // CW 到水平态 0 偏移会越右界（col 10），I 表 (1,2) 第 2 项 kick dc=-1 -> col=6
      const p = Piece(type: TetrominoType.I, rotation: 1, row: 5, col: 7);
      expect(isValidPosition(board, p), isTrue);
      final r = rotate(board, p, 1);
      expect(r, isNotNull);
      expect(r!.rotation, 2);
      expect(r.col, 6); // kick dc=-1
      expect(r.row, 5); // dr=0
    });
    test('被占格完全堵死返回 null', () {
      final board = emptyBoard();
      // 用 I 填满 T 周围一圈，使所有 kick 失败
      for (var r = 4; r <= 7; r++) {
        for (var c = 2; c <= 6; c++) {
          board[r][c] = TetrominoType.I;
        }
      }
      const p = Piece(type: TetrominoType.T, row: 5, col: 3);
      expect(rotate(board, p, 1), isNull);
    });
    test('O 旋转不变', () {
      final board = emptyBoard();
      const p = Piece(type: TetrominoType.O, row: 5, col: 4);
      final r = rotate(board, p, 1);
      expect(r, isNotNull);
      expect(r!.rotation, 0);
    });
  });

  group('clearLines', () {
    test('无满行返回 0 且不变', () {
      final board = emptyBoard();
      expect(clearLines(board), 0);
      expect(board.length, 20);
    });
    test('单行消除', () {
      final board = emptyBoard();
      for (var c = 0; c < 10; c++) {
        board[19][c] = TetrominoType.I;
      }
      expect(clearLines(board), 1);
      expect(board[19].every((c) => c == null), isTrue);
    });
    test('Tetris 四行消除', () {
      final board = emptyBoard();
      for (var r = 16; r <= 19; r++) {
        for (var c = 0; c < 10; c++) {
          board[r][c] = TetrominoType.I;
        }
      }
      expect(clearLines(board), 4);
      expect(board[16].every((c) => c == null), isTrue);
      expect(board[19].every((c) => c == null), isTrue);
    });
  });

  group('gravityInterval', () {
    test('L0 = 1s', () {
      expect(gravityInterval(0).inMilliseconds, 1000);
    });
    test('L9 = 0.11s（spec 锚点）', () {
      expect(gravityInterval(9).inMilliseconds, 110);
    });
    test('L19 = 0.03s（spec 锚点）', () {
      expect(gravityInterval(19).inMilliseconds, 30);
    });
    test('L29 = 0.02s（spec 锚点）', () {
      expect(gravityInterval(29).inMilliseconds, 20);
    });
    test('级别越高越快（单调非增）', () {
      var prev = gravityInterval(0).inMilliseconds;
      for (var lv = 1; lv <= 29; lv++) {
        final cur = gravityInterval(lv).inMilliseconds;
        expect(cur, lessThanOrEqualTo(prev));
        prev = cur;
      }
    });
    test('L29+ 趋近 20G（<=33ms）', () {
      expect(gravityInterval(50).inMilliseconds, 20);
    });
  });

  group('isBlockOut', () {
    test('spawn 位被占 -> 游戏结束', () {
      final board = emptyBoard();
      // T spawn 在 col=3 时顶部格为 (0,4)；占据该格即 spawn 位被占
      board[0][4] = TetrominoType.I;
      expect(isBlockOut(board, const Piece(type: TetrominoType.T, col: 3)), isTrue);
    });
    test('空盘 spawn 不结束', () {
      expect(isBlockOut(emptyBoard(), const Piece(type: TetrominoType.T, col: 3)), isFalse);
    });
  });
}
