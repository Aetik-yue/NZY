import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/music_song.dart';
import 'audio_backend.dart';
import 'music_library_provider.dart';

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

  @override
  MusicPlayerState build() {
    ref.onDispose(_dispose);
    // 监听扫描结果，自动注入歌单（仅在歌单为空时注入，避免覆盖用户手动选择）
    ref.listen<AsyncValue<List<MusicSong>>>(musicLibraryProvider, (_, async) {
      final songs = async.valueOrNull;
      if (songs != null && songs.isNotEmpty && state.playlist.isEmpty) {
        setPlaylist(songs);
      }
    });
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
    state = state.copyWith(
        currentIndex: index, isLoading: true, position: Duration.zero);
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
