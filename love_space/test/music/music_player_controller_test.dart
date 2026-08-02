import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/features/music/models/music_song.dart';
import 'package:love_space/features/music/providers/audio_backend.dart';
import 'package:love_space/features/music/providers/music_player_provider.dart';

MusicSong _song(int id, {String? uri, Duration? dur}) => MusicSong(
      id: id,
      title: '歌$id',
      artist: '歌手$id',
      duration: dur ?? const Duration(seconds: 10),
      uri: uri ?? 'file:///song$id.mp3',
      coverIndex: id % 6,
    );

/// 可控测试后端
///
/// - [breakUrl]：标记某 URI 的 setUrl 必定失败（模拟 URI 失效）
/// - [manualSetUrl]：为 true 时所有 setUrl 挂起由测试手动 complete（坏 URI 也走
///   completer，便于模拟"慢失败"），用于构造 auto-advance 与用户点击的并发窗口
/// - [setUrlCalls]：按顺序记录所有 setUrl 的 URI，用于断言不重复 setUrl
/// - [playedUrls]：记录实际成功 play 过的 URI（按顺序），用于验证最终播放对象
class ControllableBackend extends FakeAudioBackend {
  ControllableBackend({this.manualSetUrl = false});

  final bool manualSetUrl;
  final Set<String> _broken = {};
  final List<Completer<void>> setUrlCompleters = [];
  final List<String> setUrlCalls = [];
  final List<String> playedUrls = [];
  String? _activeUrl;

  /// 标记某 URI 播放必定失败
  void breakUrl(String url) => _broken.add(url);

  @override
  Future<void> setUrl(String url) {
    setUrlCalls.add(url);
    if (_broken.contains(url)) {
      if (manualSetUrl) {
        // 手动模式下坏 URI 也挂起，由测试决定何时失败（模拟慢失败）
        final completer = Completer<void>();
        setUrlCompleters.add(completer);
        return completer.future;
      }
      return Future<void>.error(Exception('bad uri: $url'));
    }
    _activeUrl = url;
    final completer = Completer<void>();
    setUrlCompleters.add(completer);
    if (!manualSetUrl) completer.complete();
    return completer.future;
  }

  @override
  Future<void> play() async {
    if (_activeUrl != null) playedUrls.add(_activeUrl!);
    await super.play();
  }
}

