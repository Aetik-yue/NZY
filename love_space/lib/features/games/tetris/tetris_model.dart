import 'dart:math';

import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';

/// 七种方块（warm pastel classic 配色）
enum TetrominoType { I, O, T, S, Z, J, L }

extension TetrominoTypeX on TetrominoType {
  /// 颜色：4 复用现有令牌 + 3 新增令牌
  Color get color => switch (this) {
        TetrominoType.I => AppColors.accentTeal,
        TetrominoType.O => AppColors.accentGold,
        TetrominoType.T => AppColors.accentRose,
        TetrominoType.S => AppColors.accentSage,
        TetrominoType.Z => AppColors.accentCoral,
        TetrominoType.J => AppColors.accentMauve,
        TetrominoType.L => AppColors.accentPeach,
      };
}

/// 格子坐标（命名记录，便于读 .r/.c）
typedef Cell = ({int r, int c});

/// 游戏状态
enum TetrisStatus { ready, playing, paused, gameOver }

/// 棋盘：10 列 × 20 行可见（无 buffer，方块顶部生成）
typedef TetrisBoard = List<List<TetrominoType?>>;

/// 生成空棋盘
TetrisBoard emptyBoard() => List.generate(20, (_) => List.filled(10, null));

/// 列数
const kTetrisCols = 10;
/// 行数（可见）
const kTetrisRows = 20;

// ──────── SRS：spawn 偏移（相对 origin 左上角）+ box 尺寸 ────────

const kSpawnCells = <TetrominoType, List<Cell>>{
  TetrominoType.I: [(r: 1, c: 0), (r: 1, c: 1), (r: 1, c: 2), (r: 1, c: 3)],
  TetrominoType.O: [(r: 0, c: 0), (r: 0, c: 1), (r: 1, c: 0), (r: 1, c: 1)],
  TetrominoType.T: [(r: 0, c: 1), (r: 1, c: 0), (r: 1, c: 1), (r: 1, c: 2)],
  TetrominoType.S: [(r: 0, c: 1), (r: 0, c: 2), (r: 1, c: 0), (r: 1, c: 1)],
  TetrominoType.Z: [(r: 0, c: 0), (r: 0, c: 1), (r: 1, c: 1), (r: 1, c: 2)],
  TetrominoType.J: [(r: 0, c: 0), (r: 1, c: 0), (r: 1, c: 1), (r: 1, c: 2)],
  TetrominoType.L: [(r: 0, c: 2), (r: 1, c: 0), (r: 1, c: 1), (r: 1, c: 2)],
};

const kBoxSize = <TetrominoType, int>{
  TetrominoType.I: 4,
  TetrominoType.O: 2,
  TetrominoType.T: 3,
  TetrominoType.S: 3,
  TetrominoType.Z: 3,
  TetrominoType.J: 3,
  TetrominoType.L: 3,
};

/// 计算方块在指定旋转态（0..3）下的格子偏移
///
/// 由 spawn 态应用 CW 变换 `(r,c) -> (c, size-1-r)` 迭代得到，
/// 避免手写 28 组偏移的转录错误；O 不旋转直接返回 spawn。
List<Cell> cellsOf(TetrominoType type, int rotation) {
  if (type == TetrominoType.O) return kSpawnCells[type]!;
  var cells = kSpawnCells[type]!;
  final size = kBoxSize[type]!;
  for (var i = 0; i < (rotation % 4); i++) {
    cells = [for (final p in cells) (r: p.c, c: size - 1 - p.r)];
  }
  return cells;
}

// ──────── SRS Wall Kick 表（dc=列偏移, dr=行偏移 正=向下）────────
// 由标准 SRS 表（y-up）转换：dr = -y。JLSTZ 与 I 各 8 组。

const kKicksJlStz = <(int, int), List<({int dc, int dr})>>{
  (0, 1): [(dc: 0, dr: 0), (dc: -1, dr: 0), (dc: -1, dr: -1), (dc: 0, dr: 2), (dc: -1, dr: 2)],
  (1, 0): [(dc: 0, dr: 0), (dc: 1, dr: 0), (dc: 1, dr: 1), (dc: 0, dr: -2), (dc: 1, dr: -2)],
  (1, 2): [(dc: 0, dr: 0), (dc: 1, dr: 0), (dc: 1, dr: 1), (dc: 0, dr: -2), (dc: 1, dr: -2)],
  (2, 1): [(dc: 0, dr: 0), (dc: -1, dr: 0), (dc: -1, dr: -1), (dc: 0, dr: 2), (dc: -1, dr: 2)],
  (2, 3): [(dc: 0, dr: 0), (dc: 1, dr: 0), (dc: 1, dr: -1), (dc: 0, dr: 2), (dc: 1, dr: 2)],
  (3, 2): [(dc: 0, dr: 0), (dc: -1, dr: 0), (dc: -1, dr: 1), (dc: 0, dr: -2), (dc: -1, dr: -2)],
  (3, 0): [(dc: 0, dr: 0), (dc: -1, dr: 0), (dc: -1, dr: 1), (dc: 0, dr: -2), (dc: -1, dr: -2)],
  (0, 3): [(dc: 0, dr: 0), (dc: 1, dr: 0), (dc: 1, dr: -1), (dc: 0, dr: 2), (dc: 1, dr: 2)],
};

