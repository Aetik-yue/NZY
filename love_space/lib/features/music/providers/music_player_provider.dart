import 'dart:async';
import 'dart:math';

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

/// 播放模式
enum PlayMode { sequence, shuffle, repeatOne }

const Object _keepDuration = Object();

/// 播放器状态
class MusicPlayerState {
  final List<MusicSong> playlist;
  final int currentIndex; // -1 = 未选
  final bool isPlaying;
  final Duration position;
  final Duration? duration;
  final bool isLoading; // setUrl 期间
  final PlayMode playMode;
  final bool isHidden; // 用户滑动关闭迷你条后隐藏（保留曲与进度）

  const MusicPlayerState({
    this.playlist = const [],
    this.currentIndex = -1,
    this.isPlaying = false,
    this.position = Duration.zero,
    this.duration,
    this.isLoading = false,
    this.playMode = PlayMode.sequence,
    this.isHidden = false,
  });

  MusicPlayerState copyWith({
    List<MusicSong>? playlist,
    int? currentIndex,
    bool? isPlaying,
    Duration? position,
    Object? duration = _keepDuration,
    bool? isLoading,
    PlayMode? playMode,
    bool? isHidden,
  }) =>
      MusicPlayerState(
        playlist: playlist ?? this.playlist,
        currentIndex: currentIndex ?? this.currentIndex,
        isPlaying: isPlaying ?? this.isPlaying,
        position: position ?? this.position,
        duration: identical(duration, _keepDuration)
            ? this.duration
            : duration as Duration?,
        isLoading: isLoading ?? this.isLoading,
        playMode: playMode ?? this.playMode,
        isHidden: isHidden ?? this.isHidden,
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

/// 随机源 provider（测试可 override 用脚本化序列验证 shuffle 真实按随机源分派，
/// 而非被误实现为顺序 (idx+1)%len——后者在仅断言 isNot(prev) 时会漏检）
final musicRandomProvider = Provider<Random>((ref) => Random());

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
  int? _pendingSongId;
  Future<void>? _pendingLoad;

  // 已实际 setUrl 加载成功的曲目 ID（按歌曲身份记忆：索引会随歌单重注入漂移）。
  // setPlaylist 只自动选中不播放，togglePlay 需区分「恢复播放」与「先加载再播放」：
  // just_audio 无源时 play() 仅置 playing 标志不发声，直接 play 会「假播放」。
  int? _loadedSongId;

  // 随机源：通过 provider 注入，测试可 override 用脚本化序列确定性验证 shuffle
  Random get _random => ref.read(musicRandomProvider);

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

  /// 用一次成功扫描的完整结果协调播放器歌单。
  ///
  /// 当前已加载歌曲仍存在时只重定位索引，保留音源、播放状态与进度；已经消失
  /// 时真正停止旧音源，清空播放态，并只选中剩余第一首歌曲而不自动播放。
  /// 成功空列表会隐藏迷你播放器。调用本方法也会使旧的在途切歌请求失效。
  Future<void> reconcilePlaylist(List<MusicSong> songs) async {
    final loadedSongId = _loadedSongId;
    final selectedSongId = state.currentSong?.id;
    final pendingSongId = _pendingSongId;

    _requestSeq++;
    _pendingIndex = null;
    _pendingSongId = null;
    _pendingLoad = null;

    if (loadedSongId != null) {
      final newIndex = songs.indexWhere((song) => song.id == loadedSongId);
      if (newIndex >= 0) {
        state = state.copyWith(
          playlist: songs,
          currentIndex: newIndex,
          isLoading: false,
        );
        return;
      }
    } else if (pendingSongId == null && selectedSongId != null) {
      final newIndex = songs.indexWhere((song) => song.id == selectedSongId);
      if (newIndex >= 0) {
        state = state.copyWith(
          playlist: songs,
          currentIndex: newIndex,
          isLoading: false,
        );
        return;
      }
    }

    if (loadedSongId != null || pendingSongId != null) {
      try {
        await _backend.stop();
      } catch (error) {
        debugPrint('停止已移除音乐失败: ${error.runtimeType}');
      }
    }
    _loadedSongId = null;

    final firstPlayable = songs.indexWhere((song) => song.isPlayable);
    final currentIndex = songs.isEmpty
        ? -1
        : firstPlayable < 0
            ? 0
            : firstPlayable;
    state = MusicPlayerState(
      playlist: songs,
      currentIndex: currentIndex,
      isPlaying: false,
      position: Duration.zero,
      duration: null,
      isLoading: false,
      playMode: state.playMode,
      isHidden: songs.isEmpty,
    );
  }

  /// 注入扫描到的歌单
  ///
  /// - 未选过歌（currentIndex == -1）且歌单非空时自动选中首个可播曲目（只选中不播放），
  ///   避免播放页打开后标题/封面空白占位或指向无 URI 的不可播曲目。
  /// - 已选过歌则按已加载身份 [_loadedSongId] 在新歌单重定位（应对重排/漂移），
  ///   使「暂停 -> 重排 -> 恢复」能续播同一首而不重置进度。
  /// - 歌单缩短致 currentIndex 越界时夹紧到末位，避免 currentSong 返回 null、
  ///   播放键失效（加刷新入口即会暴露）。
  void setPlaylist(List<MusicSong> songs) {
    // 重注入使在途加载的请求作废：递增请求序号，防止旧请求完成时用新歌单盖章旧结果
    _requestSeq++;
    if (state.currentIndex < 0) {
      // 未选过歌：自动选中首个可播曲目（全不可播回退 0，UI 有展示）
      final firstPlayable = songs.indexWhere((s) => s.isPlayable);
      state = state.copyWith(
        playlist: songs,
        currentIndex:
            songs.isEmpty ? -1 : (firstPlayable < 0 ? 0 : firstPlayable),
      );
      return;
    }
    // 已选过歌：尽量保持当前曲
    if (songs.isEmpty) {
      _loadedSongId = null;
      state = state.copyWith(playlist: const [], currentIndex: -1);
      return;
    }
    // 按已加载身份重定位（应对重排/漂移）：找到则跟随，保持加载记忆与进度
    if (_loadedSongId != null) {
      final newIdx = songs.indexWhere((s) => s.id == _loadedSongId);
      if (newIdx >= 0) {
        state = state.copyWith(playlist: songs, currentIndex: newIdx);
        return;
      }
      // 已加载曲不在新歌单：清加载记忆
      _loadedSongId = null;
    }
    // currentIndex 越界（歌单缩短）或无加载记忆：夹紧到末位
    final clamped = state.currentIndex.clamp(0, songs.length - 1);
    state = state.copyWith(playlist: songs, currentIndex: clamped);
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
    _pendingSongId = song.id;
    final future = _doLoadAndPlay(index, song).whenComplete(() {
      if (_pendingIndex == index && _pendingSongId == song.id) {
        _pendingIndex = null;
        _pendingSongId = null;
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
      _loadedSongId = song.id;
    } catch (e) {
      if (seq != _requestSeq) return; // 过期请求的失败忽略，交由最新请求处理
      state = state.copyWith(isLoading: false);
      throw MusicPlaybackException(index, e);
    }
  }

  /// 播放失败后自动跳下一首（跳过坏 URI，最多尝试一圈，避免死循环）
  ///
  /// 候选排除失败曲 [fromIndex]；并排除「已加载的当前曲」--若当前曲源已 setUrl
  /// 在播放/暂停中，重载会 setUrl 清零进度，故跳过。但若当前曲仅被 setPlaylist
  /// 自动选中、从未加载（无源、无进度），则仍可作为候选加载播放（避免回退后无声音）。
  /// 若排除后候选全部失败，则不操作--已加载当前曲源仍在播放，坏曲静默失败有声音延续。
  Future<void> _autoAdvance(int fromIndex) async {
    final len = state.playlist.length;
    if (len <= 1) return; // 没有可跳的下一首
    final currentIdx = state.currentIndex;
    // 当前曲是否已实际加载（源在播放/暂停中，重载会清零进度）
    final currentLoaded = _loadedSongId != null &&
        state.currentSong != null &&
        state.currentSong!.id == _loadedSongId;
    // 候选：从 fromIndex 起的一圈顺序索引，排除失败曲与已加载的当前曲
    final candidates = <int>[];
    for (var i = 1; i < len; i++) {
      final idx = (fromIndex + i) % len;
      if (currentLoaded && idx == currentIdx) continue; // 不重载已加载当前曲（保留进度）
      candidates.add(idx);
    }
    if (state.playMode == PlayMode.shuffle) {
      candidates.shuffle(_random); // 随机模式下失败跳歌也随机
    }
    for (final idx in candidates) {
      final song = state.playlist[idx];
      if (song.isPlayable) {
        try {
          await _loadAndPlay(idx, song);
          return; // 找到可播的下一首
        } on MusicPlaybackException {
          // 这首也失败，继续下一首
        }
      }
    }
    // 所有候选都失败：已加载当前曲源仍在播放，不重载以保留进度
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
    final song = state.currentSong;
    if (song == null || song.id != _loadedSongId) {
      await selectSong(state.currentIndex);
      return;
    }
    await _backend.play();
  }

  /// 隐藏迷你播放条（暂停播放，保留当前曲与进度）
  ///
  /// 用户滑动关闭迷你条时调用：同步置 isHidden（避免 await pause 期间重建闪烁，
  /// 此时 _dragX 已重置而 isHidden 未置会跳回完全不透明居中），再后台 pause。
  /// currentIndex/position/_loadedSongId 保留，下次打开播放页 showPlayer 恢复，
  /// togglePlay 续播不重载（_loadedSongId 仍匹配）。playingStream 监听器会单独
  /// 置 isPlaying=false（copyWith 幂等，无冲突）。
  Future<void> hidePlayer() async {
    state = state.copyWith(isHidden: true, isPlaying: false);
    try {
      await _backend.pause();
    } catch (e) {
      debugPrint('隐藏播放器暂停失败: $e');
    }
  }

  /// 恢复迷你播放条显示（打开播放页时调用）
  void showPlayer() {
    if (state.isHidden) {
      state = state.copyWith(isHidden: false);
    }
  }

  /// 循环切换播放模式（顺序 -> 随机 -> 单曲 -> 顺序）
  void togglePlayMode() {
    state = state.copyWith(
      playMode:
          PlayMode.values[(state.playMode.index + 1) % PlayMode.values.length],
    );
  }

  Future<void> next() async {
    if (state.playlist.isEmpty) return;
    final len = state.playlist.length;
    final idx = state.currentIndex < 0 ? 0 : state.currentIndex;
    switch (state.playMode) {
      case PlayMode.repeatOne:
        // 手动点下一首仍切下一首（网易云行为）；播完自动切歌才重播当前
        await selectSong((idx + 1) % len);
      case PlayMode.shuffle:
        if (len <= 1) {
          await selectSong(0);
          return;
        }
        var r = _random.nextInt(len);
        while (r == idx) {
          r = _random.nextInt(len);
        }
        await selectSong(r);
      case PlayMode.sequence:
        await selectSong((idx + 1) % len);
    }
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

  /// 一首播完自动切下一首；单曲循环模式重播当前；失败已被 selectSong 内部兜底
  Future<void> _onTrackCompleted() async {
    try {
      if (state.playMode == PlayMode.repeatOne && state.currentIndex >= 0) {
        // 单曲循环：seek 回开头并继续播放；seek 失败（文件被删等）回退切下一首
        try {
          await _backend.seek(Duration.zero);
          await _backend.play();
          state = state.copyWith(position: Duration.zero);
          return;
        } catch (e) {
          debugPrint('单曲循环重播失败，切下一首: $e');
        }
      }
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