ProviderContainer _containerWith(ControllableBackend backend) {
  return ProviderContainer(overrides: [
    audioBackendProvider.overrideWithValue(backend),
  ]);
}

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

  test('歌单非空但未选歌（currentIndex=-1）时 togglePlay 直接播第一首', () async {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2)]);
    expect(container.read(musicPlayerProvider).currentIndex, -1);
    expect(container.read(musicPlayerProvider).isPlaying, false);
    await ctrl.togglePlay();
    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, 0); // selectSong(0) 生效
    expect(state.isPlaying, true);
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

  test('快速连点切歌：旧 setUrl 后完成不覆盖最新请求，最终播放最后一次请求', () async {
    final backend = ControllableBackend(manualSetUrl: true);
    final container = _containerWith(backend);
    addTearDown(container.dispose);
    addTearDown(backend.dispose);

    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2)]);

    final first = ctrl.selectSong(0); // 挂起在 setUrl(song1)
    final second = ctrl.selectSong(1); // 挂起在 setUrl(song2)
    expect(backend.setUrlCompleters.length, 2);

    // 最新请求 (song2) 先完成
    backend.setUrlCompleters[1].complete();
    await second;
    // 旧请求 (song1) 后完成：应被丢弃，不得 play
    backend.setUrlCompleters[0].complete();
    await first;

    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, 1); // UI 显示最后一次请求的歌
    expect(backend.playedUrls, ['file:///song2.mp3']); // 实际播放的也是它
    expect(state.isLoading, false);
  });

  test('坏 URI：抛 MusicPlaybackException 且自动跳下一首，失败曲目不成为当前曲', () async {
    final backend = ControllableBackend();
    backend.breakUrl('file:///song2.mp3'); // song2 不可播
    final container = _containerWith(backend);
    addTearDown(container.dispose);
    addTearDown(backend.dispose);

    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2), _song(3)]);

    await ctrl.selectSong(0); // 正常播 song1
    expect(container.read(musicPlayerProvider).currentIndex, 0);

    // 点坏曲目：抛 MusicPlaybackException（供 UI 提示「该曲目无法播放」），
    // 且自动跳到下一首 song3
    await expectLater(
      ctrl.selectSong(1),
      throwsA(isA<MusicPlaybackException>()),
    );
    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, 2); // 已自动切到 song3
    expect(state.isLoading, false);
    expect(backend.playedUrls, ['file:///song1.mp3', 'file:///song3.mp3']);
  });

  test('切歌失败：currentIndex 回滚，不指向失败曲目', () async {
    final backend = ControllableBackend();
    backend.breakUrl('file:///song2.mp3'); // song2 不可播
    final container = _containerWith(backend);
    addTearDown(container.dispose);
    addTearDown(backend.dispose);

    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2)]); // song1 好，song2 坏

    // 从未选中，直接点坏曲目：失败后回退到可播的 song1，而非失败的第 1 首
    await expectLater(
      ctrl.selectSong(1),
      throwsA(isA<MusicPlaybackException>()),
    );
    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, 0);
    expect(state.isPlaying, true);
  });

  test('全部坏 URI：不崩溃、不死循环，最终停止（isLoading=false）', () async {
    final backend = ControllableBackend();
    backend.breakUrl('file:///song1.mp3');
    backend.breakUrl('file:///song2.mp3');
    backend.breakUrl('file:///song3.mp3');
    final container = _containerWith(backend);
    addTearDown(container.dispose);
    addTearDown(backend.dispose);

    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2), _song(3)]);

    await expectLater(
      ctrl.selectSong(0),
      throwsA(isA<MusicPlaybackException>()),
    );
    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, -1); // 未成功选中任何曲目
    expect(state.isLoading, false);
    expect(state.isPlaying, false);
    expect(backend.playedUrls, isEmpty); // 全程未成功 play
  });

  test('auto-advance 与用户快速点同一曲目：合并加载、不重复 setUrl、用户点击胜出', () async {
    final backend = ControllableBackend(manualSetUrl: true);
    backend.breakUrl('file:///song2.mp3'); // song2 慢失败
    final container = _containerWith(backend);
    addTearDown(container.dispose);
    addTearDown(backend.dispose);

    final ctrl = container.read(musicPlayerProvider.notifier);
    // song1(0) 正常、song2(1) 坏、song3(2) 正常
    ctrl.setPlaylist([_song(1), _song(2), _song(3)]);

    // 用户点坏曲目 song2：setUrl 挂起（模拟慢失败）
    final clickB = ctrl.selectSong(1);
    expect(backend.setUrlCalls, ['file:///song2.mp3']);

    // song2 失败 -> 触发 auto-advance -> 开始加载 song3
    backend.setUrlCompleters[0].completeError(Exception('bad uri'));
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(backend.setUrlCalls, ['file:///song2.mp3', 'file:///song3.mp3']);

    // 用户在 auto-advance 加载 song3 的窗口内点 song3：应合并（复用同一 Future），
    // 不重复 setUrl
    final clickC = ctrl.selectSong(2);
    expect(backend.setUrlCalls.where((u) => u == 'file:///song3.mp3').length, 1);

    // 完成 song3 加载
    backend.setUrlCompleters[1].complete();
    await expectLater(clickB, throwsA(isA<MusicPlaybackException>()));
    await clickC;

    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, 2); // 用户点击的 song3 被播放，未被 auto-advance 抢走
    expect(backend.playedUrls, ['file:///song3.mp3']); // 只实际播放一次 song3
    expect(backend.setUrlCalls.where((u) => u == 'file:///song3.mp3').length, 1);
  });
}
