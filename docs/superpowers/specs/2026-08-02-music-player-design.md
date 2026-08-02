# 音乐播放器（UI 先行）· 设计文档

> 日期：2026-08-02
> 状态：已批准，待实施
> 范围：**纯界面先行**（无真实播放引擎，交互态用 Timer 模拟），参考网易云音乐布局与交互，配色跟随应用暖奶油粉主题。

---

## 一、背景与目标

项目当前音乐功能为占位：
- 「我的」页 `_MusicCard` 硬编码假文案「32 首 · 正在播放"小幸运"」，onTap →「即将上线 🎵」
- 首页音乐快捷入口 onTap →「即将上线 🎵」
- `lib/features/music/` 为空目录
- pubspec 无任何音频播放依赖

本次迭代交付一个**标准网易云风格播放器界面**（纯 UI），真实可玩（旋转/进度/切歌等交互态均可用），为下一步接真实播放引擎（just_audio）留好接口。

## 二、范围与取舍

**本次做：**
- 迷你播放条（全局常驻）+ 全屏播放页 + 歌曲列表弹层
- Mock 歌单（~8 首，内存常量），封面用渐变占位（复用 `AppColors.photoGradients`）
- `MusicPlayerController`（Riverpod Notifier）用 `Timer` 模拟进度推进
- 打通入口：profile 音乐卡 + 首页音乐入口 → 打开播放页，并真实化音乐卡文案

**本次不做（YAGNI）：**
- ❌ 真实音频播放（下个迭代接 just_audio）
- ❌ Isar 歌单持久化 / 双人歌单数据层
- ❌ 歌词页、播放模式切换、喜欢/收藏、倍速、定时关闭
- ❌ 旋转唱片之外的复杂动效

## 三、架构与文件结构

```
lib/features/music/
├── models/
│   └── music_song.dart               # MusicSong 内存模型（不落库）
├── providers/
│   └── music_player_provider.dart    # mock 歌单 + MusicPlayerController
└── presentation/
    ├── music_player_page.dart        # 全屏播放页
    └── widgets/
        ├── mini_player_bar.dart      # 底部迷你播放条（全局常驻）
        └── playlist_sheet.dart       # 歌曲列表弹层
```

Provider 放 `features/music/providers/` 而非 `data/providers/data_providers.dart`：音乐播放器是** UI 态**（含 Timer 副作用），与 `currentTabProvider`（位于 `pill_nav_bar.dart`）同惯例，不属于数据层。

## 四、状态模型

### MusicSong（内存模型）
```dart
class MusicSong {
  final String title;      // 歌名
  final String artist;     // 歌手
  final int coverIndex;    // 封面渐变索引（AppColors.photoGradients）
  final Duration duration; // 时长（mock 3-4 分钟）
}
```

### MusicPlayerState / Controller
```dart
class MusicPlayerState {
  final List<MusicSong> playlist; // 歌单（mock 常量 ~8 首）
  final int currentIndex;         // 当前曲目
  final bool isPlaying;           // 播放/暂停
  final Duration position;        // 当前进度（Timer 模拟）
}

class MusicPlayerController extends Notifier<MusicPlayerState> {
  // 动作：togglePlay / next / previous / selectSong(i) / seekTo(d)
  // 内部 Timer.periodic(500ms) 推进 position；暂停冻结；播完自动切下一首（末首回第一首）
  // 接口为接 just_audio 预留：UI 只调动作，接真实引擎只改 Controller 内部
}
```

## 五、UI 组件

### 5.1 迷你播放条（MiniPlayerBar）— 全局常驻
- **位置**：`MainShell.bottomNavigationBar` 改为 `Column[MiniPlayerBar, PillNavBar]`，所有 Tab 底部常驻
- **内容**：32px 渐变小封面 ｜ 歌名+歌手（单行 ellipsis）｜ 播放/暂停圆形按钮
- **交互**：点击条 → 从底部滑出全屏播放页；按钮独立响应

### 5.2 全屏播放页（MusicPlayerPage）
- **打开**：`showModalBottomSheet` 全屏 + `isScrollControlled`（与项目现有表单模式一致），支持下滑收起
- **布局**（从上到下）：歌名/歌手 + 收起条 → 大封面（约 70% 屏宽圆角渐变，**播放时缓慢旋转**，暂停时停）→ 可拖 `Slider` 进度 + `mm:ss` 时间 → `上一首｜播放/暂停｜下一首` → 底部`歌曲列表`按钮
- **背景**：暖奶油粉渐变（AppColors），**不硬编码网易红**
- **细节**：切歌渐隐渐显过渡；旋转用 `AnimationController` 缓速

### 5.3 歌曲列表弹层（PlaylistSheet）
- 底部弹层：歌曲列表（渐变小封面 + 歌名 + 歌手），当前曲目高亮 + 播放中音符动画
- 点击 → `selectSong(i)` 切歌

## 六、入口串联（顺手修复假数据）

- profile `_MusicCard`：文案读 Controller → `「${playlist.length} 首 · 正在播放「${current.title}」」`，onTap → 打开播放页
- home 音乐快捷入口 onTap → 打开播放页
- 封面渐变复用 `AppColors.photoGradients`，不新增色值

## 七、数据流

```
MusicPlayerController (Notifier, Timer 模拟进度)
   ↑ 动作调用                    ↓ ref.watch
UI 组件（MiniPlayerBar / MusicPlayerPage / PlaylistSheet）
```

组件通过 `ref.watch(musicPlayerProvider)` 读状态、`ref.read(...notifier)` 调动作；不直接持有 Timer/进度逻辑。

## 八、错误处理

- 本迭代无网络/IO 错误面（纯内存状态）
- `Timer` 在 Controller 内部管理：暂停时 cancel，恢复时重建，避免泄漏
- 空歌单防护：playlist 为空时动作安全返回

## 九、测试

1. `test/music_player_controller_test.dart`：
   - play → position 随时间推进；pause → 冻结
   - next/previous 首尾边界（末首 next → 回第一首）
   - selectSong 切换后 position 归零
   - seekTo 设置进度、越界 clamp
   - 播完自动切下一首
2. `test/widget_test.dart`：
   - 迷你条渲染 + 打开播放页冒烟
   - 为 `musicPlayerProvider` 补充 override（保持隔离，遵循 CLAUDE.md 9.2）

## 十、验证

- `flutter analyze` 零告警
- `flutter test` 全部通过
- `flutter build apk --debug` 成功
