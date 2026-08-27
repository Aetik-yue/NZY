# 专属录音自动识别 · 实施计划

> 日期：2026-08-28
>
> 依据：`docs/superpowers/specs/2026-08-28-exclusive-music-scan-design.md`

**目标：** Android 音乐页面只自动识别真实文件名以 `yyzm` 开头的本地音频，在界面隐藏前缀，并在录音新增、删除或改名后正确协调播放器状态。

**架构：** 使用 `MusicFilenamePolicy` 承担纯 Dart 文件名规则；使用可注入的 `MusicLibrarySource` 封装 `on_audio_query`；`FutureProvider.autoDispose` 负责编排权限、MediaStore 候选查询、严格过滤、排序和封面读取；播放器通过异步 `reconcilePlaylist` 接收每次成功扫描的完整结果。

**技术栈：** Flutter、Dart、Riverpod、just_audio、on_audio_query、flutter_test。

---

## Task 1：用测试锁定文件名识别规则

**Files:**

- Create: `love_space/test/music/music_filename_policy_test.dart`
- Create: `love_space/lib/features/music/models/music_filename_policy.dart`

- [ ] 添加失败测试：大小写无关的开头匹配；中间或末尾出现 `yyzm` 不匹配。
- [ ] 添加失败测试：只移除最后一个扩展名，支持多点文件名与大小写扩展名。
- [ ] 添加失败测试：隐藏前缀及连续空格、半角/全角下划线、半角/全角短横线。
- [ ] 添加失败测试：仅有前缀或前缀加分隔符时显示“未命名录音”。
- [ ] 运行单测并确认因实现缺失而失败。
- [ ] 实现最小纯 Dart `MusicFilenamePolicy`，不引入平台依赖。
- [ ] 运行单测并确认通过。

验证命令：

```powershell
cd love_space
flutter test test/music/music_filename_policy_test.dart
```

## Task 2：建立可测试的 MediaStore 查询层

**Files:**

- Create: `love_space/lib/features/music/providers/music_library_source.dart`
- Modify: `love_space/lib/features/music/providers/music_library_provider.dart`
- Create: `love_space/test/music/music_library_provider_test.dart`

- [ ] 定义 `MusicLibrarySource`：权限请求、按显示文件名查询候选、按媒体 ID 查询封面。
- [ ] 生产实现使用 `OnAudioQuery.queryWithFilters('yyzm', WithFiltersType.AUDIOS, args: AudiosArgs.DISPLAY_NAME)`。
- [ ] 新增 `musicLibrarySourceProvider`，测试通过 Fake Source 覆盖。
- [ ] 将 `musicLibraryProvider` 改为 `FutureProvider.autoDispose<List<MusicSong>>`。
- [ ] 添加失败测试：先请求权限，再以 `yyzm` 查询显示文件名。
- [ ] 添加失败测试：只允许严格前缀匹配且具有 URI 的候选进入结果。
- [ ] 添加失败测试：标题来自真实文件名清理结果，未知歌手回退为“专属录音”。
- [ ] 添加失败测试：按 `dateAdded` 倒序、媒体 ID 倒序稳定排序。
- [ ] 添加失败测试：只为最终匹配项读取封面；单首封面失败不阻断扫描。
- [ ] 添加失败测试：权限拒绝、查询异常、成功空结果是不同结果。
- [ ] 实现两阶段筛选、分批封面读取、映射与专用扫描异常。
- [ ] 运行 Provider 测试并确认通过。

验证命令：

```powershell
cd love_space
flutter test test/music/music_library_provider_test.dart
```

## Task 3：播放器支持成功扫描后的歌单协调

**Files:**

- Modify: `love_space/lib/features/music/providers/audio_backend.dart`
- Modify: `love_space/lib/features/music/providers/just_audio_backend.dart`
- Modify: `love_space/lib/features/music/providers/music_player_provider.dart`
- Modify: `love_space/test/music/music_player_controller_test.dart`

