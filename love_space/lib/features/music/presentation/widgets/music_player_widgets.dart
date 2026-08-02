import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../models/music_song.dart';
import '../../providers/music_player_provider.dart';

/// 大封面（有图用图，无图渐变占位），用于全屏播放页
class MusicBigCover extends StatelessWidget {
  final MusicSong? song;
  const MusicBigCover({super.key, required this.song});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size.width * 0.7;
    if (song == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
        ),
        child: Icon(Icons.music_note_rounded,
            size: size * 0.4, color: AppColors.accentRose),
      );
    }
    final gradient = AppColors.coverGradients[song!.coverIndex];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: song!.coverBytes == null ? gradient : null,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        boxShadow: const [
          BoxShadow(
              color: AppColors.shadowCard,
              blurRadius: 20,
              offset: Offset(0, 8)),
        ],
      ),
      child: song!.coverBytes == null
          ? Icon(Icons.music_note_rounded,
              size: size * 0.4, color: AppColors.textOnPink)
          : ClipRRect(
              borderRadius: BorderRadius.circular(AppColors.radiusCard),
              child: Image.memory(song!.coverBytes!, fit: BoxFit.cover),
            ),
    );
  }
}

/// 进度条行（Slider + 时间标签）
class MusicProgressRow extends ConsumerWidget {
  final MusicPlayerState state;
  const MusicProgressRow({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = state.duration?.inSeconds ?? 0;
    final pos = state.position.inSeconds.clamp(0, total > 0 ? total : 0);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Slider(
            value: total > 0 ? pos / total : 0,
            min: 0,
            max: 1,
            activeColor: AppColors.accentRose,
            // duration 为 0/null 时禁用拖拽
            onChanged: total > 0
                ? (v) => ref.read(musicPlayerProvider.notifier).seekTo(
                    Duration(seconds: (v * total).round()))
                : null,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_fmt(state.position),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textOnPink)),
              Text(_fmt(state.duration ?? Duration.zero),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textOnPink)),
            ],
          ),
        ],
      ),
    );
  }

  String _fmt(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}

/// 播放控制区（上一首 / 播放暂停 / 下一首）
class MusicControls extends ConsumerWidget {
  final MusicPlayerState state;
  const MusicControls({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(musicPlayerProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded,
              size: 48, color: AppColors.textOnPink),
          onPressed: () async {
            try {
              await ctrl.previous();
            } catch (_) {
              if (context.mounted) AppSnackbar.show(context, '切换失败');
            }
          },
        ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: () => ctrl.togglePlay(),
          child: Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(
              gradient: AppColors.pinkButtonGradient,
              shape: BoxShape.circle,
            ),
            child: state.isLoading
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.textOnPink),
                  )
                : Icon(
                    state.isPlaying
                        ? Icons.pause_rounded
                        : Icons.play_arrow_rounded,
                    size: 40,
                    color: AppColors.textOnPink,
                  ),
          ),
        ),
        const SizedBox(width: 24),
        IconButton(
          icon: const Icon(Icons.skip_next_rounded,
              size: 48, color: AppColors.textOnPink),
          onPressed: () async {
            try {
              await ctrl.next();
            } catch (_) {
              if (context.mounted) AppSnackbar.show(context, '切换失败');
            }
          },
        ),
      ],
    );
  }
}

/// 空状态（无本地音乐）
class MusicEmptyState extends StatelessWidget {
  const MusicEmptyState({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.music_off_rounded, size: 64, color: AppColors.textOnPink),
          const SizedBox(height: 16),
          Text('没有找到本地音乐',
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.textOnPink)),
          const SizedBox(height: 8),
          Text('请将音乐文件放入设备后重试',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textOnPink)),
        ],
      ),
    );
  }
}

/// 权限被拒绝状态
class MusicPermissionState extends StatelessWidget {
  final VoidCallback onRetry;
  const MusicPermissionState({super.key, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lock_outline_rounded, size: 64, color: AppColors.textOnPink),
          const SizedBox(height: 16),
          Text('需要音乐权限',
              style: AppTextStyles.titleMedium
                  .copyWith(color: AppColors.textOnPink)),
          const SizedBox(height: 8),
          Text('授权后才能扫描本地音乐',
              style: AppTextStyles.caption
                  .copyWith(color: AppColors.textOnPink)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: onRetry,
            style: FilledButton.styleFrom(backgroundColor: AppColors.bgCard),
            child: Text('重新授权',
                style: AppTextStyles.body
                    .copyWith(color: AppColors.accentRose)),
          ),
        ],
      ),
    );
  }
}
