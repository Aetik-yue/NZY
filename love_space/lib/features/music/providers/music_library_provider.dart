import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../app/theme/app_colors.dart';
import '../models/music_song.dart';

/// 权限被拒绝
class MusicPermissionDeniedException implements Exception {}

/// 本地音乐库扫描 provider
///
/// 请求 Android 音频权限 -> 查询全部音乐 -> 映射为 MusicSong 列表。
/// 失败（权限拒绝/无歌）返回空列表或抛 [MusicPermissionDeniedException]。
final musicLibraryProvider =
    FutureProvider<List<MusicSong>>((ref) async {
  final audioQuery = OnAudioQuery();
  final hasPermission = await audioQuery.permissionsRequest();
  if (!hasPermission) throw MusicPermissionDeniedException();

  final songs = await audioQuery.querySongs(
    sortType: SongSortType.DATE_ADDED,
    orderType: OrderType.DESC_OR_GREATER,
  );

  final result = <MusicSong>[];
  for (var i = 0; i < songs.length; i++) {
    final s = songs[i];
    final uri = s.uri;
    if (uri == null || uri.isEmpty) continue; // 无 URI 不可播放，过滤

    Uint8List? cover;
    try {
      cover = await audioQuery.queryArtwork(s.id, ArtworkType.AUDIO,
          size: 150);
    } catch (_) {
      // 封面取失败用渐变占位，不阻断扫描
    }

    result.add(MusicSong(
      id: s.id,
      title: s.title.trim().isEmpty ? '未知歌曲' : s.title,
      artist: s.artist?.trim().isEmpty ?? true ? '未知艺术家' : s.artist!,
      duration: Duration(milliseconds: s.duration ?? 0),
      uri: uri,
      coverIndex: s.id % AppColors.coverGradients.length,
      coverBytes: cover,
    ));
  }
  return result;
});
