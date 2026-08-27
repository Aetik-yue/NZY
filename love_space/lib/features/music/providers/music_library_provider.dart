import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../app/theme/app_colors.dart';
import '../models/music_filename_policy.dart';
import '../models/music_song.dart';
import 'music_library_source.dart';

/// 权限被拒绝。
class MusicPermissionDeniedException implements Exception {}

/// MediaStore 查询或结果处理失败。
///
/// [toString] 只暴露异常类型，不输出可能包含本地路径或 URI 的错误详情。
class MusicLibraryScanException implements Exception {
  const MusicLibraryScanException(this.cause);

  final Object cause;

  @override
  String toString() => 'MusicLibraryScanException(${cause.runtimeType})';
}

/// 封面拉取并发批次大小。
const int _coverBatchSize = 8;

/// 平台音乐库来源，测试可覆盖为 Fake。
final musicLibrarySourceProvider = Provider<MusicLibrarySource>((ref) {
  return OnAudioQueryMusicLibrarySource();
});

/// 专属录音扫描 Provider。
///
/// 页面关闭后自动释放，保证下次打开音乐页重新查询。MediaStore 先按显示文件名
/// 包含 `yyzm` 预筛选，再由 [MusicFilenamePolicy] 执行严格的开头匹配。
final musicLibraryProvider =
    FutureProvider.autoDispose<List<MusicSong>>((ref) async {
  final source = ref.read(musicLibrarySourceProvider);

  try {
    final hasPermission = await source.requestPermission();
    if (!hasPermission) throw MusicPermissionDeniedException();

    final candidates = await source.queryByDisplayName(
      MusicFilenamePolicy.prefix,
    );

    final matched = <SongModel>[];
    for (final song in candidates) {
      final uri = song.uri;
      if (uri == null || uri.trim().isEmpty) continue;
      if (!MusicFilenamePolicy.matches(song.displayName)) continue;
      matched.add(song);
    }

    matched.sort((a, b) {
      final byDate = (b.dateAdded ?? -1).compareTo(a.dateAdded ?? -1);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });

    final scanned = <(SongModel, Uint8List?)>[];
    for (var i = 0; i < matched.length; i += _coverBatchSize) {
      final end = (i + _coverBatchSize).clamp(0, matched.length);
      final batch = matched.sublist(i, end);
      final covers = await Future.wait<Uint8List?>(
        batch.map((song) async {
          try {
            return await source.queryArtwork(song.id);
          } catch (_) {
            return null;
          }
        }),
      );
      for (var j = 0; j < batch.length; j++) {
        scanned.add((batch[j], covers[j]));
      }
    }

    return [
      for (final (song, cover) in scanned)
        MusicSong(
          id: song.id,
          title: MusicFilenamePolicy.displayTitle(song.displayName),
          artist: _displayArtist(song.artist),
          duration: Duration(milliseconds: song.duration ?? 0),
          uri: song.uri!,
          coverIndex: song.id % AppColors.coverGradients.length,
          coverBytes: cover,
        ),
    ];
  } on MusicPermissionDeniedException {
    rethrow;
  } on MusicLibraryScanException {
    rethrow;
  } catch (error) {
    debugPrint('Music library scan failed: ${error.runtimeType}');
    throw MusicLibraryScanException(error);
  }
});

String _displayArtist(String? rawArtist) {
  final artist = rawArtist?.trim() ?? '';
  final normalized = artist.toLowerCase();
  if (artist.isEmpty || normalized == '<unknown>' || normalized == 'unknown') {
    return '专属录音';
  }
  return artist;
}
