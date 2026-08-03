import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/music_song.dart';
import 'audio_backend.dart';

/// 播放失败异常（URI 失效 / 引擎异常等）
///
/// 由 [MusicPlayerController.selectSong] 捕获底层错误后重新抛出，
/// 供各调用点在 UI 层提示 [feedbackMessage]，避免未处理异步异常导致崩溃。
class MusicPlaybackException implements Exception {
  MusicPlaybackException(this.index, this.cause);

  /// 失败的曲目在歌单中的索引
  final int index;
  final Object cause;

  /// 统一反馈文案：URI 失效等播放失败
  static const feedbackMessage = '该曲目无法播放';

  @override
  String toString() => 'MusicPlaybackException(index: $index, cause: $cause)';
}

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
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<bool>? _playingSub;
  StreamSubscription<Duration?>? _durationSub;
  StreamSubscription<void>? _completedSub;

  // 请求序号：每次切歌自增。setUrl/play 完成后比对，若已不是最新请求则丢弃结果，
  // 防止快速连点时较早的 setUrl 晚完成导致 play(A) 而 UI 显示 B。
  int _requestSeq = 0;

  // 在途加载的曲目索引与 Future：auto-advance 与用户点击可能并发加载同一曲目，
  // 按 index 合并（复用同一个 Future、不重复 setUrl），保证用户的点击始终拥有该曲目，
  // 避免 auto-advance 的第二次 ++_requestSeq 把用户请求标记为 stale 后静默丢弃。
  int? _pendingIndex;
  Future<void>? _pendingLoad;

  // 已实际 setUrl 加载成功的曲目索引；null = 当前曲从未加载。
  // setPlaylist 只自动选中不播放，togglePlay 需区分「恢复播放」与「先加载再播放」：
  // just_audio 无源时 play() 仅置 playing 标志不发声，直接 play 会「假播放」。
  int? _loadedIndex;

  @override
  MusicPlayerState build() {
    ref.onDispose(_dispose);
    // 注意：此处不再自动监听 musicLibraryProvider。
    // 歌单由播放页显式注入（见 music_player_page.dart 的 listenManual），
    // 避免 MiniPlayerBar 常驻导致 controller 在启动即 build、进而触发权限请求。
    return const MusicPlayerState();
  }

  void _dispose() {
    _posSub?.cancel();
    _playingSub?.cancel();
    _durationSub?.cancel();
    _completedSub?.cancel();
  }

  /// 注入扫描到的歌单
  ///
  /// 未选过歌（currentIndex == -1）且歌单非空时自动选中第一首（只选中不播放），
  /// 避免播放页打开后标题/封面空白占位；已选过歌则保持当前曲不变。
  void setPlaylist(List<MusicSong> songs) {
    // 新歌单注入：无论是否保留 currentIndex，曲目都未在本会话加载过，
    // 播放键需先加载（见 togglePlay）
    _loadedIndex = null;
    if (state.currentIndex < 0 && songs.isNotEmpty) {
      state = state.copyWith(playlist: songs, currentIndex: 0);
    } else {
      state = state.copyWith(playlist: songs);
    }
  }

  /// 选择并播放指定曲目
  ///
  /// 若播放失败（URI 失效等），回滚 currentIndex（仅在成功后置为当前曲），
  /// 尝试自动跳下一首，并重新抛出 [MusicPlaybackException] 供调用点提示。
  Future<void> selectSong(int index) async {
    if (index < 0 || index >= state.playlist.length) return;
    final song = state.playlist[index];
    if (!song.isPlayable) return;
    try {
      await _loadAndPlay(index, song);
    } on MusicPlaybackException {
      // 播放失败（URI 失效等）：回滚 + 自动跳下一首，并重新抛出供调用点提示
      await _autoAdvance(index);
      rethrow;
    }
    // 其它异常（编程错误）不拦截：原样向上抛，避免被 auto-advance 掩盖真实 bug
  }

  /// 加载并播放指定曲目（带同曲目在途合并）
  ///
  /// 若同一曲目已有在途加载（用户点击与 auto-advance 并发命中同一 index），
  /// 直接复用该 Future，不重复 setUrl，避免对同一 AudioPlayer 二次 setUrl 导致
  /// 用户点击被 auto-advance 的请求序号覆盖而静默丢弃。
  Future<void> _loadAndPlay(int index, MusicSong song) {
    if (_pendingIndex == index && _pendingLoad != null) {
      return _pendingLoad!;
    }
    _pendingIndex = index;
    final future = _doLoadAndPlay(index, song).whenComplete(() {
      if (_pendingIndex == index) {
        _pendingIndex = null;
        _pendingLoad = null;
      }
    });
    _pendingLoad = future;
    return future;
  }

  /// 底层加载并播放：设置 isLoading -> setUrl -> play -> 成功后置 currentIndex
  ///
  /// 带请求序号保护：期间有更新的切歌请求时丢弃本次结果（不播放、不更新状态）。
  /// 失败抛 [MusicPlaybackException]，失败时不清除最新请求的加载态。
  Future<void> _doLoadAndPlay(int index, MusicSong song) async {
    final seq = ++_requestSeq;
    _subscribeStreams();
    state = state.copyWith(isLoading: true, position: Duration.zero);
    try {
      await _backend.setUrl(song.uri!);
      if (seq != _requestSeq) return; // 已被更新的切歌请求取代，丢弃结果
      await _backend.play();
      if (seq != _requestSeq) return; // 同上
      state = state.copyWith(
        currentIndex: index,
        isLoading: false,
        position: Duration.zero,
      );
      _loadedIndex = index;
    } catch (e) {
      if (seq != _requestSeq) return; // 过期请求的失败忽略，交由最新请求处理
      state = state.copyWith(isLoading: false);
      throw MusicPlaybackException(index, e);
    }
  }

  /// 播放失败后自动跳下一首（跳过坏 URI，最多尝试一圈，避免死循环）
  Future<void> _autoAdvance(int fromIndex) async {
    final len = state.playlist.length;
    if (len <= 1) return; // 没有可跳的下一首
    var idx = (fromIndex + 1) % len;
    var tried = 0;
    // 从下一首起逐个尝试，回到 fromIndex 或试满一圈即停
    while (tried < len && idx != fromIndex) {
      final song = state.playlist[idx];
      if (song.isPlayable) {
        try {
          await _loadAndPlay(idx, song);
          return; // 找到可播的下一首
        } on MusicPlaybackException {
          // 这首也失败，继续下一首
        }
      }
      tried++;
      idx = (idx + 1) % len;
    }
  }

  Future<void> togglePlay() async {
    // 歌单为空则仍直接返回；从未选中时兜底播第一首
    //（setPlaylist 已自动选中，此分支实际为防御）
    if (state.currentIndex < 0) {
      if (state.playlist.isEmpty) return;
      await selectSong(0);
      return;
    }
    if (state.isPlaying) {
      await _backend.pause();
      return;
    }
    // 当前曲只是被 setPlaylist 自动选中、从未 setUrl 加载（只选中不播放）时，
    // 直接 play() 无源无效（just_audio 无源 play 仅置 playing 标志、不发声），
    // 需先 selectSong 完成加载再播放
    if (_loadedIndex != state.currentIndex) {
      await selectSong(state.currentIndex);
      return;
    }
    await _backend.play();
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
    try {
      await _backend.seek(position);
      state = state.copyWith(position: position);
    } catch (e) {
      // seek 失败（如拖动时引擎异常）不打断播放，仅记录
      debugPrint('Seek failed: $e');
    }
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
    // 非 async 监听器 + 内部 try/catch：避免 completedStream 的异步异常未被处理
    _completedSub ??= _backend.completedStream.listen((_) {
      _onTrackCompleted();
    });
  }

  /// 一首播完自动切下一首；失败已被 selectSong 内部兜底，此处仅记录
  Future<void> _onTrackCompleted() async {
    try {
      await next();
    } catch (e) {
      debugPrint('自动切歌失败: $e');
    }
  }
}

final musicPlayerProvider =
    NotifierProvider<MusicPlayerController, MusicPlayerState>(
  MusicPlayerController.new,
);
