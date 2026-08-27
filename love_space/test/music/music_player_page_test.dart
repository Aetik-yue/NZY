import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/app/theme/app_theme.dart';
import 'package:love_space/data/models/album_photo.dart';
import 'package:love_space/data/providers/data_providers.dart';
import 'package:love_space/features/music/models/music_song.dart';
import 'package:love_space/features/music/presentation/music_player_page.dart';
import 'package:love_space/features/music/presentation/widgets/memory_photo_carousel.dart';
import 'package:love_space/features/music/providers/audio_backend.dart';
import 'package:love_space/features/music/providers/music_library_provider.dart';
import 'package:love_space/features/music/providers/music_memory_photo_provider.dart';
import 'package:love_space/features/music/providers/music_player_provider.dart';

MusicSong _song(int id) => MusicSong(
      id: id,
      title: '我们的歌$id',
      artist: '歌手$id',
      duration: const Duration(minutes: 3),
      uri: 'file:///song$id.mp3',
      coverIndex: id % 6,
    );

AlbumPhoto _photo(String path, int gradientIndex) => AlbumPhoto()
  ..date = DateTime(2026, 8, 24)
  ..category = PhotoCategory.daily
  ..filePath = path
  ..gradientIndex = gradientIndex;

void main() {
  testWidgets('小屏播放器使用 App 相册照片并在播放 12 秒后轮换', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projectPath = Directory.current.path;
    final photoA = '$projectPath/ios/Runner/Assets.xcassets/'
        'LaunchImage.imageset/LaunchImage.png';
    final photoB = '$projectPath/ios/Runner/Assets.xcassets/'
        'LaunchImage.imageset/LaunchImage@2x.png';
    expect(File(photoA).existsSync(), isTrue);
    expect(File(photoB).existsSync(), isTrue);

    final backend = FakeAudioBackend();
    final container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        musicLibraryProvider.overrideWith((ref) async => [_song(1), _song(2)]),
        allPhotosTypedProvider.overrideWith(
          (ref) => Stream.value([
            _photo(photoA, 0),
            _photo(photoB, 1),
          ]),
        ),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MusicPlayerPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('我们的歌1'), findsOneWidget);
    expect(find.byType(MemoryPhotoCarousel), findsOneWidget);
    expect(tester.takeException(), isNull, reason: '360×640 不应出现布局溢出');

    final firstPhoto = container.read(musicMemoryPhotoPathProvider);
    expect(firstPhoto, anyOf(photoA, photoB));

    await tester.tap(find.byIcon(Icons.play_arrow_rounded));
    await tester.pump();
    await tester.pump(const Duration(seconds: 12));
    await tester.pump(const Duration(milliseconds: 900));

    final secondPhoto = container.read(musicMemoryPhotoPathProvider);
    expect(secondPhoto, anyOf(photoA, photoB));
    expect(secondPhoto, isNot(firstPhoto));
    expect(tester.takeException(), isNull);

    // 先暂停测试音频后端，再卸载页面，确认轮播 Timer 被释放。
    await container.read(musicPlayerProvider.notifier).togglePlay();
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('空状态说明 yyzm 命名规则，重新识别会刷新音乐库', (tester) async {
    var scanCalls = 0;
    final backend = FakeAudioBackend();
    final container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        musicLibraryProvider.overrideWith((ref) async {
          scanCalls++;
          return [];
        }),
        allPhotosTypedProvider.overrideWith((ref) => Stream.value([])),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MusicPlayerPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有找到我们的歌'), findsOneWidget);
    expect(find.textContaining('yyzm_小幸运.m4a'), findsOneWidget);
    expect(find.text('重新识别'), findsOneWidget);
    expect(scanCalls, 1);

    await tester.tap(find.text('重新识别'));
    await tester.pumpAndSettle();
    expect(scanCalls, 2);
  });

  testWidgets('权限拒绝显示专属录音权限说明', (tester) async {
    final backend = FakeAudioBackend();
    final container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        musicLibraryProvider.overrideWith((ref) async {
          throw MusicPermissionDeniedException();
        }),
        allPhotosTypedProvider.overrideWith((ref) => Stream.value([])),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MusicPlayerPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('需要音乐和音频权限'), findsOneWidget);
    expect(find.textContaining('其他歌曲不会加入“我们的歌”'), findsOneWidget);
    expect(find.text('允许访问'), findsOneWidget);
  });

  testWidgets('扫描异常显示识别失败而不是空歌单', (tester) async {
    final backend = FakeAudioBackend();
    final container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        musicLibraryProvider.overrideWith((ref) async {
          throw MusicLibraryScanException(StateError('unavailable'));
        }),
        allPhotosTypedProvider.overrideWith((ref) => Stream.value([])),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MusicPlayerPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('识别歌曲失败，请重试'), findsOneWidget);
    expect(find.text('还没有找到我们的歌'), findsNothing);
    expect(find.text('重新识别'), findsOneWidget);
  });

  testWidgets('成功空扫描清除旧歌单并隐藏当前歌曲', (tester) async {
    final backend = FakeAudioBackend();
    final container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        musicLibraryProvider.overrideWith((ref) async => []),
        allPhotosTypedProvider.overrideWith((ref) => Stream.value([])),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(backend.dispose);
    container.read(musicPlayerProvider.notifier).setPlaylist([_song(9)]);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MusicPlayerPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final state = container.read(musicPlayerProvider);
    expect(state.playlist, isEmpty);
    expect(state.currentIndex, -1);
    expect(state.isHidden, isTrue);
  });

  testWidgets('我们的歌入口打开专属播放列表标题', (tester) async {
    final backend = FakeAudioBackend();
    final container = ProviderContainer(
      overrides: [
        audioBackendProvider.overrideWithValue(backend),
        musicLibraryProvider.overrideWith((ref) async => [_song(1), _song(2)]),
        allPhotosTypedProvider.overrideWith((ref) => Stream.value([])),
      ],
    );
    addTearDown(container.dispose);
    addTearDown(backend.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MusicPlayerPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('我们的歌'));
    await tester.pumpAndSettle();

    expect(find.text('我们的歌（2 首）'), findsOneWidget);
  });
}
