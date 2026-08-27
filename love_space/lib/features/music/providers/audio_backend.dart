import 'dart:async';

/// 音频播放后端抽象接口
///
/// Controller 依赖此抽象而非具体播放器，便于测试与未来替换引擎。
abstract class AudioBackend {
  Future<void> setUrl(String url);
  Future<void> play();
  Future<void> pause();
  Future<void> stop();
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
  Timer? _timer;

  @override
  Future<void> setUrl(String url) async {
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
    _playing.add(false);
    _timer?.cancel();
  }

  @override
  Future<void> stop() async {
    _timer?.cancel();
    _pos = Duration.zero;
    _playing.add(false);
    _position.add(_pos);
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
