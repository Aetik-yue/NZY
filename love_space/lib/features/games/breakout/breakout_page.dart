import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
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
  // 用 Ticker 而非 AnimationController.repeat()：基于真实时间 dt 位移，
  // 高刷屏（120Hz）下球速不会翻倍。createTicker 由 mixin 绑定 vsync 与 TickerMode。
  late final Ticker _ticker;
  // 上一次回调的 elapsed，用于计算帧间 dt；start() 时归零
  Duration _lastTick = Duration.zero;
  // 场地高宽比（h/w），由 LayoutBuilder 写入，供 collideBrick 缩放 y 距离
  double _aspectRatio = 1.0;

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
    _ticker = createTicker(_onTick);
    _loadLevel(0);
    // 锁竖屏：打砖块布局按竖屏设计
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  }

  @override
  void dispose() {
    _ticker.dispose();
    // 恢复所有朝向
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  void _loadLevel(int idx) {
    _levelIndex = idx;
    final level = kBreakoutLevels[idx];
    _bricks = buildBricks(level);
    _paddle = Paddle(x: 0.4, y: 0.92, width: 0.2);
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
    if (_status == BreakoutStatus.ready || _status == BreakoutStatus.paused) {
      setState(() => _status = BreakoutStatus.playing);
      // 归零 dt 基准，避免暂停期间累积的时间在恢复瞬间造成大跳
      _lastTick = Duration.zero;
      _ticker.start();
    }
  }

  void _pause() {
    if (_status == BreakoutStatus.playing) {
      _ticker.stop();
      setState(() => _status = BreakoutStatus.paused);
    }
  }

  void _onTick(Duration elapsed) {
    // 系统返回键退出时 Ticker 可能在 dispose 前再触发一帧，避免对已卸载 State 调 setState
    if (!mounted) return;
    // 帧率无关：dt 归一化到 60fps（1.0 = 一帧@60Hz）。
    // 120Hz 屏 dt≈0.5，位移减半，球速与 60Hz 一致；30Hz 卡顿 dt≈2.0。
    final dt = (elapsed - _lastTick).inMicroseconds / 16666.0;
    _lastTick = elapsed;
    // dt<=0：首帧（elapsed=0）或时间未前进，跳过；
    // dt>4：单帧跨度过大（>~66ms，如后台恢复/GC），丢弃防穿透
    if (dt <= 0 || dt > 4) return;

    final level = kBreakoutLevels[_levelIndex];
    final ball = _ball;
    // 与 Painter 绘制完全一致：brickW=1/cols、brickH=kBrickHeight、top=kBrickTop
    final brickW = 1.0 / _cols;
    const brickH = kBrickHeight;

    // 位移乘 dt：vx/vy 是“逻辑/帧@60fps”的速度定义，仅位移需按真实时间缩放
    ball.x += ball.vx * dt;
    ball.y += ball.vy * dt;

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

    // 挡板碰撞：圆-矩形最近点检测（支持挡板垂直移动，见 _paddleHit）
    final paddleHit = _paddleHit(ball);
    if (paddleHit != null) {
      ball.y = _paddle.y - ball.r;
      final hitPos = (ball.x - _paddle.x) / _paddle.width - 0.5;
      final speed = level.ballSpeed;
      // 速度定义不变（不乘 dt），仅作为方向/大小基准
      ball.vx = hitPos * speed * 1.6;
      ball.vy = -speed;
      // 侧面命中（bounceX 主导）：水平取反；正面命中：vy 保持击球公式（向上）
      if (paddleHit.bounceX) ball.vx = -ball.vx;
    }

    // 砖块碰撞：传 aspectRatio 使碰撞圆与视觉正圆（半径 r*w 像素）一致
    final hit = collideBrick(
      ball,
      _bricks,
      brickW,
      brickH,
      kBrickTop,
      aspectRatio: _aspectRatio,
    );
    if (hit != null) {
      hit.brick.alive = false;
      _score += hit.brick.kind.score;
      if (hit.bounceY) ball.vy = -ball.vy;
      if (hit.bounceX) ball.vx = -ball.vx;
      // 只有清除全部砖块才通关；单次击中只计分并继续游戏。
      if (levelCleared(_bricks)) {
        _ticker.stop();
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

  /// 挡板碰撞：圆-矩形最近点检测（同 collideBrick 的写法）
  ///
  /// 仅在下落（vy>0）时判定，避免挡板移入上升球路时被反复触发；
  /// 返回 `(bounceX, bounceY)` 记录，null 表示未命中。
  ({bool bounceX, bool bounceY})? _paddleHit(Ball ball) {
    if (ball.vy <= 0) return null;
    return collidePaddle(ball, _paddle, aspectRatio: _aspectRatio);
  }

  void _loseLife() {
    _ticker.stop();
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
      _paddle = Paddle(x: 0.4, y: 0.92, width: 0.2);
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

  void _onPanUpdate(DragUpdateDetails d, double width, double height) {
    setState(() {
      _paddle.x =
          (_paddle.x + d.delta.dx / width).clamp(0.0, 1.0 - _paddle.width);
      // 逻辑 y 与像素同比例（height 为场地像素高），clamp 保证挡板不越界
      _paddle.y =
          (_paddle.y + d.delta.dy / height).clamp(0.05, 1.0 - kPaddleHeight);
    });
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: true,
      // 退出转场期间停动画循环（系统返回键与 AppBar 返回键均经此回调）
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _ticker.stop();
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
                    // 场地高宽比（h/w），供 collideBrick 缩放 y 距离，使碰撞圆与
                    // 视觉正圆一致。在 build 中写入字段供 _onTick 读取
                    // （constraints 在此闭包内有效，_onTick 在帧回调时读最新值）。
                    _aspectRatio = constraints.maxHeight / constraints.maxWidth;
                    return GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onPanUpdate: (d) => _onPanUpdate(
                          d, constraints.maxWidth, constraints.maxHeight),
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
                            size: Size(
                                constraints.maxWidth, constraints.maxHeight),
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
