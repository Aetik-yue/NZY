import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import 'tetris_model.dart';
import 'tetris_painter.dart';
import 'tetris_status_overlay.dart';

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
    var row = _current!.row;
    while (isValidPosition(_board, _current!.copyWith(row: row + 1))) {
      row++;
    }
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

  /// Ghost origin 行（最大合法下落行）
  int _ghostRow() {
    if (_current == null) return 0;
    var row = _current!.row;
    while (isValidPosition(_board, _current!.copyWith(row: row + 1))) {
      row++;
    }
    return row;
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
    final full = <int>[];
    for (var r = 0; r < kTetrisRows; r++) {
      if (_board[r].every((c) => c != null)) full.add(r);
    }
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

  void _onPanUpdate(DragUpdateDetails d, double cellW, double cellH) {
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
    while (_dragDy >= cellH) {
      _softDrop();
      _dragDy -= cellH;
    }
    if (_dragDy < 0) _dragDy = 0; // 上拖忽略
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _ticker.stop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.bgPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('俄罗斯方块', style: AppTextStyles.titleMedium),
          centerTitle: true,
          actions: [
            IconButton(
              icon: Icon(
                _status == TetrisStatus.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: AppColors.textPrimary,
              ),
              onPressed: () => _status == TetrisStatus.playing ? _pause() : _start(),
            ),
          ],
        ),
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, c) {
              final fieldW = c.maxWidth * 0.62;
              final cellW = fieldW / kTetrisCols;
              final fieldH = cellW * kTetrisRows;
              return Column(
                children: [
                  // HUD
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _hud('分数', '$_score'),
                        _hud('级别', '$_level'),
                        _hud('行数', '$_lines'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 左：Hold + 按钮
                        SizedBox(
                          width: c.maxWidth * 0.19,
                          child: Column(
                            children: [
                              _panel('HOLD', _hold),
                              const SizedBox(height: 12),
                              _actionBtn('HOLD', AppColors.bgBlush, _holdSwap),
                            ],
                          ),
                        ),
                        // 中：游戏场
                        SizedBox(
                          width: fieldW,
                          height: fieldH,
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onPanUpdate: (d) => _onPanUpdate(d, cellW, cellW),
                            onTap: () => _rotate(1),
                            child: Stack(
                              children: [
                                CustomPaint(
                                  size: Size(fieldW, fieldH),
                                  painter: TetrisPainter(
                                    board: _board,
                                    current: _current,
                                    ghostRow: _ghostRow(),
                                    clearingRows: _clearingRows,
                                    clearProgress: _clearProgress,
                                  ),
                                ),
                                if (_status != TetrisStatus.playing)
                                  TetrisStatusOverlay(
                                    status: _status,
                                    score: _score,
                                    level: _level,
                                    lines: _lines,
                                    onStart: _start,
                                    onRestart: () {
                                      _reset();
                                      setState(() {});
                                    },
                                  ),
                              ],
                            ),
                          ),
                        ),
                        // 右：Next 队列 + Hard Drop
                        SizedBox(
                          width: c.maxWidth * 0.19,
                          child: Column(
                            children: [
                              _nextPanel(),
                              const SizedBox(height: 12),
                              _actionBtn('DROP', AppColors.accentRose, _hardDrop),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _hud(String label, String value) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: AppTextStyles.label),
          Text(value, style: AppTextStyles.titleSmall),
        ],
      );

  Widget _panel(String title, TetrominoType? type) => Column(
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

  Widget _nextPanel() {
    final next3 = _nextQueue.take(3).toList();
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

  Widget _actionBtn(String label, Color bg, VoidCallback onTap) => SizedBox(
        width: double.infinity,
        child: FilledButton(
          onPressed: onTap,
          style: FilledButton.styleFrom(
            backgroundColor: bg,
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppColors.radiusSm)),
          ),
          child: Text(label, style: AppTextStyles.titleXs.copyWith(color: AppColors.textPrimary)),
        ),
      );
}
