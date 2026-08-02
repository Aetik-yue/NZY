import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:on_audio_query/on_audio_query.dart';

import '../../../app/theme/app_colors.dart';
import '../models/music_song.dart';

/// 权限被拒绝
class MusicPermissionDeniedException implements Exception {}

/// 封面拉取并发批次大小
///
/// queryArtwork 在循环内串行很慢（on_audio_query 官方提示），分批 Future.wait
/// 并发加速；批大小取 8 避免一次全并发触发平台/内存压力。
const int _coverBatchSize = 8;

/// 本地音乐库扫描 provider
///
/// 请求 Android 音频权限 -> 查询全部音乐 -> 分批并发拉取封面 -> 映射为 MusicSong 列表。
/// 权限被拒绝抛 [MusicPermissionDeniedException]（播放页据此显示「重新授权」按钮）。
///
/// 异常兜底仅覆盖**平台调用段**（permissionsRequest / querySongs / 封面拉取）：
/// 其它任何平台异常捕获后返回空列表并记录日志，让 UI 走带「重新扫描」按钮的空态，
/// 而非卡死在无重试入口的 error 死胡同。纯 Dart 的 MusicSong 映射段在 try 外，
/// 若映射层有编程错误应正常抛出，避免被静默吞成空库掩盖。
final musicLibraryProvider =
    FutureProvider<List<MusicSong>>((ref) async {
  final audioQuery = OnAudioQuery();

  // 平台调用段（权限 / querySongs / 封面拉取），整体兜底
  final List<(SongModel, Uint8List?)> scanned;
  try {
    final hasPermission = await audioQuery.permissionsRequest();
    if (!hasPermission) throw MusicPermissionDeniedException();

    final songs = await audioQuery.querySongs(
      sortType: SongSortType.DATE_ADDED,
      orderType: OrderType.DESC_OR_GREATER,
    );

    // 无 URI 的曲目不可播放，提前过滤，避免后续映射成坏数据
    final playable = <SongModel>[];
    for (final s in songs) {
      final uri = s.uri;
      if (uri == null || uri.isEmpty) continue;
      playable.add(s);
    }

    // 分批并发拉取封面：每批 [_coverBatchSize] 首 Future.wait，批间串行；
    // 结果按 Future.wait 传入顺序对齐（非完成顺序），曲目顺序保持稳定。
    scanned = <(SongModel, Uint8List?)>[];
    for (var i = 0; i < playable.length; i += _coverBatchSize) {
      final end = i + _coverBatchSize < playable.length
          ? i + _coverBatchSize
          : playable.length;
      final batch = playable.sublist(i, end);

      final covers = await Future.wait<Uint8List?>(batch.map((s) async {
        try {
          return await audioQuery.queryArtwork(s.id, ArtworkType.AUDIO,
              size: 150);
        } catch (_) {
          return null; // 单首封面取失败用渐变占位，不阻断扫描
        }
      }));

      for (var j = 0; j < batch.length; j++) {
        scanned.add((batch[j], covers[j]));
      }
    }
  } on MusicPermissionDeniedException {
    // 权限拒绝必须向上抛，播放页据此显示「重新授权」按钮，不能被兜底吞掉
    rethrow;
  } catch (e) {
    // 其余任何平台异常都兜底：返回空列表让 UI 走带「重新扫描」按钮的空态，
    // 而非卡死在无重试的「加载失败」；带上异常类型便于排查
    debugPrint('Music library scan failed: ${e.runtimeType}: $e');
    return [];
  }

  // 纯 Dart 映射段（不在 try/catch 内）：编程错误应正常传播，便于定位
  return [
    for (final (s, cover) in scanned)
      MusicSong(
        id: s.id,
        title: s.title.trim().isEmpty ? '未知歌曲' : s.title,
        artist: s.artist?.trim().isEmpty ?? true ? '未知艺术家' : s.artist!,
        duration: Duration(milliseconds: s.duration ?? 0),
        uri: s.uri!,
        coverIndex: s.id % AppColors.coverGradients.length,
        coverBytes: cover,
      ),
  ];
});