- [ ] 在 `AudioBackend`、`FakeAudioBackend` 与 `JustAudioBackend` 增加异步 `stop()`。
- [ ] 为可控测试后端记录 `stop` 次数。
- [ ] 添加失败测试：当前媒体 ID 仍在新歌单时保留加载身份、进度和播放状态，不调用 `stop` 或 `setUrl`。
- [ ] 添加失败测试：当前已加载歌曲消失时调用一次 `stop`，清除旧播放状态，并选中剩余第一首但不自动播放。
- [ ] 添加失败测试：成功空歌单停止旧音源，设置 `currentIndex = -1`、清空进度/时长并隐藏迷你播放器。
- [ ] 添加失败测试：歌单协调期间的旧在途加载不能覆盖新状态。
- [ ] 将同步 `setPlaylist` 的扫描更新职责迁移为异步 `reconcilePlaylist`；保留兼容入口仅用于现有调用时也必须遵循一致状态规则，或统一更新调用点。
- [ ] 确保仅在当前已加载歌曲被移除时调用 `stop()`；从未加载的选择变化不做无意义停止。
- [ ] 运行播放器测试并修复所有回归。

验证命令：

```powershell
cd love_space
flutter test test/music/music_player_controller_test.dart
```

## Task 4：页面接入成功空列表与专属状态文案

**Files:**

- Modify: `love_space/lib/features/music/presentation/music_player_page.dart`
- Modify: `love_space/lib/features/music/presentation/widgets/music_player_states.dart`
- Modify: `love_space/lib/features/music/presentation/widgets/playlist_sheet.dart`
- Modify: `love_space/lib/features/music/presentation/widgets/music_player_widgets.dart`
- Modify: `love_space/test/music/music_player_page_test.dart`
- Modify: `love_space/test/music/permission_timing_test.dart`

- [ ] 页面监听器对所有成功结果（包括空列表）调用 `reconcilePlaylist`。
- [ ] 监听器正确处理异步错误，页面销毁后不更新已销毁状态。
- [ ] 保持失败扫描不调用协调入口，从而保留旧播放器状态。
- [ ] 空状态显示 `yyzm` 文件名示例和“重新识别”。
- [ ] 权限状态显示“需要音乐和音频权限”、专属录音说明和“允许访问”。
- [ ] 扫描异常显示“识别歌曲失败，请重试”和“重新识别”。
- [ ] 播放列表标题改为“我们的歌（N 首）”，空文案改为“还没有找到专属录音”。
- [ ] 播放器操作区的“播放列表”入口文案按产品语义改为“我们的歌”。
- [ ] 添加 Widget 测试覆盖空状态、权限状态、扫描错误、刷新按钮和播放列表标题。
- [ ] 扩展权限时机测试：关闭再打开音乐页会重新执行扫描；启动和“我的”页仍不扫描。
- [ ] 运行音乐页面和权限时机测试。

验证命令：

```powershell
cd love_space
flutter test test/music/music_player_page_test.dart test/music/permission_timing_test.dart
```

## Task 5：整体回归、构建与差异复核

**Files:** 上述全部文件。

- [ ] 格式化所有新增与修改的 Dart 文件。
- [ ] 运行 `git diff --check`，消除空白错误。
- [ ] 运行 `flutter analyze`。
- [ ] 运行完整 `flutter test`。
- [ ] 构建 Android Debug APK，确认插件 API 与 Android 工程集成正常。
- [ ] 检查 Git 差异，确认没有依赖升级、权限扩大、数据库或腾讯云改动。
- [ ] 检查日志，确认不输出完整文件路径或 URI。
- [ ] 提交实现，并报告 APK 输出位置和待真机验收项。

验证命令：

```powershell
cd love_space
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
cd ..
git diff --check
git status --short
```

## 完成标准

- [ ] 设备普通音乐不会进入 App 歌单。
- [ ] 只有真实文件名以 `yyzm` 开头的音频被显示，匹配不区分大小写。
- [ ] 所有显示位置隐藏 `yyzm` 前缀及紧随其后的分隔符。
- [ ] 每次打开音乐页与点击“重新识别”都会启动新扫描。
- [ ] 取消前缀或删除文件后，歌曲在下一次成功扫描中消失。
- [ ] 当前歌曲仍存在时不重载；消失时真正停止旧音源。
- [ ] 权限拒绝、扫描失败与成功空结果呈现不同状态。
- [ ] 自动化测试、静态分析和 Debug APK 构建全部通过。
