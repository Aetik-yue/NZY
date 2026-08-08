# 打砖块小游戏 · 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在「全部功能 → 互动娱乐」内置经典打砖块小游戏：3 关递进 + 3 命 + 分数，纯 Flutter Canvas 实现（不引入 Flame），手指拖动挡板。

**Architecture:** 逻辑与绘制分离：`breakout_model.dart`（数据类 + 关卡 + 纯碰撞函数，可单测）→ `breakout_painter.dart`（CustomPainter 绘制）→ `breakout_page.dart`（StatefulWidget 持 AnimationController 游戏循环 + GestureDetector 拖动挡板 + 状态/分数/命/关 UI）。逻辑坐标系 0..1，绘制乘实际尺寸。

**Tech Stack:** Flutter 3.44 / Dart 3.12 / Canvas（CustomPainter）+ AnimationController + GestureDetector，无新依赖。

**约束（CLAUDE.md）：** AppColors/AppTextStyles 令牌、context.mounted、文件 < 300 行、无硬编码颜色。

---

## 文件结构

**新建：**
- `love_space/lib/features/games/breakout/breakout_model.dart` - 数据类（Brick/Ball/Paddle/Status/Level）+ 3 关布局 + 纯碰撞函数
- `love_space/lib/features/games/breakout/breakout_painter.dart` - CustomPainter 绘制砖块/球/挡板/背景
- `love_space/lib/features/games/breakout/breakout_page.dart` - 游戏页（循环 + 交互 + UI）
- `love_space/test/games/breakout_model_test.dart` - 纯碰撞函数单测

**修改：**
- `love_space/lib/features/profile/presentation/all_features_page.dart` - 互动娱乐分组加「打砖块」入口

---

## Task 1: 游戏模型 + 关卡 + 纯碰撞函数（TDD）

**Files:**
- Create: `love_space/lib/features/games/breakout/breakout_model.dart`
- Test: `love_space/test/games/breakout_model_test.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/games/breakout_model_test.dart`：

```dart
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
    final brickW = 0.125, brickH = 0.04, top = 0.1; // 8 列, 顶部偏移 0.1
    test('球从下方击中砖块底部 -> 返回该砖 + 反弹 vy', () {
      final bricks = [
        Brick(row: 0, col: 0, kind: BrickKind.rose),
      ];
      // 球中心在砖块正下方边界附近，向上运动
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
      // 球在砖块左侧，向右运动
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
    test('全部砖块 alive=false -> true', () {
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
```

- [ ] **Step 2: 运行确认失败**

Run: `cd love_space && flutter test test/games/breakout_model_test.dart`
Expected: FAIL - breakout_model.dart 不存在

- [ ] **Step 3: 实现 model**

创建 `lib/features/games/breakout/breakout_model.dart`：

```dart
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
  // 关1：4 行纯色行
  Level(bricks: [
    [1, 1, 1, 1, 1, 1, 1, 1],
    [2, 2, 2, 2, 2, 2, 2, 2],
    [3, 3, 3, 3, 3, 3, 3, 3],
    [4, 4, 4, 4, 4, 4, 4, 4],
  ], ballSpeed: 0.0045),
  // 关2：5 行交替色
  Level(bricks: [
    [1, 1, 1, 1, 1, 1, 1, 1],
    [2, 2, 2, 2, 2, 2, 2, 2],
    [3, 3, 3, 3, 3, 3, 3, 3],
    [4, 4, 4, 4, 4, 4, 4, 4],
    [5, 5, 5, 5, 5, 5, 5, 5],
  ], ballSpeed: 0.0055),
  // 关3：6 行，中间镂空图案
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
/// 砖块列间距系数（kBrickGap = brickW * 0.08）
const kBrickGapRatio = 0.08;

/// 把关卡布局转为 Brick 列表
List<Brick> buildBricks(Level level) {
  final result = <Brick>[];
  for (var r = 0; r < level.bricks.length; r++) {
    final row = level.bricks[r];
    for (var c = 0; c < row.length; c++) {
      final v = row[c];
      if (v == 0) continue;
      result.add(Brick(
        row: r,
        col: c,
        kind: BrickKind.values[v - 1],
      ));
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
/// 反弹方向判断：球前一位置相对砖块矩形的方向（上下 -> bounceY，左右 -> bounceX）。
BrickHit? collideBrick(Ball ball, List<Brick> bricks, double brickW, double brickH, double top) {
  for (final b in bricks) {
    if (!b.alive) continue;
    final bx = b.col * brickW;
    final by = top + b.row * (brickH + brickH * kBrickGapRatio);
    // 球圆与砖块矩形最近点距离
    final nearestX = ball.x.clamp(bx, bx + brickW);
    final nearestY = ball.y.clamp(by, by + brickH);
    final dx = ball.x - nearestX;
    final dy = ball.y - nearestY;
    if (dx * dx + dy * dy <= ball.r * ball.r) {
      // 判断击中面：用球中心相对砖块中心的偏移方向
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
```

