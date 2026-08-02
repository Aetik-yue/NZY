# 音乐播放器（本地音乐扫描 + 真实播放）实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 实现网易云风格本地音乐播放器：扫描设备音乐库生成真实歌单，just_audio 真实播放，迷你播放条 + 全屏播放页 + 歌曲列表弹层。

**Architecture:** `MusicLibraryProvider`（FutureProvider，用 `on_audio_query` 扫描设备）-> `MusicPlayerController`（Notifier，通过 `AudioBackend` 抽象接口接 `just_audio`，便于测试）-> UI 组件。引入 `AudioBackend` 接口 + `FakeAudioBackend` 使 Controller 完全可单测。

**Tech Stack:** Flutter 3.44 / Dart 3.12 / Riverpod / just_audio ^0.9.43 / on_audio_query ^2.9.0

**Spec:** `docs/superpowers/specs/2026-08-02-music-player-design.md`

**关键约束（CLAUDE.md）：** 颜色用 AppColors / 文字用 AppTextStyles；AppSnackbar 反馈；异步后 context.mounted；相对 import；ConsumerWidget；文件 < 300 行。

---

## 文件结构

**新建：**
- `love_space/lib/features/music/models/music_song.dart` — MusicSong 内存模型
- `love_space/lib/features/music/providers/audio_backend.dart` — AudioBackend 抽象接口 + FakeAudioBackend
- `love_space/lib/features/music/providers/just_audio_backend.dart` — just_audio 实现
- `love_space/lib/features/music/providers/music_player_provider.dart` — MusicPlayerController + State
- `love_space/lib/features/music/providers/music_library_provider.dart` — 扫描设备音乐库
- `love_space/lib/features/music/presentation/music_player_page.dart` — 全屏播放页
- `love_space/lib/features/music/presentation/widgets/mini_player_bar.dart` — 迷你播放条
- `love_space/lib/features/music/presentation/widgets/playlist_sheet.dart` — 歌曲列表弹层
- `love_space/test/music/music_player_controller_test.dart` — Controller 单测

**修改：**
- `love_space/pubspec.yaml` — 加 just_audio / on_audio_query
- `love_space/android/app/src/main/AndroidManifest.xml` — 加音频权限
- `love_space/lib/app/theme/app_colors.dart` — 加 coverGradients 封面渐变令牌
- `love_space/lib/shared/layouts/main_shell.dart` — 底部常驻迷你条
- `love_space/lib/features/profile/presentation/profile_page.dart` — 音乐卡真实化
- `love_space/lib/features/home/presentation/home_page.dart` — 音乐入口接通
- `love_space/test/widget_test.dart` — 补 music provider override

---

## Task 1: 添加依赖与 Android 权限

**Files:**
- Modify: `love_space/pubspec.yaml`
- Modify: `love_space/android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: 添加依赖**

在 `pubspec.yaml` 的 `dependencies:` 下（`image_picker` 之后）添加：

```yaml
  # 音乐播放
  just_audio: ^0.9.43
  on_audio_query: ^2.9.0
```

- [ ] **Step 2: 添加 Android 权限**

在 `android/app/src/main/AndroidManifest.xml` 的 `<manifest>` 标签内、`<application>` 之前添加：

```xml
    <!-- 音乐：扫描设备音频库（Android 13+） -->
    <uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
    <!-- 音乐：扫描设备音频库（Android 12 及以下） -->
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE"
        android:maxSdkVersion="32" />
```

- [ ] **Step 3: 安装依赖并验证编译**

Run:
```bash
cd love_space
flutter pub get
flutter analyze
```
Expected: `No issues found!`（新依赖未使用，不产生告警）

- [ ] **Step 4: Commit**

```bash
cd ..
git add love_space/pubspec.yaml love_space/pubspec.yaml.lock love_space/android/app/src/main/AndroidManifest.xml
git commit -m "feat(music): 添加 just_audio/on_audio_query 依赖与音频权限"
```

---

## Task 2: 封面渐变令牌

**Files:**
- Modify: `love_space/lib/app/theme/app_colors.dart`

- [ ] **Step 1: 新增 coverGradients**

在 `app_colors.dart` 的 `// ──────── 渐变 ────────` 区块末尾（`headerGradient` 定义之后）添加：

```dart
  /// 音乐封面渐变组（无封面图时按 id 取模占位）
  static const coverGradients = <LinearGradient>[
    LinearGradient(colors: [Color(0xFFFFBFD0), Color(0xFFFF8FB1)]),
    LinearGradient(colors: [Color(0xFFFFD1BF), Color(0xFFFFB5A1)]),
    LinearGradient(colors: [Color(0xFFFFB5CC), Color(0xFFFFD4E0)]),
    LinearGradient(colors: [Color(0xFFFFBFCC), Color(0xFFFFA1B5)]),
    LinearGradient(colors: [Color(0xFFFFE0D4), Color(0xFFFFB5CC)]),
    LinearGradient(colors: [Color(0xFFFF8FB1), Color(0xFFFF6B9D)]),
  ];
```

- [ ] **Step 2: 验证**

