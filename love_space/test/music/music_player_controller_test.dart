import 'dart:async';
import 'dart:math';

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

/// 脚本化 Random：按预设序列循环返回 nextInt，用于确定性验证 shuffle 真实按
/// randomProvider 分派（可检出 shuffle 被误实现为顺序 (idx+1)%len 的回归）。
/// 不引入 mockito 依赖，手写最小 Random 实现。
class _ScriptedRandom implements Random {
  _ScriptedRandom(this.sequence);
  final List<int> sequence;
  int _i = 0;
  @override
  int nextInt(int max) {
    final v = sequence[_i % sequence.length];
    _i++;
    return v % max;
  }

  // 未用方法抛异常快速失败：当前 controller 仅消费 nextInt，若未来代码路径分支到
  // nextBool/nextDouble，硬编码常量会让测试在错误值下静默通过
  @override
  bool nextBool() => throw UnimplementedError('_ScriptedRandom 仅支持 nextInt');
  @override
  double nextDouble() =>
      throw UnimplementedError('_ScriptedRandom 仅支持 nextInt');
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

  test('歌单自动选中第一首后，点播放键直接播放第一首', () async {
    final backend = ControllableBackend();
    final container = _containerWith(backend);
    addTearDown(container.dispose);
    addTearDown(backend.dispose);

    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2)]);
    expect(container.read(musicPlayerProvider).currentIndex, 0); // 自动选中第一首
    expect(container.read(musicPlayerProvider).isPlaying, false); // 只选中不播放
    await ctrl.togglePlay();
    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, 0);
    expect(state.isPlaying, true);
    // 先 setUrl 加载再 play，而非无源假播放（只置 playing 标志、不发声）
    expect(backend.playedUrls, ['file:///song1.mp3']);
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

  test('hidePlayer 暂停并隐藏，保留当前曲与进度', () async {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2)]);
    await ctrl.selectSong(0);
    await ctrl.seekTo(const Duration(seconds: 30));
    await ctrl.hidePlayer();
    final state = container.read(musicPlayerProvider);
    expect(state.isHidden, true);
    expect(state.isPlaying, false);
    expect(state.currentIndex, 0); // 保留当前曲
    expect(state.position, const Duration(seconds: 30)); // 保留进度
  });

  test('showPlayer 恢复显示', () async {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1)]);
    await ctrl.selectSong(0);
    await ctrl.hidePlayer();
    ctrl.showPlayer();
    expect(container.read(musicPlayerProvider).isHidden, false);
  });

  test('播放完成自动切下一首', () async {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([
      _song(1, dur: const Duration(milliseconds: 500)),
      _song(2, dur: const Duration(milliseconds: 500))
    ]);
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
    // setPlaylist 已自动选中第一首（只选中不播放），但未成功播放任何曲目
    expect(state.currentIndex, 0);
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
    expect(
        backend.setUrlCalls.where((u) => u == 'file:///song3.mp3').length, 1);

    // 完成 song3 加载
    backend.setUrlCompleters[1].complete();
    await expectLater(clickB, throwsA(isA<MusicPlaybackException>()));
    await clickC;

    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, 2); // 用户点击的 song3 被播放，未被 auto-advance 抢走
    expect(backend.playedUrls, ['file:///song3.mp3']); // 只实际播放一次 song3
    expect(
        backend.setUrlCalls.where((u) => u == 'file:///song3.mp3').length, 1);
  });

  test('setPlaylist 未选过歌时自动选中第一首（不播放）', () {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2)]);
    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, 0);
    expect(state.isPlaying, false); // 只选中不播放
  });

  test('setPlaylist 已选过歌时不覆盖 currentIndex', () async {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2), _song(3)]);
    await ctrl.selectSong(2);
    ctrl.setPlaylist([_song(1), _song(2), _song(3)]); // 重扫注入
    expect(container.read(musicPlayerProvider).currentIndex, 2);
  });

  test('暂停后歌单重注入：同曲保留加载记忆，恢复续播且不重复 setUrl', () async {
    final backend = ControllableBackend();
    final container = _containerWith(backend);
    addTearDown(container.dispose);
    addTearDown(backend.dispose);

    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2), _song(3)]);
    await ctrl.selectSong(2);
    await ctrl.seekTo(const Duration(seconds: 5));
    await ctrl.togglePlay(); // 暂停
    expect(container.read(musicPlayerProvider).isPlaying, false);

    ctrl.setPlaylist(
        [_song(1), _song(2), _song(3), _song(4)]); // 重注入：原曲仍在 index 2
    await ctrl.togglePlay(); // 恢复播放
    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, 2);
    expect(state.isPlaying, true);
    expect(state.position, const Duration(seconds: 5)); // 续播位置，未被重置为 0
    expect(backend.setUrlCalls, ['file:///song3.mp3']); // 恢复未重复 setUrl
  });

  test('setPlaylist 自动选中首个可播曲目（首首无 URI 时跳过）', () {
    final ctrl = container.read(musicPlayerProvider.notifier);
    // uri 传空串（_song 助手的 ?? 默认只对 null 生效），isPlayable 为 false
    ctrl.setPlaylist([_song(1, uri: ''), _song(2)]);
    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, 1);
    expect(state.isPlaying, false); // 只选中不播放
  });

  test('togglePlayMode 三态循环切换', () {
    final ctrl = container.read(musicPlayerProvider.notifier);
    expect(container.read(musicPlayerProvider).playMode, PlayMode.sequence);
    ctrl.togglePlayMode();
    expect(container.read(musicPlayerProvider).playMode, PlayMode.shuffle);
    ctrl.togglePlayMode();
    expect(container.read(musicPlayerProvider).playMode, PlayMode.repeatOne);
    ctrl.togglePlayMode();
    expect(container.read(musicPlayerProvider).playMode, PlayMode.sequence);
  });

  test('next 在顺序模式下循环到下一首', () async {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2), _song(3)]);
    await ctrl.selectSong(2); // 末首
    await ctrl.next();
    expect(container.read(musicPlayerProvider).currentIndex, 0);
  });

  test('next 在单曲模式下仍切下一首（手动切歌不受模式影响）', () async {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2)]);
    await ctrl.selectSong(0);
    ctrl.togglePlayMode(); // sequence -> shuffle
    ctrl.togglePlayMode(); // shuffle -> repeatOne
    await ctrl.next();
    expect(container.read(musicPlayerProvider).currentIndex, 1);
  });

  test('next 在随机模式下取合法且非当前的曲目', () async {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2), _song(3), _song(4)]);
    await ctrl.selectSong(0);
    ctrl.togglePlayMode(); // shuffle
    // 每次 next 不得切回上一首（当前曲），但回到更早的曲目是合法的
    var prev = 0;
    for (var i = 0; i < 10; i++) {
      await ctrl.next();
      final idx = container.read(musicPlayerProvider).currentIndex;
      expect(idx, inInclusiveRange(0, 3));
      expect(idx, isNot(prev)); // 随机不会切回上一首
      prev = idx;
    }
  });

  test('单曲循环播完重播当前（position 归零且继续播放）', () async {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1, dur: const Duration(milliseconds: 500))]);
    backend.setDuration(const Duration(milliseconds: 500));
    await ctrl.selectSong(0);
    ctrl.togglePlayMode();
    ctrl.togglePlayMode(); // repeatOne
    await Future.delayed(const Duration(milliseconds: 800)); // 触发 completed
    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, 0); // 仍当前曲
    expect(state.position, Duration.zero); // 重播归零
  });

  test('shuffle 模式失败跳歌也随机：自动跳到非当前的可播曲目', () async {
    final backend = ControllableBackend();
    backend.breakUrl('file:///song2.mp3'); // 当前曲的下一首不可播
    final container = _containerWith(backend);
    addTearDown(container.dispose);
    addTearDown(backend.dispose);

    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2), _song(3)]);
    ctrl.togglePlayMode(); // shuffle
    await ctrl.selectSong(0); // 正常播 song1

    // 点坏曲目 song2：失败后 auto-advance 在 shuffle 下随机尝试 song1/song3，
    // 找到可播曲目即停（不死循环），不会落在失败的 song2
    await expectLater(
      ctrl.selectSong(1),
      throwsA(isA<MusicPlaybackException>()),
    );
    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, isNot(1)); // 不指向失败曲目
    expect(state.currentIndex, inInclusiveRange(0, 2));
    expect(state.isLoading, false);
    expect(state.isPlaying, true); // 已继续播放
    expect(backend.playedUrls, isNot(contains('file:///song2.mp3')));
  });

  test('shuffle 的 next 按 musicRandomProvider 序列分派（确定性验证，可检测顺序回归）', () async {
    // override musicRandomProvider 用脚本序列：若 shuffle 被误实现为顺序 (idx+1)%len，
    // 断言（期望 2/0/3）会失败（顺序实现会给 1/2/3），从而检出回归
    final backend = ControllableBackend();
    final container = ProviderContainer(overrides: [
      audioBackendProvider.overrideWithValue(backend),
      musicRandomProvider.overrideWithValue(_ScriptedRandom([2, 0, 3])),
    ]);
    addTearDown(container.dispose);
    addTearDown(backend.dispose);

    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2), _song(3), _song(4)]);
    await ctrl.selectSong(0);
    ctrl.togglePlayMode(); // sequence -> shuffle
    await ctrl.next();
    expect(container.read(musicPlayerProvider).currentIndex, 2); // 第一个随机值 2
    await ctrl.next();
    expect(container.read(musicPlayerProvider).currentIndex,
        0); // 第二个随机值 0（!= 当前 2）
    await ctrl.next();
    expect(container.read(musicPlayerProvider).currentIndex,
        3); // 第三个随机值 3（!= 当前 0）
  });

  test('歌单缩短致 currentIndex 越界：夹紧到末位，currentSong 非 null', () async {
    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2), _song(3)]);
    await ctrl.selectSong(2); // 末首 song3
    expect(container.read(musicPlayerProvider).currentIndex, 2);
    // 歌单缩短：移除末首，currentIndex(2) 越界（旧实现会保留越界值致 currentSong=null）
    ctrl.setPlaylist([_song(1), _song(2)]);
    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, 1); // 夹紧到末位
    expect(state.currentSong, isNotNull);
    expect(state.currentSong!.id, 2);
  });

  test('歌单重排：按已加载身份重定位 currentIndex，续播不重载、进度保留', () async {
    final backend = ControllableBackend();
    final container = _containerWith(backend);
    addTearDown(container.dispose);
    addTearDown(backend.dispose);

    final ctrl = container.read(musicPlayerProvider.notifier);
    ctrl.setPlaylist([_song(1), _song(2)]);
    await ctrl.selectSong(0); // song1，index 0
    await ctrl.seekTo(const Duration(seconds: 5));
    await ctrl.togglePlay(); // 暂停
    expect(container.read(musicPlayerProvider).isPlaying, false);

    // 重排：song1 从 index 0 漂移到 index 1（旧实现会保留 currentIndex=0 指向 song2）
    ctrl.setPlaylist([_song(2), _song(1)]);
    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, 1); // 跟随 song1 重定位
    expect(state.currentSong!.id, 1);

    // 续播：_loadedSongId 保留，togglePlay 不重载、进度保留
    await ctrl.togglePlay();
    final state2 = container.read(musicPlayerProvider);
    expect(state2.isPlaying, true);
    expect(state2.position, const Duration(seconds: 5));
    expect(backend.setUrlCalls, ['file:///song1.mp3']); // 恢复未重复 setUrl
  });

  test('auto-advance 不重载已加载当前曲：其它候选全失败时保留当前曲不二次 setUrl', () async {
    final backend = ControllableBackend();
    backend.breakUrl('file:///song2.mp3');
    backend.breakUrl('file:///song3.mp3');
    final container = _containerWith(backend);
    addTearDown(container.dispose);
    addTearDown(backend.dispose);

    final ctrl = container.read(musicPlayerProvider.notifier);
    // song1(0) 已加载播放，song2(1)/song3(2) 均坏
    ctrl.setPlaylist([_song(1), _song(2), _song(3)]);
    await ctrl.selectSong(0); // 正常播 song1
    expect(backend.setUrlCalls, ['file:///song1.mp3']);

    // 点坏曲 song2：auto-advance 候选排除已加载当前曲 song1(0) 后仅剩 song3(2)，
    // song3 也坏 -> 全部候选失败，不重载 song1（保留播放、不二次 setUrl）
    await expectLater(
      ctrl.selectSong(1),
      throwsA(isA<MusicPlaybackException>()),
    );
    final state = container.read(musicPlayerProvider);
    expect(state.currentIndex, 0); // 回到正在播放的 song1
    expect(state.isPlaying, true); // 仍在播放（未被重载打断）
    // song1 只 setUrl 过一次（首次加载），auto-advance 未重载当前曲
    expect(
        backend.setUrlCalls.where((u) => u == 'file:///song1.mp3').length, 1);
    expect(backend.setUrlCalls,
        ['file:///song1.mp3', 'file:///song2.mp3', 'file:///song3.mp3']);
    // song1 的 play() 仅首次加载时调用一次，未被 auto-advance 重新触发（坏曲 setUrl
    // 失败不会走到 play，故 playedUrls 不含 song2/song3）
    expect(backend.playedUrls, ['file:///song1.mp3']);
  });
}