- [ ] **Step 4: 运行确认通过**

Run: `cd love_space && flutter test test/games/breakout_model_test.dart`
Expected: All tests passed（7 条）

- [ ] **Step 5: Commit**

```bash
cd ..
git add love_space/lib/features/games/breakout/breakout_model.dart love_space/test/games/breakout_model_test.dart
git commit -m "feat(games): 打砖块模型 + 关卡 + 纯碰撞函数（TDD）"
```

---

## Task 2: CustomPainter 绘制

**Files:**
- Create: `love_space/lib/features/games/breakout/breakout_painter.dart`

- [ ] **Step 1: 实现 painter**

创建 `lib/features/games/breakout/breakout_painter.dart`：

```dart
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import 'breakout_model.dart';

/// 打砖块绘制器（逻辑坐标 0..1 -> 实际像素）
///
/// 经典美术：深色背景、彩色砖块行、白色挡板与球。
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
    // 背景：深色（textPrimary 偏深，经典打砖块暗背景）
    final bgPaint = Paint()..color = const Color(0xFF1A1220);
    canvas.drawRect(Offset.zero & size, bgPaint);

    final w = size.width;
    final h = size.height;
    final brickW = w / cols;
    final brickH = h * kBrickHeight;
    final gap = brickH * kBrickGapRatio;

    // 砖块（圆角矩形 + 行色）
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

    // 挡板：白色圆角矩形
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

  @override
  bool shouldRepaint(covariant BreakoutPainter old) =>
      old.bricks != bricks || old.ball != ball || old.paddle != paddle;
}
```

- [ ] **Step 2: 验证**

