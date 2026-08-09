# 俄罗斯方块 · 设计文档

> 日期：2026-08-08
> 状态：待用户审阅
> 范围：在「全部功能 -> 互动娱乐」新增俄罗斯方块游戏，MVP 标配，纯 Flutter Canvas（无 Flame），warm pastel classic 配色

---

## 一、背景与目标

参考打砖块（features/games/breakout/）已验证的「纯 Canvas + Ticker + StatefulWidget」范式，新增俄罗斯方块游戏。入口在「全部功能 -> 互动娱乐」分组。纯离线、竖屏、单手操作、暖奶油粉主题适配。

## 二、范围与取舍（MVP 标配）

**做：**
- 7-bag 随机生成器（公平发牌）
- SRS 旋转系统 + wall kick（JLSTZ/I 两套 kick 表）
- Ghost piece 落点预览（半透明轮廓）
- Hold 暂存（每块限 1 次）
- Hard drop（硬降）/ Soft drop（软降）
- Lock delay 500ms（移动/旋转重置，上限 15 次防无限拖延）
- Next 队列预告（3 个）
- 消行（Single/Double/Triple/Tetris）+ 基础计分 + 级别速度曲线
- Game over（Block out / Lock out）
- 暂停/重开

**不做（YAGNI/后置）：**
- ❌ T-spin 检测、Back-to-Back、Combo、Perfect Clear（深度计分后置）
- ❌ 多人/在线/云同步
- ❌ 持久化最高分（MVP 内存，后置）
- ❌ 自定义按键映射/左撇子镜像（后置）
- ❌ 音效（后置）

## 三、数据模型

### TetrominoType 与配色
```dart
enum TetrominoType { I, O, T, S, Z, J, L }
// 配色（warm pastel classic）：
// I=accentTeal(新) / O=accentGold(新) / T=accentRose / S=accentSage(新)
// Z=accentCoral / J=accentMauve / L=accentPeach
```
（4 复用 + 3 新增令牌 accentGold #F5D78A / accentSage #A8C9A0 / accentTeal #8FD4D0）

### 旋转状态（SRS）
每方块 4 状态（0/R/2/L）。预计算每状态 cell offsets（相对中心）。O 不旋转。I 用独立中心表。

### Wall Kick 表
- JLSTZ：`0->R: [(0,0),(-1,0),(-1,1),(0,-2),(-1,-2)]` 等 8 组（调研给出完整表）
- I：独立 8 组（调研给出完整表）
- 旋转碰撞时按序尝试 offset，首个合法位置生效

### Board
- 10 列 × 40 行内部（上 20 行 buffer，下 20 行可见）
- 用 `List<List<TetrominoType?>>` 或 `Set<(int,int)>` 表示已锁定格

### GameState
```dart
class TetrisState {
  final List<List<TetrominoType?>> board;
  final Piece? current;        // 当前方块（type/rotation/row/col）
  final TetrominoType? hold;
  final bool holdUsed;         // 本块已用 Hold
  final List<TetrominoType> nextQueue; // 7-bag 队列
  final int score;
  final int level;
  final int lines;
  final TetrisStatus status;   // ready/playing/paused/gameOver
  final int lockResets;        // lock delay 重置计数
}
enum TetrisStatus { ready, playing, paused, gameOver }
```

## 四、纯逻辑函数（可 TDD）
- `List<TetrominoType> refillBag()`：7-bag 洗牌
- `bool isValidPosition(board, piece)`：碰撞检测（边界/已占格）
- `Piece? rotate(board, piece, dir, kickTable)`：SRS 旋转 + wall kick，返回新位置或 null
- `int clearLines(board)`：消除满行，返回消除数
- `TetrominoType? checkGameOver(board, piece)`：Block out / Lock out 检测
- `Duration gravityInterval(level)`：级别->下落间隔（L0=1s... 递增到 20G）

## 五、计分与级别
- Single=100 / Double=300 / Triple=500 / Tetris=800（×level）
- Soft drop +1/cell / Hard drop +2/cell
- 每 10 行升 1 级，gravity 速度按曲线递增（L0=1.0s/行，L9=0.11s，L19+=0.03s，29+=0.02s，趋近 20G）

## 六、UI

### TetrisPage（features/games/tetris/tetris_page.dart）
- ConsumerStatefulWidget + Ticker（dt 归一化 60fps，复用打砖块模式）+ WidgetsBindingObserver（回前台校准）
- 竖屏锁定（SystemChrome）
- 布局：
  - 顶部 HUD：分数 / 级别 / 行数
  - 左上：Hold 小面板（显示暂存方块）
  - 右上：Next 队列小面板（3 个）
  - 中部：游戏场（10×20 可见，CustomPainter 绘制）
  - 底部右：Hard Drop 大按钮（pinkButtonGradient）+ Hold 按钮（bgBlush）
  - 状态遮罩：ready/paused/gameOver（复用打砖块 overlay 模式）
- 控制（混合方案）：
  - 游戏场 GestureDetector：onPanUpdate 水平拖动移动方块（1:1 跟手，按格子宽度量化）、onTap 旋转、垂直下拖软降
  - Hard Drop 按钮：瞬时落底 + 锁定
  - Hold 按钮：暂存/交换

### TetrisPainter（tetris_painter.dart）
- gameBgDark 深底
- 已锁定格：warm pastel 渐变方块（2-stop gradient + 圆角 radiusXs + 内高光）
- 当前方块：同渐变
- Ghost：半透明（opacity 0.2）轮廓
- 消行动画：闪光 -> 缩小淡出 -> 上方下移（动画期间锁输入）

### TetrisStatusOverlay（tetris_status_overlay.dart）
- ready「准备好了吗 / 开始」
- paused「已暂停 / 继续」
- gameOver「游戏结束 / 得分 X / 重新开始」

## 七、入口
`all_features_page.dart` 互动娱乐分组追加 _FeatureEntry：icon=Icons.grid_view_rounded / view_in_ar_rounded，title='俄罗斯方块'，onTap push TetrisPage

## 八、新增设计令牌（app_colors.dart）
```dart
static const accentGold = Color(0xFFF5D78A);   // O
static const accentSage = Color(0xFFA8C9A0);   // S
static const accentTeal = Color(0xFF8FD4D0);   // I
```

## 九、测试
- `test/games/tetris_model_test.dart`（TDD）：
  - 7-bag 公平性（12 块内必见每种、无连续 3 同）
  - isValidPosition 碰撞（边界/已占格）
  - rotate + wall kick（靠墙旋转踢墙成功、无法旋转返回 null）
  - clearLines（满行消除、多行、无行）
  - checkGameOver（Block out / Lock out）
  - gravityInterval 级别曲线
- `widget_test.dart`：TetrisPage 冒烟渲染

## 十、验证
- `flutter analyze` 零告警
- `flutter test` 全部通过
- `flutter build apk --debug` 成功
- 真机：发牌/旋转/消行/Hold/Ghost/Hard drop/级别加速/game over