Run: `cd love_space && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd ..
git add love_space/lib/app/theme/app_colors.dart
git commit -m "feat(music): 新增 AppColors.coverGradients 封面渐变令牌"
```

---

## Task 3: MusicSong 模型

**Files:**
- Create: `love_space/lib/features/music/models/music_song.dart`

- [ ] **Step 1: 创建模型**

```dart
import 'dart:typed_data';

/// 音乐歌曲内存模型
///
/// 从 on_audio_query 的 SongModel 映射而来，不落库（每次进入刷新扫描）。
/// [coverBytes] 为 null 时 UI 用 [coverIndex] 取 AppColors.coverGradients 占位。
class MusicSong {
  final int id;
  final String title;
  final String artist;
  final Duration duration;
  final String? uri;
  final int coverIndex;
  final Uint8List? coverBytes;

  const MusicSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.uri,
    required this.coverIndex,
    this.coverBytes,
  });

  /// 是否可播放（必须有 URI）
  bool get isPlayable => uri != null && uri!.isNotEmpty;
}
```

- [ ] **Step 2: 验证**

Run: `cd love_space && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd ..
git add love_space/lib/features/music/models/music_song.dart
git commit -m "feat(music): 新增 MusicSong 内存模型"
```

---

## Task 4: AudioBackend 接口 + FakeAudioBackend

**Files:**
- Create: `love_space/lib/features/music/providers/audio_backend.dart`

**Why:** just_audio 的 `AudioPlayer` 是具体类、依赖原生库，测试环境不可用。抽 `AudioBackend` 接口，Controller 依赖抽象，生产用 just_audio、测试用 FakeAudioBackend（StreamController 驱动）。

- [ ] **Step 1: 创建接口与 Fake**

```dart
import 'dart:async';
import 'dart:typed_data';

/// 音频播放后端抽象接口
///
/// Controller 依赖此抽象而非具体播放器，便于测试与未来替换引擎。
abstract class AudioBackend {
  Future<void> setUrl(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> seek(Duration position);

  /// 当前播放位置流
  Stream<Duration> get positionStream;
  /// 是否正在播放流
  Stream<bool> get playingStream;
  /// 当前曲目总时长流
  Stream<Duration?> get durationStream;
  /// 播放完成流（一首播完）
  Stream<void> get completedStream;

  void dispose();
}

/// 测试用 Fake：用 StreamController 模拟播放器行为
///
/// play() 后用 Timer 按 500ms 推进 position；到达 duration 时发 completed。
class FakeAudioBackend implements AudioBackend {
  FakeAudioBackend({this.autoAdvance = true});

  final bool autoAdvance;
  final _position = StreamController<Duration>.broadcast();
  final _playing = StreamController<bool>.broadcast();
  final _duration = StreamController<Duration?>.broadcast();
  final _completed = StreamController<void>.broadcast();

  Duration _pos = Duration.zero;
  Duration? _dur;
  bool _isPlaying = false;
  Timer? _timer;
  String? _currentUrl;

  @override
  Future<void> setUrl(String url) async {
    _currentUrl = url;
    _pos = Duration.zero;
    _position.add(_pos);
    _duration.add(_dur);
  }

  /// 测试辅助：设置当前曲目时长
  void setDuration(Duration d) {
    _dur = d;
    _duration.add(d);
  }

  @override
  Future<void> play() async {
    _isPlaying = true;
    _playing.add(true);
    if (autoAdvance) {
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(milliseconds: 500), (_) {
        _pos += const Duration(milliseconds: 500);
        if (_dur != null && _pos >= _dur!) {
          _pos = _dur!;
          _position.add(_pos);
          _completed.add(null);
          _timer?.cancel();
        } else {
          _position.add(_pos);
        }
      });
    }
  }

  @override
  Future<void> pause() async {
    _isPlaying = false;
    _playing.add(false);
    _timer?.cancel();
  }

  @override
  Future<void> seek(Duration position) async {
    _pos = position;
    _position.add(_pos);
  }

  @override
  Stream<Duration> get positionStream => _position.stream;
  @override
  Stream<bool> get playingStream => _playing.stream;
  @override
  Stream<Duration?> get durationStream => _duration.stream;
  @override
  Stream<void> get completedStream => _completed.stream;

  @override
  void dispose() {
    _timer?.cancel();
    _position.close();
    _playing.close();
    _duration.close();
    _completed.close();
  }
}
```

- [ ] **Step 2: 验证**

Run: `cd love_space && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd ..
git add love_space/lib/features/music/providers/audio_backend.dart
git commit -m "feat(music): AudioBackend 抽象接口 + FakeAudioBackend（测试用）"
```

---

## Task 5: MusicPlayerController + 单测（TDD）

**Files:**
- Create: `love_space/test/music/music_player_controller_test.dart`
- Create: `love_space/lib/features/music/providers/music_player_provider.dart`

- [ ] **Step 1: 写失败测试**

创建 `test/music/music_player_controller_test.dart`：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/features/music/models/music_song.dart';
import 'love_space/lib/features/music/providers/audio_backend.dart';
import 'package:love_space/features/music/providers/music_player_provider.dart';

