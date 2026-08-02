import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../providers/music_player_provider.dart';

/// 歌曲列表弹层
///
/// 展示扫描到的全部歌曲，当前曲目高亮 + 播放中音符；点击切歌。
class PlaylistSheet extends ConsumerWidget {
  const PlaylistSheet({super.key});

  /// 弹出歌曲列表（可拖拽高度）
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bgPrimary,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.4,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) =>
            const PlaylistSheet(),
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
          margin: const EdgeInsets.only(top: 10),
          width: 40,
          height: 4,
          decoration: BoxDecoration(
            color: AppColors.textTertiary,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text('播放列表（${songs.length} 首）',
              style: AppTextStyles.titleMedium),
        ),
        Expanded(
          child: songs.isEmpty
              ? Center(
                  child: Text('没有找到本地音乐', style: AppTextStyles.caption))
              : ListView.builder(
                  itemCount: songs.length,
                  itemBuilder: (_, i) {
                    final s = songs[i];
                    final isCurrent = i == state.currentIndex;
                    return ListTile(
                      leading: _leading(isCurrent, state.isPlaying),
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
                      onTap: () => ref
                          .read(musicPlayerProvider.notifier)
                          .selectSong(i),
                    );
                  },
                ),
        ),
      ],
    );
  }

  /// 当前曲目高亮图标：播放中用均衡器，否则音符
  Widget _leading(bool isCurrent, bool isPlaying) {
    if (!isCurrent) {
      return const Icon(Icons.music_note_rounded,
          color: AppColors.textTertiary, size: 24);
    }
    return Icon(
      isPlaying ? Icons.equalizer_rounded : Icons.music_note_rounded,
      color: AppColors.accentRose,
      size: 24,
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
