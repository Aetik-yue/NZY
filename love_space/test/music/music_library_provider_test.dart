import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:on_audio_query/on_audio_query.dart';
import 'package:love_space/features/music/providers/music_library_provider.dart';
import 'package:love_space/features/music/providers/music_library_source.dart';

SongModel _song({
  required int id,
  required String displayName,
  String? uri,
  String? artist = '严浩睿',
  int? dateAdded,
  int? duration = 60 * 1000,
}) {
  final lastDot = displayName.lastIndexOf('.');
  final stem = lastDot > 0 ? displayName.substring(0, lastDot) : displayName;
  return SongModel({
    '_id': id,
    '_data': '/storage/emulated/0/Music/$displayName',
    '_uri': uri,
    '_display_name': displayName,
    '_display_name_wo_ext': stem,
    '_size': 1024,
    'album': null,
    'album_id': null,
    'artist': artist,
    'artist_id': null,
    'genre': null,
    'genre_id': null,
    'bookmark': null,
    'composer': null,
    'date_added': dateAdded,
    'date_modified': null,
    'duration': duration,
    'title': '媒体标签标题$id',
    'track': null,
    'file_extension': lastDot > 0 ? displayName.substring(lastDot + 1) : '',
    'is_alarm': false,
    'is_audiobook': false,
    'is_music': true,
    'is_notification': false,
    'is_podcast': false,
    'is_ringtone': false,
  });
}

class FakeMusicLibrarySource implements MusicLibrarySource {
  bool permissionGranted = true;
  Object? queryError;
  List<SongModel> candidates = [];
  final Set<int> brokenArtworkIds = {};
  final List<String> calls = [];
  final List<String> queryCandidates = [];
  final List<int> artworkIds = [];

  @override
  Future<bool> requestPermission() async {
    calls.add('permission');
    return permissionGranted;
  }

  @override
  Future<List<SongModel>> queryByDisplayName(String candidate) async {
    calls.add('query');
    queryCandidates.add(candidate);
    final error = queryError;
    if (error != null) throw error;
    return candidates;
  }

  @override
  Future<Uint8List?> queryArtwork(int songId) async {
    calls.add('artwork:$songId');
    artworkIds.add(songId);
    if (brokenArtworkIds.contains(songId)) {
      throw StateError('artwork unavailable');
    }
    return Uint8List.fromList([songId]);
  }
}

ProviderContainer _container(FakeMusicLibrarySource source) {
  return ProviderContainer(
    overrides: [
      musicLibrarySourceProvider.overrideWithValue(source),
    ],
  );
}