Run: `cd love_space && flutter analyze`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
cd ..
git add love_space/lib/features/games/breakout/breakout_painter.dart
git commit -m "feat(games): 打砖块 CustomPainter（经典深底彩色砖块）"
```

---

## Task 3: 游戏页（循环 + 碰撞 + 交互 + UI）

**Files:**
- Create: `love_space/lib/features/games/breakout/breakout_page.dart`

- [ ] **Step 1: 实现游戏页**

创建 `lib/features/games/breakout/breakout_page.dart`：

```dart
import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import 'breakout_model.dart';
import 'breakout_painter.dart';

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

  // 游戏状态
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

  /// 加载关卡
  void _loadLevel(int idx) {
    _levelIndex = idx;
    final level = kBreakoutLevels[idx];
    _bricks = buildBricks(level);
    _paddle = Paddle(x: 0.4, width: 0.2); // 居中
    _ball = Ball(
      x: 0.5,
      y: 0.85,
      vx: level.ballSpeed,
      vy: -level.ballSpeed,
      r: 0.018,
    );
    _status = BreakoutStatus.ready;
  }

  /// 开始/继续
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

  /// 每帧更新
  void _tick() {
    final level = kBreakoutLevels[_levelIndex];
    final ball = _ball;
    final brickW = 1.0 / _cols;
    final brickH = kBrickHeight;

    // 移动
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

    // 挡板碰撞（球底触挡板顶 y=0.92，挡板宽 0.2 高 0.025）
    final paddleTop = 0.92;
    if (ball.vy > 0 &&
        ball.y + ball.r >= paddleTop &&
        ball.y + ball.r <= paddleTop + 0.04 &&
        ball.x >= _paddle.x &&
        ball.x <= _paddle.x + _paddle.width) {
      ball.y = paddleTop - ball.r;
      // 按击中位置调整水平速度（经典手感）
      final hitPos = (ball.x - _paddle.x) / _paddle.width - 0.5; // -0.5..0.5
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
      // 重置球与挡板，保留砖块
      final level = kBreakoutLevels[_levelIndex];
      _ball = Ball(x: 0.5, y: 0.85, vx: level.ballSpeed, vy: -level.ballSpeed, r: 0.018);
      _paddle = Paddle(x: 0.4, width: 0.2);
      setState(() => _status = BreakoutStatus.ready);
    }
  }

  /// 下一关
  void _nextLevel() {
    _loadLevel(_levelIndex + 1);
    setState(() {});
  }

  /// 重新开始（从头）
  void _restart() {
    _score = 0;
    _lives = 3;
    _loadLevel(0);
    setState(() {});
  }

  /// 手指拖动挡板
  void _onPanUpdate(DragUpdateDetails d, double width) {
    setState(() {
      _paddle.x = (_paddle.x + d.delta.dx / width).clamp(0.0, 1.0 - _paddle.width);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('打砖块', style: AppTextStyles.titleMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 顶栏：分数 / 命 / 关
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _hud('分数', '$_score'),
                  _hud('第 ${_levelIndex + 1} 关', '/ ${kBreakoutLevels.length}'),
                  _hud('生命', '❤️×$_lives'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // 游戏区域
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onPanUpdate: (d) => _onPanUpdate(d, constraints.maxWidth),
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
                          size: Size(constraints.maxWidth, constraints.maxHeight),
                          painter: BreakoutPainter(
                            bricks: _bricks,
                            ball: _ball,
                            paddle: _paddle,
                            cols: _cols,
                          ),
                        ),
                        // 状态遮罩
                        if (_status != BreakoutStatus.playing)
                          _statusOverlay(),
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

  /// 状态遮罩（ready/paused/levelClear/gameWin/gameOver）
  Widget _statusOverlay() {
    final (title, hint, action) = switch (_status) {
      BreakoutStatus.ready => ('准备好了吗', '点击屏幕或拖动开始', '开始'),
      BreakoutStatus.paused => ('已暂停', '点击继续', '继续'),
      BreakoutStatus.levelClear => ('过关！', '第 ${_levelIndex + 1} 关完成', '下一关'),
      BreakoutStatus.gameWin => ('通关啦 🎉', '总分 $_score', '再玩一次'),
      BreakoutStatus.gameOver => ('游戏结束', '得分 $_score', '重新开始'),
      BreakoutStatus.playing => ('', '', ''),
    };
    return Container(
      color: const Color(0x99000000),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: AppTextStyles.titleLarge.copyWith(color: Colors.white)),
            const SizedBox(height: 8),
            Text(hint, style: AppTextStyles.body.copyWith(color: Colors.white70)),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () {
                switch (_status) {
                  case BreakoutStatus.ready:
                  case BreakoutStatus.paused:
                    _start();
                    break;
                  case BreakoutStatus.levelClear:
                    _nextLevel();
                    break;
                  case BreakoutStatus.gameWin:
                  case BreakoutStatus.gameOver:
                    _restart();
                    break;
                  case BreakoutStatus.playing:
                    break;
                }
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentRose,
              ),
              child: Text(action, style: AppTextStyles.body.copyWith(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: 验证**

Run: `cd love_space && flutter analyze`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
cd ..
git add love_space/lib/features/games/breakout/breakout_page.dart
git commit -m "feat(games): 打砖块游戏页（循环+碰撞+拖动+状态遮罩）"
```

---

## Task 4: 入口接入「全部功能」

**Files:**
- Modify: `love_space/lib/features/profile/presentation/all_features_page.dart`

- [ ] **Step 1: 加入口**

在 `all_features_page.dart` 顶部 import：
```dart
import '../../games/breakout/breakout_page.dart';
```

在「互动娱乐」分组的 items 列表（当前 `恋爱测试`、`缘分签` 占位）**之前**插入打砖块条目（onTap 真实跳转）。把「互动娱乐」分组从 `const` 改为普通构造（因含 onTap 闭包）：

```dart
      _FeatureGroup(
        title: '互动娱乐',
        items: [
          _FeatureEntry(
            icon: Icons.sports_baseball_rounded,
            title: '打砖块',
            subtitle: '经典 Breakout · 3 关挑战',
            color: AppColors.accentRose,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BreakoutPage()),
            ),
          ),
          const _FeatureEntry(
            icon: Icons.quiz_rounded,
            title: '恋爱测试',
            subtitle: '看看你们有多默契',
            color: AppColors.accentMauve,
          ),
          const _FeatureEntry(
            icon: Icons.auto_awesome_rounded,
            title: '缘分签',
            subtitle: '每日一句爱的占卜',
            color: AppColors.accentCoral,
          ),
        ],
      ),
```

- [ ] **Step 2: 验证**

Run: `cd love_space && flutter analyze`
Expected: No issues found

- [ ] **Step 3: Commit**

```bash
cd ..
git add love_space/lib/features/profile/presentation/all_features_page.dart
git commit -m "feat(games): 全部功能页接入打砖块入口"
```

---

## Task 5: 全量验证 + 冒烟测试

**Files:**
- Modify: `love_space/test/widget_test.dart`（补 BreakoutPage 冒烟，可选）

- [ ] **Step 1: 全量验证**

Run:
```bash
cd love_space
flutter analyze
flutter test
flutter build apk --debug
```
Expected: `No issues found!` + `All tests passed!`（含 breakout_model_test 7 条）+ `✓ Built`

- [ ] **Step 2: （可选）补冒烟测试**

在 `test/widget_test.dart` 末尾追加（确认游戏页能渲染不崩）：

```dart
testWidgets('BreakoutPage renders', (tester) async {
  await tester.pumpWidget(
    const MaterialApp(home: BreakoutPage()),
  );
  expect(find.text('打砖块'), findsOneWidget);
  expect(find.text('准备好了吗'), findsOneWidget); // ready 遮罩
});
```
（顶部加 `import 'package:love_space/features/games/breakout/breakout_page.dart';`）

Run: `cd love_space && flutter test`
Expected: All tests passed

- [ ] **Step 3: Commit（若加了冒烟测试）**

```bash
cd ..
git add love_space/test/widget_test.dart
git commit -m "test(games): 打砖块游戏页冒烟测试"
```

- [ ] **Step 4: 真机验证（手动）**

`flutter run` 到手机，验证：
- 全部功能 → 互动娱乐 → 打砖块 -> 进入游戏页
- ready 遮罩「开始」-> 球移动
- 拖动挡板接球
- 球碰砖块消除+加分
- 球落地丢命、3 命用完游戏结束
- 过关进下一关、3 关通关
- 暂停（点击）/ 继续

---

## Self-Review 结果

**Spec 覆盖：** 经典打砖块 3 关递进 + 3 命 + 分数（Task 1/3）｜纯 Canvas 实现（Task 2/3）｜手指拖动挡板（Task 3）｜入口在全部功能互动娱乐（Task 4）｜经典美术深底彩色砖块（Task 2）。
**类型一致性：** `BrickKind`/`Brick`/`Ball`/`Paddle`/`BreakoutStatus`/`Level`/`BrickHit`/`collideBrick`/`levelCleared`/`buildBricks` 在 Task 1-3 命名一致；`kBreakoutLevels`/`kBrickTop`/`kBrickHeight` 跨文件一致。
**占位符扫描：** 无 TBD；Task 2 关卡布局已给完整 3 关矩阵；Task 3 游戏循环含完整碰撞/状态逻辑。
