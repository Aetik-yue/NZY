import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../models/music_song.dart';
import '../../providers/music_player_provider.dart';

/// 歌曲列表弹层
///
/// 展示扫描到的全部歌曲，当前曲目高亮 + 播放中音符；点击切歌。
class PlaylistSheet extends ConsumerWidget {
  const PlaylistSheet({super.key, this.scrollController});

  final ScrollController? scrollController;

  /// 弹出歌曲列表（可拖拽高度）
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppColors.radiusCard)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => PlaylistSheet(
          scrollController: scrollController,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(musicPlayerProvider);
    final songs = state.playlist;
    return Column(
      children: [
        // 顶部拖拽指示条
        Container(
          margin: const EdgeInsets.only(top: 12),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.textTertiary,
            borderRadius: BorderRadius.circular(AppColors.radiusXs),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child:
              Text('播放列表（${songs.length} 首）', style: AppTextStyles.titleMedium),
        ),
        Expanded(
          child: songs.isEmpty
              ? Center(child: Text('没有找到本地音乐', style: AppTextStyles.caption))
              : ListView.builder(
                  controller: scrollController,
                  itemCount: songs.length,
                  itemBuilder: (_, i) {
                    final s = songs[i];
                    final isCurrent = i == state.currentIndex;
                    return ListTile(
                      minLeadingWidth: 48,
                      leading: _PlaylistCover(
                        song: s,
                        isCurrent: isCurrent,
                        isPlaying: state.isPlaying,
                      ),
                      title: Text(
                        s.title,
                        style: isCurrent
                            ? AppTextStyles.body
                                .copyWith(color: AppColors.accentRose)
                            : AppTextStyles.body,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        '${s.artist} · ${_fmt(s.duration)}',
                        style: AppTextStyles.caption,
                        maxLines: 1,
                      ),
                      onTap: () async {
                        try {
                          await ref
                              .read(musicPlayerProvider.notifier)
                              .selectSong(i);
                        } on MusicPlaybackException {
                          // 播放失败已自动跳下一首，仅提示当前曲目无法播放
                          if (context.mounted) {
                            AppSnackbar.show(context,
                                MusicPlaybackException.feedbackMessage);
                          }
                        } catch (_) {
                          if (context.mounted) {
                            AppSnackbar.show(context, '播放失败');
                          }
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// 播放列表保留歌曲自身封面，避免回忆照片削弱歌曲辨识度。
class _PlaylistCover extends StatelessWidget {
  const _PlaylistCover({
    required this.song,
    required this.isCurrent,
    required this.isPlaying,
  });

  final MusicSong song;
  final bool isCurrent;
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: 48,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (song.coverBytes != null)
              Image.memory(song.coverBytes!, fit: BoxFit.cover)
            else
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: AppColors.coverGradients[song.coverIndex],
                ),
                child: const Icon(
                  Icons.music_note_rounded,
                  color: AppColors.textOnPink,
                  size: 22,
                ),
              ),
            if (isCurrent)
              ColoredBox(color: AppColors.accentRose.withValues(alpha: 0.72)),
            if (isCurrent)
              Icon(
                isPlaying ? Icons.equalizer_rounded : Icons.music_note_rounded,
                color: AppColors.textOnPink,
                size: 24,
              ),
          ],
        ),
      ),
    );
  }
}
