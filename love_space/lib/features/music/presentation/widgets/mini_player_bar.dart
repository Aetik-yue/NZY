import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../models/music_song.dart';
import '../../providers/music_player_provider.dart';
import '../music_player_page.dart';

/// 底部常驻迷你播放条
///
/// 有当前曲目时显示；点击打开全屏播放页，播放/暂停按钮独立响应。
class MiniPlayerBar extends ConsumerWidget {
  const MiniPlayerBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerProvider);
    final song = state.currentSong;
    if (song == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => MusicPlayerPage.show(context),
      behavior: HitTestBehavior.opaque,
      child: Container(
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowCard,
              blurRadius: 12,
              offset: Offset(0, 2),
              spreadRadius: -2,
            ),
          ],
        ),
        child: Row(
          children: [
            _Cover(song: song, size: 36),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(song.title,
                      style: AppTextStyles.body,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                  Text(song.artist,
                      style: AppTextStyles.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            GestureDetector(
              onTap: () =>
                  ref.read(musicPlayerProvider.notifier).togglePlay(),
              child: Container(
                width: 36,
                height: 36,
                decoration: const BoxDecoration(
                  gradient: AppColors.pinkButtonGradient,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  state.isPlaying
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  color: AppColors.textOnPink,
                  size: 22,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 封面（有图用图，无图渐变占位）
class _Cover extends StatelessWidget {
  const _Cover({required this.song, required this.size});
  final MusicSong song;
  final double size;

  @override
  Widget build(BuildContext context) {
    final gradient = AppColors.coverGradients[song.coverIndex];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: song.coverBytes == null ? gradient : null,
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: song.coverBytes == null
          ? Icon(Icons.music_note_rounded,
              color: AppColors.textOnPink, size: size * 0.5)
          : ClipRRect(
              borderRadius: BorderRadius.circular(size * 0.3),
              child: Image.memory(song.coverBytes!, fit: BoxFit.cover),
            ),
    );
  }
}