MusicSong _song(int id, {String? uri, Duration? dur}) => MusicSong(
      id: id,
      title: '歌$id',
      artist: '歌手$id',
      duration: dur ?? const Duration(seconds: 10),
      uri: uri ?? 'file:///song$id.mp3',
      coverIndex: id % 6,
    );

void main() {
  late FakeAudioBackend backend;
  late ProviderContainer container;

  setUp(() {
    backend = FakeAudioBackend();
    container = ProviderContainer(overrides: [
      audioBackendProvider.overrideWithValue(backend),
    ]);
  });
  tearDown(() {
    container.dispose();
    backend.dispose();
  });

  test('初始状态：无曲目、未播放、currentIndex=-1', () {
    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, -1);
    expect(state.isPlaying, false);
    expect(state.playlist, isEmpty);
  });

  test('setPlaylist 注入歌单后 playlist 非空', () {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2)]);
    expect(container.read(musicPlayerProvider).playlist.length, 2);
  });

  test('selectSong 设置当前曲并 setUrl+play', () async {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2)]);
    await ctrl.selectSong(0);
    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, 0);
    expect(state.isPlaying, true);
  });

  test('togglePlay 切换播放暂停', () async {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1)]);
    await ctrl.selectSong(0);
    expect(container.read(musicPlayerProvider).isPlaying, true);
    await ctrl.togglePlay();
    expect(container.read(musicPlayerProvider).isPlaying, false);
    await ctrl.togglePlay();
    expect(container.read(musicPlayerProvider).isPlaying, true);
  });

  test('next 末首回第一首；previous 首首回末首', () async {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2), _song(3)]);
    await ctrl.selectSong(2); // 末首
    await ctrl.next();
    expect(container.read(musicPlayerProvider).currentIndex, 0);
    await ctrl.previous();
    expect(container.read(musicPlayerProvider).currentIndex, 2);
  });

  test('seekTo 设置进度', () async {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1, dur: const Duration(seconds: 60))]);
    backend.setDuration(const Duration(seconds: 60));
    await ctrl.selectSong(0);
    await ctrl.seekTo(const Duration(seconds: 30));
    expect(container.read(musicPlayerProvider).position,
        const Duration(seconds: 30));
  });

  test('播放完成自动切下一首', () async {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1, dur: const Duration(milliseconds: 500)),
                       _song(2, dur: const Duration(milliseconds: 500))]);
    backend.setDuration(const Duration(milliseconds: 500));
    await ctrl.selectSong(0);
    // 等待 Fake 的 500ms Timer 触发 completed
    await Future.delayed(const Duration(milliseconds: 800));
    expect(container.read(musicPlayerProvider).currentIndex, 1);
  });
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `cd love_space && flutter test test/music/music_player_controller_test.dart`
Expected: FAIL — `music_player_provider.dart` 不存在 / imports 无法解析

- [ ] **Step 3: 实现 Controller**

创建 `lib/features/music/providers/music_player_provider.dart`：

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/music_song.dart';
import 'audio_backend.dart';

/// 播放器状态
class MusicPlayerState {
  final List<MusicSong> playlist;
  final int currentIndex; // -1 = 未选
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final bool isLoading; // setUrl 期间

  const MusicPlayerState({
    this.playlist = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration,
    this.isLoading = false,
  });

  MusicPlayerState copyWith({
    List<MusicSong>? playlist,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Duration? duration,
    bool? isLoading,
  }) =>
      MusicPlayerState(
        playlist: playlist ?? this.playlist,
        currentIndex: currentIndex ?? this.currentIndex,
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: duration ?? this.duration,
        isLoading: isLoading ?? this.isLoading,
      );

  MusicSong? get currentSong =>
      currentIndex >= 0 && currentIndex < playlist.length
          ? playlist[currentIndex]
          : null;
}

/// AudioBackend provider（生产用 just_audio 实现，测试 override）
final audioBackendProvider = Provider<AudioBackend>((ref) {
  // 默认抛异常，由 main 或测试 override；生产实现在 just_audio_backend.dart
  throw UnimplementedError('audioBackendProvider 必须被 override');
});

/// 音乐播放控制器
class MusicPlayerController extends Notifier<MusicPlayerState> {
  AudioBackend get _backend => ref.read(audioBackendProvider);
  StreamSubscription? _posSub;
  StreamSubscription? _playingSub;
  StreamSubscription? _durationSub;
  StreamSubscription? _completedSub;

  @override
  MusicPlayerState build() {
    ref.onDispose(_dispose);
    return const MusicPlayerState();
  }

  void _dispose() {
    _posSub?.cancel();
    _playingSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
  }

  /// 注入扫描到的歌单
  void setPlaylist(List<MusicSong> songs) {
    state = state.copyWith(playlist: songs);
  }

