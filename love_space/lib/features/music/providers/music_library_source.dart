import 'dart:typed_data';

import 'package:on_audio_query/on_audio_query.dart';

/// 设备音乐库的最小平台边界。
///
/// 业务筛选规则不进入此接口；生产环境封装 [OnAudioQuery]，测试可注入 Fake，
/// 避免单元测试依赖 Android MethodChannel。
abstract class MusicLibrarySource {
  Future<bool> requestPermission();

  Future<List<SongModel>> queryByDisplayName(String candidate);

  Future<Uint8List?> queryArtwork(int songId);
}

/// 基于 Android MediaStore 的生产实现。
class OnAudioQueryMusicLibrarySource implements MusicLibrarySource {
  OnAudioQueryMusicLibrarySource({OnAudioQuery? audioQuery})
      : _audioQuery = audioQuery ?? OnAudioQuery();

  final OnAudioQuery _audioQuery;

  @override
  Future<bool> requestPermission() => _audioQuery.permissionsRequest();

  @override
  Future<List<SongModel>> queryByDisplayName(String candidate) async {
    final results = await _audioQuery.queryWithFilters(
      candidate,
      WithFiltersType.AUDIOS,
      args: AudiosArgs.DISPLAY_NAME,
    );
    return decodeSongFilterResults(results);
  }

  @override
  Future<Uint8List?> queryArtwork(int songId) {
    return _audioQuery.queryArtwork(
      songId,
      ArtworkType.AUDIO,
      size: 150,
    );
  }
}

/// 将 `queryWithFilters` 的动态结果转换为歌曲模型。
///
/// `on_audio_query` 的普通 `querySongs` 会直接构造 [SongModel]，但 2.9.0 的
/// `queryWithFilters` MethodChannel 实现返回原始 Map；这里同时兼容两种形态，避免
/// 插件未来调整返回类型时再次让真机歌单静默变空。
List<SongModel> decodeSongFilterResults(List<dynamic> results) {
  return [
    for (final result in results)
      if (result is SongModel)
        result
      else if (result is Map)
        SongModel(Map<dynamic, dynamic>.from(result))
      else
        throw FormatException(
          'Unsupported audio query result: ${result.runtimeType}',
        ),
  ];
}
