import 'dart:async';

import 'package:just_audio/just_audio.dart';

import 'audio_backend.dart';

/// just_audio 实现 AudioBackend
///
/// 包装 just_audio.AudioPlayer，将播放器事件桥接到 AudioBackend 流。
/// [init] 必须在注入后调用一次，用于挂接 processingState -> completed 转换。
class JustAudioBackend implements AudioBackend {
  JustAudioBackend() : _player = AudioPlayer();

  final AudioPlayer _player;
  StreamSubscription<Duration>? _posSub;
  StreamSubscription<ProcessingState>? _stateSub;
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

  /// 初始化：将 just_audio 的 positionStream 与 processingStateStream 桥接到本接口
  ///
  /// processingState == completed 时发完成事件。不在此处手动 seek：
  /// 切下一首时 controller.next() -> setUrl 本身会重置到开头，且避免与
  /// controller 的 setUrl 并发竞争（seek 也可能在播放器忙碌时抛异常）。
  void init() {
    _posSub = _player.positionStream.listen(_positionController.add);
    _stateSub = _player.processingStateStream.listen((processingState) {
      if (processingState == ProcessingState.completed) {
        _completedController.add(null);
      }
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _stateSub?.cancel();
    _positionController.close();
    _completedController.close();
    _player.dispose();
  }
}
