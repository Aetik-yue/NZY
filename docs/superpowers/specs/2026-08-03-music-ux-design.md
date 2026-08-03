# 音乐页面交互体验优化 · 设计文档

> 日期：2026-08-03
> 状态：已批准，待实施
> 方向：**交互体验优先**（用户确认方案 A：逐项独立小改，不重构布局）
> 前置：音乐功能已完成健壮性加固（竞态/异常/权限时机/令牌），本迭代聚焦 UI/UX

---

## 一、背景与目标

音乐播放器（全屏播放页 + 迷你条 + 歌单弹层）功能已完整、健壮性已加固。当前 UI/UX 仍有明显提升空间（对照网易云交互标准）：

- 打开播放页但从未选歌时，标题/封面**空白占位**
- 播放页只能点收起条关闭，**无下滑手势**（网易云标志性交互）
- 切歌时内容**直接跳变**，无过渡动画
- 进度条拖动中**频繁 seek**（卡顿），无预览
- 无**播放模式**（顺序/随机/单曲循环）
- 迷你条无播放中动效

本迭代以**逐项独立小改**（每项一个提交）交付 6 项交互优化，不重构播放页布局（避免回归刚加固的代码）。

## 二、范围与取舍

**本次做（6 项）：**
1. 未选歌时自动选中第一首
2. 下滑手势收起播放页（跟随位移 + 回弹）
3. 切歌过渡动画（歌名/封面渐隐渐显）
4. 播放模式切换（顺序/随机/单曲循环，含 controller 逻辑 + 测试）
5. 进度条拖动预览（拖动中不 seek，松手才跳转）
6. 迷你条播放中等化器动效

**本次不做（YAGNI / 后置）：**
- ❌ 歌词页（范围大，后置）
- ❌ 喜欢/收藏（无数据层，后置）
- ❌ 后台播放/音频焦点（功能级，非 UI）
- ❌ 歌单弹层搜索/排序（后置）
- ❌ 播放页布局重构（DraggableScrollableSheet 方案未选）

## 三、逐项设计

### 1. 未选歌时自动选中第一首
- **位置**：`MusicPlayerController.setPlaylist`（`lib/features/music/providers/music_player_provider.dart`）
- **行为**：注入歌单后若 `currentIndex == -1` 且歌单非空 → 自动设 `currentIndex = 0`（**只选中不播放**，与网易云一致：页面有内容、用户点播放键出声）
- **效果**：打开播放页 → 扫描 → 自动显示第一首的标题/封面/时长，迷你条同步出现；不再空白占位

### 2. 下滑手势收起播放页
- **位置**：`music_player_page.dart` 页面根部包 `GestureDetector`
- **行为**：
  - `onVerticalDragUpdate`：页面内容用 `Transform.translate` **跟随手指位移**（背景透明度同步淡化）
  - `onVerticalDragEnd`：位移 > 屏高 25% 或速度 > 800px/s → `Navigator.pop` 收起；否则**回弹**原位
- **保留**：顶部收起条点击关闭（现有）

### 3. 切歌过渡动画
- **位置**：歌名/歌手 + 大封面（`music_player_page.dart` / `MusicBigCover`）
- **实现**：`AnimatedSwitcher`（300ms FadeTransition，key = `song?.id`）包裹歌名/歌手/封面；切歌时旧内容淡出、新内容淡入
- **旋转连续性**：`RotationTransition` 保持在外层（持续旋转不中断），`AnimatedSwitcher` 在内层包封面内容

### 4. 播放模式切换（顺序/随机/单曲循环）
- **状态层**（`music_player_provider.dart`）：
  - 新增 `enum PlayMode { sequence, shuffle, repeatOne }` + `state.playMode` + `togglePlayMode()`
  - `next()` 按模式取曲：顺序 `(i+1) % len`｜随机：随机非当前曲｜单曲：重播当前
  - 播完自动切歌 `_onTrackCompleted`：repeatOne → `seek(0)` + 重播当前；shuffle → 随机下一首；sequence → 正常 next
- **UI 层**：控制区布局改为 `[模式按钮｜上一首｜播放/暂停｜下一首｜列表按钮]` 一行：
  - 模式按钮图标随模式：`Icons.repeat`（顺序）/ `Icons.shuffle`（随机）/ `Icons.repeat_one`（单曲），激活态 `AppColors.accentRose` 高亮
  - 点击切换 + `AppSnackbar` 轻提示当前模式（如「随机播放」）
- **测试**：controller 单测补 playMode 三态切换、顺序/随机/单曲的 next 与播完自动切歌行为

### 5. 进度条拖动预览
- **位置**：`MusicProgressRow`（由 ConsumerWidget 改为 **ConsumerStatefulWidget**，持局部 `_dragValue`）
- **行为**：拖动中 `onChanged` 只更新本地预览值 + 时间标签显示预览时间（**不调 seek**）；`onChangeEnd` 才调一次 `seekTo`。消除拖动中频繁 seek 卡顿
- **效果**：拖动时时间标签实时跟随手指，松手才真正跳转

### 6. 迷你条播放中等化器动效
- **位置**：`mini_player_bar.dart` 歌名左侧新增 `_EqualizerBars`（约 16×16，3 条竖线）
- **行为**：`isPlaying` 时 3 条竖线用 `AnimationController` 循环跳动（伪随机高度）；暂停时静止（低透明度）
- **实现**：独立小 StatelessWidget + 内部 `AnimationController`（`TickerProviderStateMixin`），自管理生命周期

## 四、数据流与状态变更

```
MusicPlayerState 新增：playMode: PlayMode
MusicPlayerController 新增：togglePlayMode()；next() 按模式；_onTrackCompleted 按模式
UI：MusicControls 布局改造（模式按钮 + 列表按钮并入控制区行）
    MusicProgressRow → ConsumerStatefulWidget（拖动预览）
    MusicPlayerPage → GestureDetector 下滑 + AnimatedSwitcher
    MiniPlayerBar → _EqualizerBars
```

## 五、错误处理

- 播放模式切换为纯状态操作，无 IO 错误面
- 下滑收起：拖动中 pop 前检查 `context.mounted`
- 随机播放：歌单仅 1 首时随机 = 重播当前（不越界）
- 进度拖动：`onChangeEnd` 的 seekTo 复用 controller 既有异常兜底

## 六、测试

1. `test/music/music_player_controller_test.dart` 新增：
   - `setPlaylist` 后 currentIndex 自动置 0（未选过歌时）
   - `togglePlayMode` 三态循环
   - `next()` 在 sequence/shuffle/repeatOne 下的行为（随机用注入随机源或验证不越界 + 非当前）
   - `_onTrackCompleted` 在 repeatOne 下重播当前（position 归零 + 继续播放）
2. `test/widget_test.dart` / `permission_timing_test.dart` 冒烟保持通过（页面结构变化不破坏既有测试，必要时更新）

## 七、验证

- `flutter analyze` 零告警
- `flutter test` 全部通过（含新增 playMode 用例）
- `flutter build apk --debug` 成功
- 真机复核（可选）：下滑收起、模式切换、拖动预览手感

## 八、提交规划（每项一提交）

1. `feat(music): 未选歌时自动选中第一首`
2. `feat(music): 播放页下滑手势收起`
3. `feat(music): 切歌过渡动画（渐隐渐显）`
4. `feat(music): 播放模式切换（顺序/随机/单曲）+ 单测`
5. `feat(music): 进度条拖动预览（松手才 seek）`
6. `feat(music): 迷你条播放中等化器动效`
