import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../models/music_song.dart';
import '../../providers/music_player_provider.dart';
import 'playlist_sheet.dart';

/// 控制区切歌图标尺寸
const _kControlIconSize = 48.0;

/// 主播放按钮直径
const _kPlayButtonSize = 72.0;

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

/// 播放控制区（模式 / 上一首 / 播放暂停 / 下一首 / 列表）
class MusicControls extends ConsumerWidget {
  final MusicPlayerState state;
  const MusicControls({super.key, required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(musicPlayerProvider.notifier);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // 播放模式切换
        IconButton(
          icon: Icon(
            switch (state.playMode) {
              PlayMode.sequence => Icons.repeat_rounded,
              PlayMode.shuffle => Icons.shuffle_rounded,
              PlayMode.repeatOne => Icons.repeat_one_rounded,
            },
            size: 28,
            // 顺序是默认模式，图标弱化；随机/单曲为激活态高亮
            color: state.playMode == PlayMode.sequence
                ? AppColors.textOnPink
                : AppColors.accentRose,
          ),
          onPressed: () {
            ctrl.togglePlayMode();
            final mode = ref.read(musicPlayerProvider).playMode;
            if (context.mounted) {
              AppSnackbar.show(context, switch (mode) {
                PlayMode.sequence => '顺序播放',
                PlayMode.shuffle => '随机播放',
                PlayMode.repeatOne => '单曲循环',
              });
            }
          },
        ),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.skip_previous_rounded,
              size: _kControlIconSize, color: AppColors.textOnPink),
          onPressed: () async {
            try {
              await ctrl.previous();
            } on MusicPlaybackException {
              if (context.mounted) {
                AppSnackbar.show(
                    context, MusicPlaybackException.feedbackMessage);
              }
            } catch (_) {
              if (context.mounted) AppSnackbar.show(context, '切换失败');
            }
          },
        ),
        const SizedBox(width: 24),
        GestureDetector(
          onTap: () async {
            try {
              await ctrl.togglePlay();
            } catch (_) {
              if (context.mounted) AppSnackbar.show(context, '播放失败');
            }
          },
          child: Container(
            width: _kPlayButtonSize,
            height: _kPlayButtonSize,
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
              size: _kControlIconSize, color: AppColors.textOnPink),
          onPressed: () async {
            try {
              await ctrl.next();
            } on MusicPlaybackException {
              if (context.mounted) {
                AppSnackbar.show(
                    context, MusicPlaybackException.feedbackMessage);
              }
            } catch (_) {
              if (context.mounted) AppSnackbar.show(context, '切换失败');
            }
          },
        ),
        const SizedBox(width: 8),
        // 歌曲列表（原页面底部按钮移入）
        IconButton(
          icon: const Icon(Icons.queue_music_rounded,
              size: 28, color: AppColors.textOnPink),
          onPressed: () => PlaylistSheet.show(context),
        ),
      ],
    );
  }
}

/// 空状态（无本地音乐 / 扫描失败兜底）
class MusicEmptyState extends StatelessWidget {
  /// 非空时显示「重新扫描」按钮：
  /// 真无音乐可手动重扫，扫描失败兜底成空态后也能重试恢复
  final VoidCallback? onRetry;
  const MusicEmptyState({super.key, this.onRetry});

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
          if (onRetry != null) ...[
            const SizedBox(height: 24),
            FilledButton(
              onPressed: onRetry,
              style: FilledButton.styleFrom(backgroundColor: AppColors.bgCard),
              child: Text('重新扫描',
                  style: AppTextStyles.body
                      .copyWith(color: AppColors.accentRose)),
            ),
          ],
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
