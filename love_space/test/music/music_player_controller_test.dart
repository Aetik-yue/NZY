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
