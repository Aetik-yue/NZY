import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../music/presentation/music_player_page.dart';
import '../../../music/providers/music_player_provider.dart';

/// 相伴天数、照片、愿望和未完成待办的摘要。
class ProfileStatsRow extends ConsumerWidget {
  const ProfileStatsRow({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(daysTogetherProvider);
    final photoCount = ref.watch(photoCountProvider);
    final wishStats = ref.watch(wishStatsProvider);
    final memoStats = ref.watch(memoStatsProvider);
    final activeMemos = memoStats.total - memoStats.done;
    final stats = <(String, String, Color)>[
      ('$days', '相伴天数', AppColors.textPrimary),
      ('$photoCount', '相册照片', AppColors.accentRose),
      ('${wishStats.total}', '愿望', AppColors.accentRose),
      ('$activeMemos', '待完成', AppColors.accentRose),
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 16,
            offset: Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: stats
            .map((stat) => Expanded(
                  child: Column(
                    children: [
                      Text(stat.$1,
                          style: AppTextStyles.statNumber
                              .copyWith(color: stat.$3)),
                      const SizedBox(height: 4),
                      Text(stat.$2, style: AppTextStyles.label),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

/// 音乐入口；仅消费播放器状态，避免进入「我的」时触发媒体权限。
class ProfileMusicCard extends ConsumerWidget {
  const ProfileMusicCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final playerState = ref.watch(musicPlayerProvider);
    final count = playerState.playlist.length;
    final current = playerState.currentSong;
    final subtitle = count == 0
        ? '打开音乐库，开始播放'
        : playerState.isLoading && current != null
            ? '正在准备「${current.title}」'
            : playerState.isPlaying && current != null
                ? '正在播放「${current.title}」'
                : current != null
                    ? '$count 首 · 「${current.title}」'
                    : '$count 首 · 点击播放';

    return Semantics(
      button: true,
      label: '打开回忆唱片',
      child: Material(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        child: InkWell(
          onTap: () => MusicPlayerPage.show(context),
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
          child: Ink(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: AppColors.musicCardGradient,
              borderRadius: BorderRadius.circular(AppColors.radiusCard),
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: AppColors.pinkButtonGradient,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  child: const Icon(Icons.photo_album_rounded,
                      color: AppColors.textOnPink, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('回忆唱片', style: AppTextStyles.titleXs),
                      const SizedBox(height: 4),
                      Text(subtitle,
                          style: AppTextStyles.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: const BoxDecoration(
                    color: AppColors.bgCard,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.play_arrow_rounded,
                      color: AppColors.accentRose, size: 24),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
