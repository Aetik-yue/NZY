# 音乐播放器（本地音乐扫描 + 真实播放）· 设计文档

> 日期：2026-08-02
> 状态：已批准，待实施
> 范围：扫描设备本地音乐文件 + just_audio 真实播放，参考网易云音乐布局与交互，配色跟随应用暖奶油粉主题。

---

## 一、背景与目标

项目当前音乐功能为占位：
- 「我的」页 `_MusicCard` 硬编码假文案「32 首 · 正在播放"小幸运"」，onTap ->「即将上线 🎵」
- 首页音乐快捷入口 onTap ->「即将上线 🎵」
- `lib/features/music/` 为空目录
- pubspec 无任何音频播放依赖

本次迭代交付一个**标准网易云风格本地音乐播放器**：自动扫描设备音乐库生成真实歌单、真实播放音频、迷你播放条 + 全屏播放页 + 歌曲列表弹层。**不使用任何假数据。**

## 二、范围与取舍

**本次做：**
- 扫描设备本地音乐库（`on_audio_query`）生成真实歌单（标题/艺术家/时长/封面/URI 均来自系统媒体库）
- `just_audio` 真实播放/暂停/上下首/seek/进度/播完自动下一首
- 迷你播放条（全局常驻）+ 全屏播放页（旋转大封面/进度条/控制）+ 歌曲列表弹层
- 打通入口：profile 音乐卡 + 首页音乐入口 -> 打开播放页，文案读真实扫描结果
- Android 运行时权限请求（READ_MEDIA_AUDIO / READ_EXTERNAL_STORAGE）

**本次不做（YAGNI）：**
- ❌ Isar 歌单持久化 / 双人歌单 / 云端歌单（扫描结果每次进入时刷新即可）
- ❌ 歌词页、播放模式切换（顺序/随机/单曲）、喜欢/收藏、倍速、定时关闭
- ❌ iOS 音乐库访问（iOS 沙盒限制多，本项目面向 Android，后续再做）
- ❌ 旋转唱片之外的复杂动效

## 三、新增依赖

```yaml
# pubspec.yaml
just_audio: ^0.9.43        # 真实音频播放（支持本地 file/content URI）
on_audio_query: ^2.9.0     # 查询设备音乐库（标题/艺术家/时长/封面/URI，自带权限请求）
```

`on_audio_query` 自带 Android 权限请求能力（`OnAudioQuery.permissionsRequest`），无需额外引入 `permission_handler`。

## 四、架构与文件结构

```
lib/features/music/
├── models/
│   └── music_song.dart                # MusicSong 内存模型（从 SongModel 映射）
├── providers/
│   ├── music_library_provider.dart    # FutureProvider：权限请求 + 扫描设备音乐库
│   └── music_player_provider.dart     # MusicPlayerController（接 just_audio）
└── presentation/
    ├── music_player_page.dart         # 全屏播放页
    └── widgets/
        ├── mini_player_bar.dart       # 底部迷你播放条（全局常驻）
        └── playlist_sheet.dart        # 歌曲列表弹层
```

Provider 放 `features/music/providers/`：音乐播放器是 UI 态（含播放器副作用），与 `currentTabProvider`（位于 `pill_nav_bar.dart`）同惯例，不塞进 `data/providers/data_providers.dart`。

## 五、状态模型与数据流

### MusicSong（内存模型，从 on_audio_query 的 SongModel 映射）
```dart
class MusicSong {
  final int id;              // on_audio_query 歌曲 id
  final String title;        // 标题（来自媒体库元数据）
  final String artist;       // 艺术家（缺失时为"未知艺术家"）
  final Duration duration;   // 时长
  final String? uri;         // 播放 URI（file:// 或 content://）
  final int coverIndex;      // 无封面时用的渐变索引（复用 AppColors.photoGradients）
  final Uint8List? coverBytes; // 封面图字节（来自 queryArtworks，可能为 null）
}
```

### MusicLibraryProvider（FutureProvider<List<MusicSong>>）
- 请求 Android 音频权限 -> 授权后 `OnAudioQuery.querySongs()` 拉取全部音频
- 映射为 `List<MusicSong>`，并对每首 `queryArtworks()` 取封面（失败的用渐变占位）
- 权限拒绝 -> 抛 `MusicPermissionDeniedException`（UI 层捕获显示引导）
- 扫描为空 -> 返回空列表（UI 层显示空态）

### MusicPlayerController（Notifier<MusicPlayerState>）
```dart
class MusicPlayerState {
  final List<MusicSong> playlist;  // 来自 MusicLibraryProvider 扫描结果
  final int currentIndex;          // 当前曲目（-1 表示未选）
  final bool isPlaying;
  final Duration position;
  final Duration duration;         // 当前曲总时长
  final bool isLoading;            // 切歌加载中（setUrl 期间）
}
```
内部持有 `just_audio.AudioPlayer`：
- `togglePlay()` -> `player.play()` / `player.pause()`
- `next()` / `previous()` / `selectSong(i)` -> `player.setUrl(song.uri!)` + `play()`
- `seekTo(d)` -> `player.seek(d)`
- 监听 `player.positionStream` 更新 position、`playerStateStream` 处理 completed（自动下一首，末首停止或循环）、`durationStream` 更新 duration
- `setPlaylist(List<MusicSong>)` -> 注入扫描结果

