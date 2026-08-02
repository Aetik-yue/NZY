import 'dart:typed_data';

/// 音乐歌曲内存模型
///
/// 从 on_audio_query 的 SongModel 映射而来，不落库（每次进入刷新扫描）。
/// [coverBytes] 为 null 时 UI 用 [coverIndex] 取 AppColors.coverGradients 占位。
class MusicSong {
  final int id;
  final String title;
  final String artist;
  final Duration duration;
  final String? uri;
  final int coverIndex;
  final Uint8List? coverBytes;

  const MusicSong({
    required this.id,
    required this.title,
    required this.artist,
    required this.duration,
    required this.uri,
    required this.coverIndex,
    this.coverBytes,
  });

  /// 是否可播放（必须有 URI）
  bool get isPlayable => uri != null && uri!.isNotEmpty;
}
