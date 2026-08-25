import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/app/theme/app_theme.dart';
import 'package:love_space/features/music/models/music_song.dart';
import 'package:love_space/features/music/presentation/widgets/mini_player_bar.dart';
import 'package:love_space/features/music/providers/audio_backend.dart';
import 'package:love_space/features/music/providers/music_player_provider.dart';

MusicSong _song() => const MusicSong(
      id: 1,
      title: '我们的歌',
      artist: '测试歌手',
      duration: Duration(minutes: 3),
      uri: 'file:///song.mp3',
      coverIndex: 0,
    );

void main() {
  testWidgets('迷你播放器小幅拖动回弹，滑过阈值后关闭', (tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final backend = FakeAudioBackend(autoAdvance: false);
    final container = ProviderContainer(
      overrides: [audioBackendProvider.overrideWithValue(backend)],
    );
    addTearDown(container.dispose);
    addTearDown(backend.dispose);
    container.read(musicPlayerProvider.notifier).setPlaylist([_song()]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const Scaffold(bottomNavigationBar: MiniPlayerBar()),
        ),
      ),
    );

    const surface = Key('mini_player_surface');
    expect(find.byKey(surface), findsOneWidget);

    await tester.drag(find.byKey(surface), const Offset(40, 0));
    await tester.pumpAndSettle();
    expect(container.read(musicPlayerProvider).isHidden, isFalse);
    expect(find.byKey(surface), findsOneWidget);

    await tester.drag(find.byKey(surface), const Offset(160, 0));
    await tester.pumpAndSettle();
    expect(container.read(musicPlayerProvider).isHidden, isTrue);
    expect(container.read(musicPlayerProvider).isPlaying, isFalse);
    expect(find.byKey(surface), findsNothing);
  });
}
