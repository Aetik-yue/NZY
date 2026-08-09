import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'tetris_model.dart';
import 'tetris_play_body.dart';

/// 俄罗斯方块游戏页
class TetrisPage extends StatefulWidget {
  const TetrisPage({super.key});
  @override
  State<TetrisPage> createState() => _TetrisPageState();
}

class _TetrisPageState extends State<TetrisPage>
    with TickerProviderStateMixin {
  late final Ticker _ticker;
  Duration _lastTick = Duration.zero;

  TetrisBoard _board = emptyBoard();
  Piece? _current;
  TetrominoType? _hold;
  bool _holdUsed = false;
  List<TetrominoType> _nextQueue = [];
  final Random _rng = Random();

  int _score = 0, _level = 0, _lines = 0;
  TetrisStatus _status = TetrisStatus.ready;

  // gravity / lock delay
  double _gravityAccumMs = 0, _lockAccumMs = 0;
  int _lockResets = 0;
  bool _onGround = false;

  // 消行动画
  bool _clearing = false;
  double _clearProgress = 0;
  Set<int> _clearingRows = {};

  // 拖动量化累计
  double _dragDx = 0, _dragDy = 0;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
    _reset();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    _ticker.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _reset() {
    _board = emptyBoard();
    _nextQueue = refillBag(_rng);
    _current = _spawnFromQueue();
    _hold = null;
    _holdUsed = false;
    _score = 0;
    _level = 0;
    _lines = 0;
    _gravityAccumMs = 0;
    _lockAccumMs = 0;
    _lockResets = 0;
    _onGround = false;
    _clearing = false;
    _status = TetrisStatus.ready;
  }

  Piece _spawnFromQueue() {
    if (_nextQueue.length <= 1) _nextQueue.addAll(refillBag(_rng));
    return spawnPiece(_nextQueue.removeAt(0));
  }

  void _start() {
    if (_status == TetrisStatus.ready || _status == TetrisStatus.paused) {
      setState(() => _status = TetrisStatus.playing);
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _pause() {
    if (_status == TetrisStatus.playing) {
      _ticker.stop();
      setState(() => _status = TetrisStatus.paused);
    }
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    final dt = (elapsed - _lastTick).inMicroseconds / 16666.0;
    _lastTick = elapsed;
    if (dt <= 0 || dt > 4) return;
    if (_status != TetrisStatus.playing) return;

    if (_clearing) {
      _clearProgress += dt / 18; // ~300ms（18 帧@60fps）
      if (_clearProgress >= 1) _finishClear();
      setState(() {});
      return;
    }

    final piece = _current!;
    // gravity（ms 累加）
    _gravityAccumMs += dt * 16.6667;
    final intervalMs = gravityInterval(_level).inMilliseconds;
    while (_gravityAccumMs >= intervalMs) {
      _gravityAccumMs -= intervalMs;
      final moved = piece.copyWith(row: piece.row + 1);
      if (isValidPosition(_board, moved)) {
        _current = moved;
        _onGround = false;
      } else {
        _onGround = true;
        break;
      }
    }
    // lock delay
    _onGround = !isValidPosition(_board, piece.copyWith(row: piece.row + 1));
    if (_onGround) {
      _lockAccumMs += dt * 16.6667;
      if (_lockAccumMs >= 500) {
        _lockPiece();
        return;
      }
    } else {
      _lockAccumMs = 0;
    }
    setState(() {});
  }

  /// 移动（成功且原贴地时重置 lock delay）
  void _move(int dc) {
    if (_status != TetrisStatus.playing || _clearing) return;
    final moved = _current!.copyWith(col: _current!.col + dc);
    if (isValidPosition(_board, moved)) {
      _current = moved;
      _resetLockIfGrounded();
      setState(() {});
    }
  }

  void _rotate(int dir) {
    if (_status != TetrisStatus.playing || _clearing) return;
    final r = rotate(_board, _current!, dir);
    if (r != null) {
      _current = r;
      _resetLockIfGrounded();
      setState(() {});
    }
  }

  void _resetLockIfGrounded() {
    if (_onGround && _lockResets < 15) {
      _lockAccumMs = 0;
      _lockResets++;
    }
  }

  /// 软降一格（+1 分）
  void _softDrop() {
    if (_status != TetrisStatus.playing || _clearing) return;
    final moved = _current!.copyWith(row: _current!.row + 1);
    if (isValidPosition(_board, moved)) {
      _current = moved;
      _score += 1;
      _lockAccumMs = 0;
      setState(() {});
    }
  }

  /// 硬降：落到底 + 锁定（+2/格）
  void _hardDrop() {
    if (_status != TetrisStatus.playing || _clearing) return;
    final row = ghostRow(_board, _current);
    _score += (row - _current!.row) * 2;
    _current = _current!.copyWith(row: row);
    _lockPiece();
  }

  /// Hold：每块限 1 次
  void _holdSwap() {
    if (_status != TetrisStatus.playing || _clearing || _holdUsed) return;
    final cur = _current!.type;
    if (_hold == null) {
      _hold = cur;
      _current = _spawnFromQueue();
    } else {
      _current = spawnPiece(_hold!);
      _hold = cur;
    }
    _holdUsed = true;
    _lockAccumMs = 0;
    _lockResets = 0;
    _onGround = false;
    setState(() {});
  }

  void _lockPiece() {
    final piece = _current!;
    for (final p in piece.absoluteCells()) {
      if (p.r >= 0 && p.r < kTetrisRows && p.c >= 0 && p.c < kTetrisCols) {
        _board[p.r][p.c] = piece.type;
      }
    }
    _lockAccumMs = 0;
    _lockResets = 0;
    // 检测满行 -> 动画 / 否则直接生成下一块
    final full = fullRows(_board);
    if (full.isNotEmpty) {
      _clearing = true;
      _clearProgress = 0;
      _clearingRows = full.toSet();
    } else {
      _spawnNext();
    }
    setState(() {});
  }

  void _finishClear() {
    final n = clearLines(_board);
    _clearing = false;
    _clearingRows = {};
    _clearProgress = 0;
    if (n > 0) {
      _score += kLineScores[n] * (_level + 1);
      _lines += n;
      _level = _lines ~/ 10;
    }
    _spawnNext();
  }

  void _spawnNext() {
    final next = _spawnFromQueue();
    if (isBlockOut(_board, next)) {
      _ticker.stop();
      _status = TetrisStatus.gameOver;
      return;
    }
    _current = next;
    _holdUsed = false;
    _lockAccumMs = 0;
    _lockResets = 0;
    _onGround = false;
    _gravityAccumMs = 0;
  }

  void _onPanUpdate(DragUpdateDetails d, double cellW) {
    if (_status != TetrisStatus.playing || _clearing) return;
    _dragDx += d.delta.dx;
    _dragDy += d.delta.dy;
    // 水平：每格宽度移动 1 列
    if (_dragDx.abs() >= cellW) {
      final cols = (_dragDx / cellW).truncate();
      _move(cols);
      _dragDx -= cols * cellW;
    }
    // 垂直下拖：软降
    while (_dragDy >= cellW) {
      _softDrop();
      _dragDy -= cellW;
    }
    if (_dragDy < 0) _dragDy = 0; // 上拖忽略
  }

  @override
  Widget build(BuildContext context) {
    return TetrisPlayBody(
      score: _score,
      level: _level,
      lines: _lines,
      hold: _hold,
      nextQueue: _nextQueue,
      board: _board,
      current: _current,
      clearingRows: _clearingRows,
      clearProgress: _clearProgress,
      status: _status,
      onPanUpdate: _onPanUpdate,
      onRotate: () => _rotate(1),
      onStart: _start,
      onPause: _pause,
      onRestart: () {
        _reset();
        setState(() {});
      },
      onHoldSwap: _holdSwap,
      onHardDrop: _hardDrop,
      onPop: () => _ticker.stop(),
    );
  }
}