  /// 选择并播放指定曲目
  Future<void> selectSong(int index) async {
    if (index < 0 || index >= state.playlist.length) return;
    final song = state.playlist[index];
    if (!song.isPlayable) return;
    state = state.copyWith(currentIndex: index, isLoading: true, position: Duration.zero);
    _subscribeStreams();
    try {
      await _backend.setUrl(song.uri!);
      await _backend.play();
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> togglePlay() async {
    if (state.currentIndex < 0) return;
    if (state.isPlaying) {
      await _backend.pause();
    } else {
      await _backend.play();
    }
  }

  Future<void> next() async {
    if (state.playlist.isEmpty) return;
    final nextIdx = (state.currentIndex + 1) % state.playlist.length;
    await selectSong(nextIdx);
  }

  Future<void> previous() async {
    if (state.playlist.isEmpty) return;
    final prevIdx = state.currentIndex <= 0
        ? state.playlist.length - 1
        : state.currentIndex - 1;
    await selectSong(prevIdx);
  }

  Future<void> seekTo(Duration position) async {
    await _backend.seek(position);
    state = state.copyWith(position: position);
  }

  void _subscribeStreams() {
    _posSub ??= _backend.positionStream.listen((p) {
      state = state.copyWith(position: p);
    });
    _playingSub ??= _backend.playingStream.listen((playing) {
      state = state.copyWith(isPlaying: playing);
    });
    _durationSub ??= _backend.durationStream.listen((d) {
      state = state.copyWith(duration: d);
    });
    _completedSub ??= _backend.completedStream.listen((_) async {
      await next();
    });
  }
}

final musicPlayerProvider =
    NotifierProvider<MusicPlayerController, MusicPlayerState>(
  MusicPlayerController.new,
);
```

- [ ] **Step 4: 运行测试确认通过**

Run: `cd love_space && flutter test test/music/music_player_controller_test.dart`
Expected: All tests passed (7)

- [ ] **Step 5: Commit**

```bash
cd ..
git add love_space/test/music/music_player_controller_test.dart love_space/lib/features/music/providers/music_player_provider.dart
git commit -m "feat(music): MusicPlayerController + 单测（接 AudioBackend）"
```

---

## Task 6: JustAudioBackend 实现

**Files:**
- Create: `love_space/lib/features/music/providers/just_audio_backend.dart`

- [ ] **Step 1: 实现 just_audio 后端**

```dart
import 'dart:async';
import 'package:just_audio/just_audio.dart';
import 'audio_backend.dart';

/// just_audio 实现 AudioBackend
class JustAudioBackend implements AudioBackend {
  JustAudioBackend() : _player = AudioPlayer();

  final AudioPlayer _player;
  StreamSubscription<Duration>? _posSub;
  final _positionController = StreamController<Duration>.broadcast();
  final _completedController = StreamController<void>.broadcast();

  @override
  Future<void> setUrl(String url) => _player.setUrl(url);

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Stream<Duration> get positionStream => _positionController.stream;

  @override
  Stream<bool> get playingStream => _player.playingStream;

  @override
  Stream<Duration?> get durationStream => _player.durationStream;

  @override
  Stream<void> get completedStream => _completedController.stream;

  /// 初始化：将 just_audio 的 processingStateStream 转为 completed 事件
  void init() {
    _posSub = _player.positionStream.listen(_positionController.add);
    _player.processingStateStream.listen((state) {
      if (state.processingState == ProcessingState.completed) {
        _completedController.add(null);
        _player.seek(Duration.zero); // 重置以便下一首
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _positionController.close();
    _completedController.close();
    _player.dispose();
  }
}
```

- [ ] **Step 2: 在 main.dart 注入生产后端**

修改 `lib/main.dart`，在 `ProviderScope` 的 `overrides` 中加入后端注入。先读 `main.dart` 确认当前 overrides 结构（已知 `isarProvider.overrideWithValue(isar)`），在其后添加：

```dart
// 在文件顶部 import 区加：
import 'features/music/providers/audio_backend.dart';
import 'features/music/providers/just_audio_backend.dart';

// 在 main() 内创建后端实例并注入 overrides：
final audioBackend = JustAudioBackend()..init();

runApp(
  ProviderScope(
    overrides: [
      isarProvider.overrideWithValue(isar),
      audioBackendProvider.overrideWithValue(audioBackend),
    ],
    child: const LoveSpaceApp(),
  ),
);
```

- [ ] **Step 3: 验证**

Run: `cd love_space && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
cd ..
git add love_space/lib/features/music/providers/just_audio_backend.dart love_space/lib/main.dart
git commit -m "feat(music): JustAudioBackend 实现并在 main 注入"
```

---

## Task 7: MusicLibraryProvider（扫描设备音乐库）

**Files:**
- Create: `love_space/lib/features/music/providers/music_library_provider.dart`

**Note:** `on_audio_query` 依赖原生库，测试环境无法运行；此 provider 不写单测，由 widget_test override 隔离。

- [ ] **Step 1: 实现扫描 provider**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';
import '../../app/theme/app_colors.dart';
import '../models/music_song.dart';

/// 权限被拒绝
class MusicPermissionDeniedException implements Exception {}

/// 本地音乐库扫描 provider
///
/// 请求 Android 音频权限 -> 查询全部音乐 -> 映射为 MusicSong 列表。
/// 失败（权限拒绝/无歌）返回空列表或抛 MusicPermissionDeniedException。
final musicLibraryProvider =
    FutureProvider<List<MusicSong>>((ref) async {
  final audioQuery = OnAudioQuery();
  final hasPermission = await audioQuery.permissionsRequest();
  if (!hasPermission) throw MusicPermissionDeniedException();

  final songs = await audioQuery.querySongs(
    type: SongType.IS_MUSIC,
    sortType: SongSortType.DATE_ADDED,
    orderType: OrderType.DESC,
  );

  final result = <MusicSong>[];
  for (var i = 0; i < songs.length; i++) {
    final s = songs[i];
    final uri = s.uri;
    if (uri == null || uri.isEmpty) continue; // 无 URI 不可播放，过滤

    Uint8List? cover;
    try {
      cover = await audioQuery.queryArtwork(s.id, ArtworkType.AUDIO,
          size: 150);
    } catch (_) {
      // 封面取失败用渐变占位，不阻断扫描
    }

    result.add(MusicSong(
      id: s.id,
      title: s.title.trim().isEmpty ? '未知歌曲' : s.title,
      artist: s.artist?.trim().isEmpty ?? true ? '未知艺术家' : s.artist!,
      duration: Duration(milliseconds: s.duration ?? 0),
      uri: uri,
      coverIndex: s.id % AppColors.coverGradients.length,
      coverBytes: cover,
    ));
  }
  return result;
});
```

**需在文件顶部加 `import 'dart:typed_data';`**（Uint8List）。

- [ ] **Step 2: 在 Controller 接 library（歌单自动注入）**

修改 `music_player_provider.dart` 的 `build()`，监听 library 并自动 setPlaylist：

```dart
@override
MusicPlayerState build() {
  ref.onDispose(_dispose);
  // 监听扫描结果，自动注入歌单
  ref.listen<AsyncValue<List<MusicSong>>>(musicLibraryProvider, (_, async) {
    final songs = async.valueOrNull;
    if (songs != null && songs.isNotEmpty && state.playlist.isEmpty) {
      setPlaylist(songs);
    }
  });
  return const MusicPlayerState();
}
```

并在文件顶部加：`import 'music_library_provider.dart';`

- [ ] **Step 3: 验证编译**

Run: `cd love_space && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
cd ..
git add love_space/lib/features/music/providers/music_library_provider.dart love_space/lib/features/music/providers/music_player_provider.dart
git commit -m "feat(music): MusicLibraryProvider 扫描设备音乐库并注入 Controller"
```

---

## Task 8: MiniPlayerBar 组件

**Files:**
- Create: `love_space/lib/features/music/presentation/widgets/mini_player_bar.dart`

- [ ] **Step 1: 实现迷你播放条**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../models/music_song.dart';
import '../../providers/music_player_provider.dart';
import '../music_player_page.dart';

/// 底部常驻迷你播放条
///
/// 有当前曲目时显示；点击打开全屏播放页，播放/暂停按钮独立响应。
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerProvider);
    final song = state.currentSong;
    if (song == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => MusicPlayerPage.show(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowCard,
              blurRadius: 12,
              offset: Offset(0, 2),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          children: [
            _Cover(song: song, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(song.title,
                      style: AppTextStyles.body,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(song.artist,
                      style: AppTextStyles.caption,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            GestureDetector(
              onTap: () => ref.read(musicPlayerProvider.notifier).togglePlay(),
              child: Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  gradient: AppColors.pinkButtonGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  state.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: Colors.white, size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 封面（有图用图，无图渐变占位）
class _Cover extends StatelessWidget {
  const _Cover({required this.song, required this.size});
  final MusicSong song;
  final double size;

  @override
  Widget build(BuildContext context) {
    final gradient = AppColors.coverGradients[song.coverIndex];
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: song.coverBytes == null ? gradient : null,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: song.coverBytes == null
          ? Icon(Icons.music_note_rounded, color: Colors.white, size: size * 0.5)
          : ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.3),
              child: Image.memory(song.coverBytes!,
                  fit: BoxFit.cover),
            ),
    );
  }
}
```

- [ ] **Step 2: 验证**

Run: `cd love_space && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd ..
git add love_space/lib/features/music/presentation/widgets/mini_player_bar.dart
git commit -m "feat(music): MiniPlayerBar 底部常驻迷你播放条"
```

---

## Task 9: PlaylistSheet 组件

**Files:**
- Create: `love_space/lib/features/music/presentation/widgets/playlist_sheet.dart`

- [ ] **Step 1: 实现歌曲列表弹层**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../providers/music_player_provider.dart';
import '../music_player_page.dart';

/// 歌曲列表弹层
///
/// 展示扫描到的全部歌曲，当前曲目高亮 + 播放中音符；点击切歌。
class PlaylistSheet extends ConsumerWidget {
  const PlaylistSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) =>
            const PlaylistSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerProvider);
    final songs = state.playlist;
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.only(top: 10),
          width: 40, height: 4,
          decoration: BoxDecoration(
            color: AppColors.textTertiary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('播放列表（${songs.length} 首）',
              style: AppTextStyles.titleMedium),
        ),
        Expanded(
          child: songs.isEmpty
              ? Center(child: Text('没有找到本地音乐', style: AppTextStyles.caption))
              : ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (_, i) {
                    final s = songs[i];
                    final isCurrent = i == state.currentIndex;
                    return ListTile(
                      leading: _leading(isCurrent, state.isPlaying),
                      title: Text(s.title,
                          style: isCurrent
                              ? AppTextStyles.body.copyWith(color: AppColors.accentRose)
                              : AppTextStyles.body,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text('${s.artist} · ${_fmt(s.duration)}',
                          style: AppTextStyles.caption, maxLines: 1),
                      onTap: () => ref
                          .read(musicPlayerProvider.notifier)
                          .selectSong(i),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _leading(bool isCurrent, bool isPlaying) {
    if (!isCurrent) {
      return Icon(Icons.music_note_rounded, color: AppColors.textTertiary, size: 24);
    }
    return Icon(
      isPlaying ? Icons.equalizer_rounded : Icons.music_note_rounded,
      color: AppColors.accentRose, size: 24,
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// 顶层 import 避免 MusicPlayerPage.show 循环引用问题：PlaylistSheet 不调 MusicPlayerPage
/// （删除上述未用 import）
```

**修正：** 文件顶部不要 import `music_player_page.dart`（PlaylistSheet 不需要打开播放页）。请删除该 import 行。`MusicPlayerPage.show` 引用不存在于此文件，移除。

- [ ] **Step 2: 清理无用 import 并验证**

确保文件顶部仅：
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../providers/music_player_provider.dart';
```

Run: `cd love_space && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd ..
git add love_space/lib/features/music/presentation/widgets/playlist_sheet.dart
git commit -m "feat(music): PlaylistSheet 歌曲列表弹层"
```

---

## Task 10: MusicPlayerPage 全屏播放页

**Files:**
- Create: `love_space/lib/features/music/presentation/music_player_page.dart`

- [ ] **Step 1: 实现全屏播放页**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import '../../shared/widgets/app_snackbar.dart';
import '../providers/music_library_provider.dart';
import '../providers/music_player_provider.dart';
import 'widgets/playlist_sheet.dart';

/// 全屏音乐播放页（网易云风格）
class MusicPlayerPage extends ConsumerStatefulWidget {
  const MusicPlayerPage({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MusicPlayerPage(),
    );
  }

  @override
  ConsumerState<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends ConsumerState<MusicPlayerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotateCtrl;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicPlayerProvider);
    final song = state.currentSong;
    final library = ref.watch(musicLibraryProvider);

    // 旋转动画跟随播放状态
    if (state.isPlaying) {
      if (!_rotateCtrl.isAnimating) _rotateCtrl.repeat();
    } else {
      _rotateCtrl.stop();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,
        ),
        child: SafeArea(
          child: library.when(
            loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => e is MusicPermissionDeniedException
                ? _PermissionState(onRetry: () => ref
                    .refresh(musicLibraryProvider))
                : Center(child: Text('加载失败', style: AppTextStyles.body)),
            data: (songs) => songs.isEmpty
                ? _EmptyState()
                : _playerContent(song, state),
          ),
        ),
      ),
    );
  }

  Widget _playerContent(song, state) {
    return Column(
      children: [
        // 顶部：收起条 + 歌名
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40, height: 4,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: Colors.white54,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(state.currentSong?.title ?? '',
            style: AppTextStyles.titleLarge, maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(state.currentSong?.artist ?? '',
            style: AppTextStyles.caption),
        const SizedBox(height: 24),
        // 大封面（旋转）
        Expanded(
          child: Center(
            child: RotationTransition(
              turns: _rotateCtrl,
              child: _BigCover(song: state.currentSong),
            ),
          ),
        ),
        // 进度条
        _ProgressRow(state: state),
        const SizedBox(height: 8),
        // 控制区
        _Controls(state: state),
        const SizedBox(height: 8),
        // 列表按钮
        IconButton(
          icon: const Icon(Icons.queue_music_rounded,
              color: AppColors.textOnPink),
          onPressed: () => PlaylistSheet.show(context),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

class _BigCover extends StatelessWidget {
  final dynamic song;
  const _BigCover({required this.song});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.7;
    if (song == null) {
      return Container(
        width: size, height: size,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Icon(Icons.music_note_rounded,
            size: size * 0.4, color: AppColors.accentRose),
      );
    }
    final gradient = AppColors.coverGradients[song.coverIndex];
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(
        gradient: song.coverBytes == null ? gradient : null,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowCard, blurRadius: 20,
              offset: Offset(0, 8)),
        ],
      ),
      child: song.coverBytes == null
          ? Icon(Icons.music_note_rounded, size: size * 0.4,
              color: Colors.white)
          : ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Image.memory(song.coverBytes!, fit: BoxFit.cover),
            ),
    );
  }
}

class _ProgressRow extends ConsumerWidget {
  final MusicPlayerState state;
  const _ProgressRow({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = state.duration?.inSeconds ?? 0;
    final pos = state.position.inSeconds.clamp(0, total > 0 ? total : 0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Slider(
            value: total > 0 ? pos / total : 0,
            min: 0, max: 1,
            activeColor: AppColors.accentRose,
            onChanged: total > 0
                ? (v) => ref.read(musicPlayerProvider.notifier).seekTo(
                    Duration(seconds: (v * total).round()))
                : null,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(state.position), style: AppTextStyles.caption),
              Text(_fmt(state.duration ?? Duration.zero),
                  style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _Controls extends ConsumerWidget {
  final MusicPlayerState state;
  const _Controls({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(musicPlayerProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded,
              size: 48, color: AppColors.textOnPink),
          onPressed: () async {
            try { await ctrl.previous(); }
            catch (_) {
              if (context.mounted) AppSnackbar.show(context, '切换失败');
            }
          },
        ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: () => ctrl.togglePlay(),
          child: Container(
            width: 72, height: 72,
            decoration: const BoxDecoration(
              gradient: AppColors.pinkButtonGradient,
              shape: BoxShape.circle,
            ),
            child: state.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : Icon(
                    state.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    size: 40, color: Colors.white,
                  ),
          ),
        ),
        const SizedBox(width: 24),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded,
              size: 48, color: AppColors.textOnPink),
          onPressed: () async {
            try { await ctrl.next(); }
            catch (_) {
              if (context.mounted) AppSnackbar.show(context, '切换失败');
            }
          },
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.music_off_rounded, size: 64,
              color: AppColors.textOnPink),
          const SizedBox(height: 16),
          Text('没有找到本地音乐', style: AppTextStyles.titleMedium
              .copyWith(color: AppColors.textOnPink)),
          const SizedBox(height: 8),
          Text('请将音乐文件放入设备后重试', style: AppTextStyles.caption
              .copyWith(color: AppColors.textOnPink)),
        ],
      ),
    );
  }
}

class _PermissionState extends StatelessWidget {
  final VoidCallback onRetry;
  const _PermissionState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.lock_outline_rounded, size: 64,
              color: AppColors.textOnPink),
          const SizedBox(height: 16),
          Text('需要音乐权限', style: AppTextStyles.titleMedium
              .copyWith(color: AppColors.textOnPink)),
          const SizedBox(height: 8),
          Text('授权后才能扫描本地音乐', style: AppTextStyles.caption
              .copyWith(color: AppColors.textOnPink)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: AppColors.bgCard),
            child: Text('重新授权', style: AppTextStyles.body
                .copyWith(color: AppColors.accentRose)),
          ),
        ],
      ),
    );
  }
}
```

**注意 import：** `app_colors.dart` / `app_text_styles.dart` 路径是 `../../app/theme/...`（music_player_page.dart 在 `features/music/presentation/`）。`shared/widgets/app_snackbar.dart` 路径是 `../../shared/widgets/app_snackbar.dart`。请按实际层级核对（CLAUDE.md 6.2：相对路径不超 4 级）。

- [ ] **Step 2: 修正 import 层级**

文件位于 `lib/features/music/presentation/music_player_page.dart`，相对路径：
- `import '../../../app/theme/app_colors.dart';`  (3 级回退到 lib/)
- `import '../../../app/theme/app_text_styles.dart';`
- `import '../../../shared/widgets/app_snackbar.dart';`
- `import '../providers/music_library_provider.dart';`
- `import '../providers/music_player_provider.dart';`
- `import 'widgets/playlist_sheet.dart';`

请用这组精确 import 替换 Step 1 中的相对路径。同样核对 `mini_player_bar.dart` 和 `playlist_sheet.dart` 的 import 层级（它们在 `presentation/widgets/`，回退 3 级到 lib/）。

- [ ] **Step 3: 验证**

Run: `cd love_space && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
cd ..
git add love_space/lib/features/music/presentation/music_player_page.dart
git commit -m "feat(music): MusicPlayerPage 全屏播放页（旋转封面/进度/控制/列表）"
```

---

## Task 11: MainShell 集成迷你播放条

**Files:**
- Modify: `love_space/lib/shared/layouts/main_shell.dart`

- [ ] **Step 1: 底部叠加迷你条**

修改 `main_shell.dart`（当前 `bottomNavigationBar: const PillNavBar()` 在第 36 行）。将其改为包含 MiniPlayerBar 的 Column：

```dart
// 顶部 import 区新增：
import '../../features/music/presentation/widgets/mini_player_bar.dart';

// build() 内的 bottomNavigationBar 改为：
bottomNavigationBar: Column(
  mainAxisSize: MainAxisSize.min,
  children: const [
    MiniPlayerBar(),
    PillNavBar(),
  ],
),
```

- [ ] **Step 2: 验证**

Run: `cd love_space && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 3: Commit**

```bash
cd ..
git add love_space/lib/shared/layouts/main_shell.dart
git commit -m "feat(music): MainShell 底部常驻 MiniPlayerBar"
```

---

## Task 12: 入口串联（profile + home）

**Files:**
- Modify: `love_space/lib/features/profile/presentation/profile_page.dart`
- Modify: `love_space/lib/features/home/presentation/home_page.dart`

- [ ] **Step 1: profile 音乐卡真实化**

`_MusicCard` 当前是 `StatelessWidget`（约 194 行），文案硬编码「32 首 · 正在播放"小幸运"」。改为 `ConsumerWidget`，文案读 Controller，onTap 打开播放页。

读 `profile_page.dart:194-260` 确认 `_MusicCard` 完整结构后：
1. 类签名改为 `class _MusicCard extends ConsumerWidget`，移除 `Widget build` 的 `BuildContext` 单参数改为 `(context, ref)`
2. 替换文案行（原 235 行附近）：

```dart
// 替换硬编码 Text：
final playerState = ref.watch(musicPlayerProvider);
final libraryAsync = ref.watch(musicLibraryProvider);
final count = libraryAsync.valueOrNull?.length ?? 0;
final current = playerState.currentSong;
final sub = current != null
    ? '$count 首 · 正在播放「${current.title}」'
    : '$count 首 · 点击播放';
// 用 sub 替换原 '32 首 · 正在播放"小幸运"'
```

3. 替换 onTap（原 240 行附近 `AppSnackbar.show(context, '即将上线 🎵')`）：

```dart
onTap: () => MusicPlayerPage.show(context),
```

4. 顶部 import 新增：
```dart
import '../../music/presentation/music_player_page.dart';
import '../../music/providers/music_player_provider.dart';
import '../../music/providers/music_library_provider.dart';
```

- [ ] **Step 2: home 音乐入口接通**

`home_page.dart:362-367` 音乐快捷入口 onTap 当前是 `AppSnackbar.show(context, '即将上线 🎵')`。改为打开播放页：

```dart
// 替换 onTap：
onTap: () => MusicPlayerPage.show(context),
```

顶部 import 新增：
```dart
import '../music/presentation/music_player_page.dart';
```

- [ ] **Step 3: 验证**

Run: `cd love_space && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 4: Commit**

```bash
cd ..
git add love_space/lib/features/profile/presentation/profile_page.dart love_space/lib/features/home/presentation/home_page.dart
git commit -m "feat(music): profile 音乐卡真实化 + home 音乐入口接通"
```

---

## Task 13: widget_test override 与冒烟测试

**Files:**
- Modify: `love_space/test/widget_test.dart`

- [ ] **Step 1: 补充 music provider override**

读 `widget_test.dart` 确认现有 `ProviderScope` overrides 列表。新增 music 相关 override，避免 `audioBackendProvider` 默认抛 `UnimplementedError` 与 `musicLibraryProvider` 触发原生库：

```dart
// 顶部 import 新增：
import 'package:love_space/features/music/providers/audio_backend.dart';
import 'package:love_space/features/music/providers/music_player_provider.dart';
import 'package:love_space/features/music/providers/music_library_provider.dart';

// overrides 列表新增：
audioBackendProvider.overrideWithValue(FakeAudioBackend()),
musicLibraryProvider.overrideWith((ref) async => []), // 空歌单避免原生调用
```

- [ ] **Step 2: 运行测试**

Run: `cd love_space && flutter test`
Expected: All tests passed（含 music controller 7 个 + 现有 +6 ~8）

- [ ] **Step 3: Commit**

```bash
cd ..
git add love_space/test/widget_test.dart
git commit -m "test(music): widget_test 补 music provider override 隔离"
```

---

## Task 14: 全量验证

- [ ] **Step 1: analyze**

Run: `cd love_space && flutter analyze`
Expected: `No issues found!`

- [ ] **Step 2: test**

Run: `cd love_space && flutter test`
Expected: All tests passed

- [ ] **Step 3: build**

Run: `cd love_space && flutter build apk --debug`
Expected: `✓ Built build\app\outputs\flutter-apk\app-debug.apk`

- [ ] **Step 4: 真机冒烟（手动，记录结果）**

`flutter run` 到手机，验证：
- 首次打开音乐页弹出权限请求 -> 授权
- 扫描到本地音乐 -> 迷你条显示第一首
- 点迷你条 -> 全屏页，封面旋转，有声音
- 拖进度条 -> seek 生效
- 上一首/下一首 -> 切歌正常
- 列表按钮 -> 弹出歌单，点击切歌
- 播完一首 -> 自动下一首
- profile 音乐卡文案显示真实首数与当前曲名

- [ ] **Step 5: 最终 Commit（若有修复）**

如发现问题，修复后 commit；无问题则跳过。

---

## Self-Review 结果

**Spec 覆盖：** ✓ 依赖(Task1) ✓ 渐变令牌(Task2) ✓ MusicSong(Task3) ✓ AudioBackend/Controller(Task4-5) ✓ just_audio(Task6) ✓ 扫描(Task7) ✓ 迷你条(Task8) ✓ 列表弹层(Task9) ✓ 全屏页(Task10) ✓ MainShell(Task11) ✓ 入口(Task12) ✓ 测试(Task13) ✓ 验证(Task14) — 权限拒绝/空态/URI失效 均有对应 UI/逻辑。

**类型一致性：** `MusicPlayerState` 字段、`MusicPlayerController` 方法名（setPlaylist/selectSong/togglePlay/next/previous/seekTo）在 Task5/8/9/10/12 中一致；`audioBackendProvider` 全局统一。

**已知需实现时核对项（非占位符，是精确指引）：** import 相对路径层级（Task10 Step2 已明确列出正确层级）；profile `_MusicCard` 改 ConsumerWidget 时需读原文确认行号。