const kKicksI = <(int, int), List<({int dc, int dr})>>{
  (0, 1): [(dc: 0, dr: 0), (dc: -2, dr: 0), (dc: 1, dr: 0), (dc: -2, dr: 1), (dc: 1, dr: -2)],
  (1, 0): [(dc: 0, dr: 0), (dc: 2, dr: 0), (dc: -1, dr: 0), (dc: 2, dr: -1), (dc: -1, dr: 2)],
  (1, 2): [(dc: 0, dr: 0), (dc: -1, dr: 0), (dc: 2, dr: 0), (dc: -1, dr: -2), (dc: 2, dr: 1)],
  (2, 1): [(dc: 0, dr: 0), (dc: 1, dr: 0), (dc: -2, dr: 0), (dc: 1, dr: 2), (dc: -2, dr: -1)],
  (2, 3): [(dc: 0, dr: 0), (dc: 2, dr: 0), (dc: -1, dr: 0), (dc: 2, dr: -1), (dc: -1, dr: 2)],
  (3, 2): [(dc: 0, dr: 0), (dc: -2, dr: 0), (dc: 1, dr: 0), (dc: -2, dr: 1), (dc: 1, dr: -2)],
  (3, 0): [(dc: 0, dr: 0), (dc: 1, dr: 0), (dc: -2, dr: 0), (dc: 1, dr: 2), (dc: -2, dr: -1)],
  (0, 3): [(dc: 0, dr: 0), (dc: -1, dr: 0), (dc: 2, dr: 0), (dc: -1, dr: -2), (dc: 2, dr: 1)],
};

/// 当前方块
class Piece {
  final TetrominoType type;
  final int rotation; // 0..3
  final int row;      // origin 行（box 左上）
  final int col;      // origin 列

  const Piece({
    required this.type,
    this.rotation = 0,
    this.row = 0,
    this.col = 3,
  });

  /// 绝对格子坐标
  List<Cell> absoluteCells() {
    final base = cellsOf(type, rotation);
    return [for (final p in base) (r: p.r + row, c: p.c + col)];
  }

  Piece copyWith({int? rotation, int? row, int? col}) => Piece(
        type: type,
        rotation: rotation ?? this.rotation,
        row: row ?? this.row,
        col: col ?? this.col,
      );
}

/// 7-bag 随机生成器（公平发牌）
List<TetrominoType> refillBag([Random? rng]) {
  final r = rng ?? Random();
  return TetrominoType.values.toList()..shuffle(r);
}

/// 碰撞检测（边界 + 已占格）
bool isValidPosition(TetrisBoard board, Piece piece) {
  for (final p in piece.absoluteCells()) {
    if (p.c < 0 || p.c >= kTetrisCols || p.r < 0 || p.r >= kTetrisRows) {
      return false;
    }
    if (board[p.r][p.c] != null) return false;
  }
  return true;
}

/// SRS 旋转 + wall kick
///
/// [dir] = +1 顺时针 / -1 逆时针。按序尝试 kick 表，首个合法位置生效；
/// 全部失败返回 null（方块不变）。O 不旋转。
Piece? rotate(TetrisBoard board, Piece piece, int dir) {
  if (piece.type == TetrominoType.O) return piece;
  final from = piece.rotation;
  final to = (piece.rotation + dir + 4) % 4;
  final kicks = piece.type == TetrominoType.I
      ? kKicksI[(from, to)]!
      : kKicksJlStz[(from, to)]!;
  for (final k in kicks) {
    final candidate = piece.copyWith(
      rotation: to,
      col: piece.col + k.dc,
      row: piece.row + k.dr,
    );
    if (isValidPosition(board, candidate)) return candidate;
  }
  return null;
}

/// 消除满行，返回消除数（就地修改 board，上方下移）
int clearLines(TetrisBoard board) {
  var cleared = 0;
  for (var r = board.length - 1; r >= 0; r--) {
    if (board[r].every((c) => c != null)) {
      board.removeAt(r);
      board.insert(0, List<TetrominoType?>.filled(kTetrisCols, null));
      cleared++;
      r++; // 该索引现已是原 r-1 行，抵消循环 r-- 以复检
    }
  }
  return cleared;
}

/// Block out 检测（spawn 位被占 -> 游戏结束）
bool isBlockOut(TetrisBoard board, Piece piece) => !isValidPosition(board, piece);

/// 消行分值（0..4 行）
const kLineScores = [0, 100, 300, 500, 800];

/// 级别 -> 下落间隔（L0=1s 递减到 L29+=20ms，趋近 20G）
///
/// spec 锚点：L0=1.0s / L9=0.11s / L19+=0.03s / L29+=0.02s。L15-28 平滑到 30ms。
Duration gravityInterval(int level) {
  const ms = [
    1000, 793, 618, 473, 355, 300, 218, 164, 135, 110, // 0-9
    88, 72, 57, 46, 38, 33, 30, 30, 30, 30, // 10-19
    30, 30, 30, 30, 30, 30, 30, 30, 30, // 20-28
  ];
  if (level >= 29) return const Duration(milliseconds: 20);
  return Duration(milliseconds: ms[level.clamp(0, ms.length - 1)]);
}

/// 生成 spawn 方块（顶部居中）
Piece spawnPiece(TetrominoType type) =>
    Piece(type: type, rotation: 0, row: 0, col: type == TetrominoType.I ? 3 : 3);
