import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import 'breakout_model.dart';
import 'breakout_painter.dart';
import 'breakout_status_overlay.dart';

/// 打砖块游戏页
class BreakoutPage extends StatefulWidget {
  const BreakoutPage({super.key});

  @override
  State<BreakoutPage> createState() => _BreakoutPageState();
}

class _BreakoutPageState extends State<BreakoutPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  final int _cols = 8;

  List<Brick> _bricks = [];
  late Ball _ball;
  late Paddle _paddle;
  int _levelIndex = 0;
  int _score = 0;
  int _lives = 3;
  BreakoutStatus _status = BreakoutStatus.ready;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..addListener(_tick);
    _loadLevel(0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _loadLevel(int idx) {
    _levelIndex = idx;
    final level = kBreakoutLevels[idx];
    _bricks = buildBricks(level);
    _paddle = Paddle(x: 0.4, width: 0.2);
    _ball = Ball(
      x: 0.5,
      y: 0.85,
      vx: level.ballSpeed,
      vy: -level.ballSpeed,
      r: 0.018,
    );
    _status = BreakoutStatus.ready;
  }

  void _start() {
    if (_status == BreakoutStatus.ready ||
        _status == BreakoutStatus.paused) {
      setState(() => _status = BreakoutStatus.playing);
      _ctrl.repeat();
    }
  }

  void _pause() {
    if (_status == BreakoutStatus.playing) {
      _ctrl.stop();
      setState(() => _status = BreakoutStatus.paused);
    }
  }

  void _tick() {
    // 系统返回键退出时控制器可能在 dispose 前再触发一帧，避免对已卸载 State 调 setState
    if (!mounted) return;

    final level = kBreakoutLevels[_levelIndex];
    final ball = _ball;
    // 与 Painter 绘制完全一致：brickW=1/cols、brickH=kBrickHeight、top=kBrickTop
    final brickW = 1.0 / _cols;
    const brickH = kBrickHeight;

    ball.x += ball.vx;
    ball.y += ball.vy;

    // 左右墙
    if (ball.x - ball.r < 0) {
      ball.x = ball.r;
      ball.vx = -ball.vx;
    } else if (ball.x + ball.r > 1) {
      ball.x = 1 - ball.r;
      ball.vx = -ball.vx;
    }
    // 顶墙
    if (ball.y - ball.r < 0) {
      ball.y = ball.r;
      ball.vy = -ball.vy;
    }
    // 底（丢命）
    if (ball.y - ball.r > 1) {
      _loseLife();
      return;
    }

    // 挡板碰撞（y=0.92 与 Painter 一致）
    const paddleTop = 0.92;
    if (ball.vy > 0 &&
        ball.y + ball.r >= paddleTop &&
        ball.y + ball.r <= paddleTop + 0.04 &&
        ball.x >= _paddle.x &&
        ball.x <= _paddle.x + _paddle.width) {
      ball.y = paddleTop - ball.r;
      final hitPos = (ball.x - _paddle.x) / _paddle.width - 0.5;
      final speed = level.ballSpeed;
      ball.vx = hitPos * speed * 1.6;
      ball.vy = -speed;
    }

    // 砖块碰撞
    final hit = collideBrick(ball, _bricks, brickW, brickH, kBrickTop);
    if (hit != null) {
      hit.brick.alive = false;
      _score += hit.brick.kind.score;
      if (hit.bounceY) ball.vy = -ball.vy;
      if (hit.bounceX) ball.vx = -ball.vx;
      if (levelCleared(_bricks)) {
        _ctrl.stop();
        if (_levelIndex + 1 >= kBreakoutLevels.length) {
          setState(() => _status = BreakoutStatus.gameWin);
        } else {
          setState(() => _status = BreakoutStatus.levelClear);
        }
        return;
      }
    }

    setState(() {});
  }

  void _loseLife() {
    _ctrl.stop();
    _lives--;
    if (_lives <= 0) {
      setState(() => _status = BreakoutStatus.gameOver);
    } else {
      final level = kBreakoutLevels[_levelIndex];
      _ball = Ball(
        x: 0.5,
        y: 0.85,
        vx: level.ballSpeed,
        vy: -level.ballSpeed,
        r: 0.018,
      );
      _paddle = Paddle(x: 0.4, width: 0.2);
      setState(() => _status = BreakoutStatus.ready);
    }
  }

  void _nextLevel() {
    _loadLevel(_levelIndex + 1);
    setState(() {});
  }

  void _restart() {
    _score = 0;
    _lives = 3;
    _loadLevel(0);
    setState(() {});
  }

  void _onPanUpdate(DragUpdateDetails d, double width) {
    setState(() {
      _paddle.x =
          (_paddle.x + d.delta.dx / width).clamp(0.0, 1.0 - _paddle.width);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      // 退出转场期间停动画循环（系统返回键与 AppBar 返回键均经此回调）
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _ctrl.stop();
      },
      child: Scaffold(
        backgroundColor: AppColors.bgPrimary,
        appBar: AppBar(
          backgroundColor: AppColors.bgPrimary,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios_new,
                size: 20, color: AppColors.textPrimary),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text('打砖块', style: AppTextStyles.titleMedium),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _hud('分数', '$_score'),
                    _hud('第 ${_levelIndex + 1} 关',
                        '/ ${kBreakoutLevels.length}'),
                    _hud('生命', '❤️×$_lives'),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (d) =>
                          _onPanUpdate(d, constraints.maxWidth),
                      onTap: () {
                        if (_status == BreakoutStatus.playing) {
                          _pause();
                        } else if (_status == BreakoutStatus.ready ||
                            _status == BreakoutStatus.paused) {
                          _start();
                        }
                      },
                      child: Stack(
                        children: [
                          CustomPaint(
                            size: Size(constraints.maxWidth,
                                constraints.maxHeight),
                            painter: BreakoutPainter(
                              bricks: _bricks,
                              ball: _ball,
                              paddle: _paddle,
                              cols: _cols,
                            ),
                          ),
                          if (_status != BreakoutStatus.playing)
                            BreakoutStatusOverlay(
                              status: _status,
                              levelIndex: _levelIndex,
                              score: _score,
                              onStart: _start,
                              onNextLevel: _nextLevel,
                              onRestart: _restart,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Widget _hud(String label, String value) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: AppTextStyles.label),
        Text(value, style: AppTextStyles.titleSmall),
      ],
    );
  }
}