### 数据流
```
MusicLibraryProvider (FutureProvider, 扫描设备)
        ↓ playlist 注入
MusicPlayerController (Notifier, 接 just_audio)
   ↑ 动作调用                    ↓ ref.watch
UI 组件（MiniPlayerBar / MusicPlayerPage / PlaylistSheet）
```

## 六、UI 组件

### 6.1 迷你播放条（MiniPlayerBar）- 全局常驻
- **位置**：`MainShell.bottomNavigationBar` 改为 `Column[MiniPlayerBar, PillNavBar]`
- **显示逻辑**：`currentIndex >= 0`（有选中曲目）时显示，否则不占位
- **内容**：32px 封面（有 coverBytes 用 Image.memory，否则渐变占位）｜ 歌名+艺术家（ellpsis）｜ 播放/暂停按钮
- **交互**：点击条 -> 从底部滑出全屏播放页；按钮独立响应

### 6.2 全屏播放页（MusicPlayerPage）
- **打开**：`showModalBottomSheet` 全屏 + `isScrollControlled`，支持下滑收起
- **布局**（从上到下）：歌名/艺术家 + 收起条 -> 大封面（约 70% 屏宽圆角，**播放时缓慢旋转**，暂停时停；有封面用真实图，无封面用渐变）-> 可拖 `Slider` 进度 + `mm:ss` 时间 -> `上一首｜播放/暂停｜下一首` -> 底部`歌曲列表`按钮
- **加载态**：切歌 `isLoading` 期间封面/按钮显示 Spinner
- **空态**：歌单为空时显示「没有找到本地音乐」+ 提示（如检查权限/将音乐放入设备）
- **权限态**：权限拒绝时显示「需要音乐权限」+「重新授权」按钮（调 `OnAudioQuery.permissionsRequest`）
- **背景**：暖奶油粉渐变（AppColors），不硬编码网易红

### 6.3 歌曲列表弹层（PlaylistSheet）
- 底部弹层：扫描到的全部歌曲列表（小封面 + 歌名 + 艺术家 + 时长）
- 当前曲目高亮 + 播放中音符动画
- 点击 -> `selectSong(i)` 切歌，弹层保留

## 七、权限与错误处理

| 场景 | 处理 |
|---|---|
| 首次进入音乐页 | `OnAudioQuery.permissionsRequest` 请求 READ_MEDIA_AUDIO（Android 13+）/ READ_EXTERNAL_STORAGE（13 以下） |
| 权限拒绝 | `MusicLibraryProvider` 抛异常，全屏页显示「需要音乐权限」+「重新授权」按钮 |
| 扫描结果为空 | 返回空列表，全屏页显示空态「没有找到本地音乐」 |
| 单首 URI 失效/文件损坏 | `player.setUrl` 抛异常 -> `AppSnackbar.show('该曲目无法播放')` -> 自动跳下一首 |
| 歌单中无 URI 的条目 | 扫描时过滤掉（`uri == null` 的不入歌单） |

## 八、入口串联（消除全部假数据）

- profile `_MusicCard`：文案读 `MusicLibraryProvider` + `MusicPlayerController` -> `「${playlist.length} 首 · 正在播放「${current.title}」」`（无当前曲时只显示首数）；onTap -> 打开播放页
- home 音乐快捷入口 onTap -> 打开播放页
- 封面渐变复用 `AppColors.photoGradients`，不新增色值

## 九、Android 配置

- `android/app/src/main/AndroidManifest.xml` 添加：
  - `<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />`（Android 13+）
  - `<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />`（Android 12 及以下）
- `just_audio` 无需额外 manifest 配置（播放本地文件不涉及 INTERNET 权限，但保留以防后续接网络流）

## 十、测试

1. `test/music_player_controller_test.dart`：
   - mock `just_audio.AudioPlayer`（用 fake 实现 positionStream/playerStateStream）
   - 测 play/pause 状态切换、next/previous 首尾边界、selectSong 切换+setUrl、seekTo、播完 completed 自动下一首
2. `test/widget_test.dart`：
   - 迷你条渲染 + 打开播放页冒烟
   - 为 `musicLibraryProvider` / `musicPlayerProvider` 补 override（mock 空歌单 + 假 SongModel 列表），保持隔离（遵循 CLAUDE.md 9.2）

## 十一、验证

- `flutter analyze` 零告警
- `flutter test` 全部通过
- `flutter build apk --debug` 成功
- 真机实测：扫描到本地音乐 -> 迷你条显示 -> 打开播放页 -> 播放有声音 -> 进度走动 -> 切歌/seek/播完自动下一首均正常