void main() {
  test('queryWithFilters 返回的原始 Map 会转换为 SongModel', () {
    final raw = _song(
      id: 7,
      displayName: 'yyzm_真机结果.m4a',
      uri: 'content://audio/7',
    ).getMap;

    final decoded = decodeSongFilterResults([raw]);

    expect(decoded, hasLength(1));
    expect(decoded.single, isA<SongModel>());
    expect(decoded.single.id, 7);
    expect(decoded.single.displayName, 'yyzm_真机结果.m4a');
  });

  test('先请求权限，再以 yyzm 查询显示文件名候选', () async {
    final source = FakeMusicLibrarySource();
    final container = _container(source);
    addTearDown(container.dispose);

    await container.read(musicLibraryProvider.future);

    expect(source.calls, ['permission', 'query']);
    expect(source.queryCandidates, ['yyzm']);
  });

  test('只映射严格前缀且具有 URI 的歌曲，并使用真实文件名标题', () async {
    final source = FakeMusicLibrarySource()
      ..candidates = [
        _song(
          id: 1,
          displayName: 'yyzm_小幸运.m4a',
          uri: 'content://audio/1',
        ),
        _song(
          id: 2,
          displayName: '我的录音_yyzm.mp3',
          uri: 'content://audio/2',
        ),
        _song(id: 3, displayName: 'yyzm_没有地址.wav'),
      ];
    final container = _container(source);
    addTearDown(container.dispose);

    final songs = await container.read(musicLibraryProvider.future);

    expect(songs, hasLength(1));
    expect(songs.single.id, 1);
    expect(songs.single.title, '小幸运');
    expect(songs.single.title, isNot('媒体标签标题1'));
    expect(source.artworkIds, [1]);
  });

  test('未知歌手回退为专属录音', () async {
    final source = FakeMusicLibrarySource()
      ..candidates = [
        _song(
          id: 1,
          displayName: 'yyzm_第一首.m4a',
          uri: 'content://audio/1',
          artist: '  ',
        ),
        _song(
          id: 2,
          displayName: 'YYZM-第二首.mp3',
          uri: 'content://audio/2',
          artist: '<unknown>',
        ),
      ];
    final container = _container(source);
    addTearDown(container.dispose);

    final songs = await container.read(musicLibraryProvider.future);

    expect(songs.map((song) => song.artist), ['专属录音', '专属录音']);
  });

  test('按添加时间倒序，相同时间按媒体 ID 倒序稳定排列', () async {
    final source = FakeMusicLibrarySource()
      ..candidates = [
        _song(
          id: 2,
          displayName: 'yyzm_旧歌.m4a',
          uri: 'content://audio/2',
          dateAdded: 10,
        ),
        _song(
          id: 1,
          displayName: 'yyzm_无时间.mp3',
          uri: 'content://audio/1',
        ),
        _song(
          id: 3,
          displayName: 'yyzm_新歌A.wav',
          uri: 'content://audio/3',
          dateAdded: 20,
        ),
        _song(
          id: 4,
          displayName: 'yyzm_新歌B.flac',
          uri: 'content://audio/4',
          dateAdded: 20,
        ),
      ];
    final container = _container(source);
    addTearDown(container.dispose);

    final songs = await container.read(musicLibraryProvider.future);

    expect(songs.map((song) => song.id), [4, 3, 2, 1]);
    expect(source.artworkIds, [4, 3, 2, 1]);
  });

  test('单首封面失败只让该歌曲使用空封面', () async {
    final source = FakeMusicLibrarySource()
      ..candidates = [
        _song(
          id: 1,
          displayName: 'yyzm_第一首.m4a',
          uri: 'content://audio/1',
        ),
        _song(
          id: 2,
          displayName: 'yyzm_第二首.mp3',
          uri: 'content://audio/2',
        ),
      ]
      ..brokenArtworkIds.add(1);
    final container = _container(source);
    addTearDown(container.dispose);

    final songs = await container.read(musicLibraryProvider.future);

    expect(songs, hasLength(2));
    expect(songs.firstWhere((song) => song.id == 1).coverBytes, isNull);
    expect(songs.firstWhere((song) => song.id == 2).coverBytes, isNotNull);
  });

  test('权限拒绝抛出专用异常且不查询候选', () async {
    final source = FakeMusicLibrarySource()..permissionGranted = false;
    final container = _container(source);
    addTearDown(container.dispose);

    await expectLater(
      container.read(musicLibraryProvider.future),
      throwsA(isA<MusicPermissionDeniedException>()),
    );
    expect(source.calls, ['permission']);
  });

  test('候选查询异常抛出扫描异常，而不是伪装成空歌单', () async {
    final source = FakeMusicLibrarySource()
      ..queryError = StateError('media store unavailable');
    final container = _container(source);
    addTearDown(container.dispose);

    await expectLater(
      container.read(musicLibraryProvider.future),
      throwsA(isA<MusicLibraryScanException>()),
    );
  });

  test('查询成功但没有匹配项时返回空歌单', () async {
    final source = FakeMusicLibrarySource()
      ..candidates = [
        _song(
          id: 1,
          displayName: '普通歌曲.mp3',
          uri: 'content://audio/1',
        ),
      ];
    final container = _container(source);
    addTearDown(container.dispose);

    final songs = await container.read(musicLibraryProvider.future);

    expect(songs, isEmpty);
    expect(source.artworkIds, isEmpty);
  });
}
