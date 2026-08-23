import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../providers/music_player_provider.dart';
import 'playlist_sheet.dart';

const _kPlayButtonSize = 72.0;
const _kSkipButtonSize = 56.0;

/// 进度条行：拖动中仅预览，松手后执行一次 seek。
class MusicProgressRow extends ConsumerStatefulWidget {
  const MusicProgressRow({super.key, required this.state});

  final MusicPlayerState state;

  @override
  ConsumerState<MusicProgressRow> createState() => _MusicProgressRowState();
}

class _MusicProgressRowState extends ConsumerState<MusicProgressRow> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final total = widget.state.duration?.inSeconds ?? 0;
    final seconds = _dragValue != null
        ? _dragValue! * total
        : widget.state.position.inSeconds.clamp(0, total > 0 ? total : 0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppColors.spacingXl),
      child: Column(
        children: [
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 3,
              activeTrackColor: AppColors.accentRose,
              inactiveTrackColor: AppColors.accentPinkSoft,
              thumbColor: AppColors.accentRose,
              overlayColor: AppColors.shadowPinkMedium,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
            ),
            child: Slider(
              value: total > 0 ? seconds / total : 0,
              min: 0,
              max: 1,
              onChanged: total > 0
                  ? (value) => setState(() => _dragValue = value)
                  : null,
              onChangeStart: total > 0
                  ? (_) => setState(() => _dragValue =
                      (widget.state.position.inSeconds / total).clamp(0.0, 1.0))
                  : null,
              onChangeEnd: total > 0
                  ? (value) {
                      setState(() => _dragValue = null);
                      ref.read(musicPlayerProvider.notifier).seekTo(
                            Duration(seconds: (value * total).round()),
                          );
                    }
                  : null,
            ),
          ),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppColors.spacingXs),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _formatDuration(Duration(seconds: seconds.round())),
                  style: AppTextStyles.caption,
                ),
                Text(
                  _formatDuration(widget.state.duration ?? Duration.zero),
                  style: AppTextStyles.caption,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

/// 播放控制区：主行只承载切歌与播放，模式和列表放在次级操作行。
class MusicControls extends ConsumerWidget {
  const MusicControls({super.key, required this.state});

  final MusicPlayerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(musicPlayerProvider.notifier);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _SkipButton(
              tooltip: '上一首',
              icon: Icons.skip_previous_rounded,
              onPressed: () => _runPlaybackAction(
                context,
                controller.previous,
                fallbackMessage: '切换失败',
              ),
            ),
            const SizedBox(width: AppColors.spacingXl),
            Semantics(
              button: true,
              label: state.isPlaying ? '暂停' : '播放',
              child: Material(
                color: AppColors.bgCard.withValues(alpha: 0),
                shape: const CircleBorder(),
                child: Ink(
                  width: _kPlayButtonSize,
                  height: _kPlayButtonSize,
                  decoration: const BoxDecoration(
                    gradient: AppColors.pinkButtonGradient,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.shadowPinkStrong,
                        blurRadius: 20,
                        offset: Offset(0, 8),
                        spreadRadius: -6,
                      ),
                    ],
                  ),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => _runPlaybackAction(
                      context,
                      controller.togglePlay,
                      fallbackMessage: '播放失败',
                    ),
                    child: state.isLoading
                        ? const Padding(
                            padding: EdgeInsets.all(AppColors.spacingXl),
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: AppColors.textOnPink,
                            ),
                          )
                        : Icon(
                            state.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 42,
                            color: AppColors.textOnPink,
                          ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AppColors.spacingXl),
            _SkipButton(
              tooltip: '下一首',
              icon: Icons.skip_next_rounded,
              onPressed: () => _runPlaybackAction(
                context,
                controller.next,
                fallbackMessage: '切换失败',
              ),
            ),
          ],
        ),
        const SizedBox(height: AppColors.spacingSm),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppColors.spacingXl),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton.icon(
                onPressed: () {
                  controller.togglePlayMode();
                  final mode = ref.read(musicPlayerProvider).playMode;
                  AppSnackbar.show(context, _playModeLabel(mode));
                },
                icon: Icon(_playModeIcon(state.playMode), size: 22),
                label: Text(_playModeLabel(state.playMode)),
                style: TextButton.styleFrom(
                  foregroundColor: state.playMode == PlayMode.sequence
                      ? AppColors.textSecondary
                      : AppColors.accentRose,
                  minimumSize: const Size(48, 48),
                ),
              ),
              TextButton.icon(
                onPressed: () => PlaylistSheet.show(context),
                icon: const Icon(Icons.queue_music_rounded, size: 22),
                label: const Text('播放列表'),
                style: TextButton.styleFrom(
                  foregroundColor: AppColors.textSecondary,
                  minimumSize: const Size(48, 48),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _runPlaybackAction(
    BuildContext context,
    Future<void> Function() action, {
    required String fallbackMessage,
  }) async {
    try {
      await action();
    } on MusicPlaybackException {
      if (context.mounted) {
        AppSnackbar.show(context, MusicPlaybackException.feedbackMessage);
      }
    } catch (_) {
      if (context.mounted) AppSnackbar.show(context, fallbackMessage);
    }
  }

  IconData _playModeIcon(PlayMode mode) => switch (mode) {
        PlayMode.sequence => Icons.repeat_rounded,
        PlayMode.shuffle => Icons.shuffle_rounded,
        PlayMode.repeatOne => Icons.repeat_one_rounded,
      };

  String _playModeLabel(PlayMode mode) => switch (mode) {
        PlayMode.sequence => '顺序播放',
        PlayMode.shuffle => '随机播放',
        PlayMode.repeatOne => '单曲循环',
      };
}

class _SkipButton extends StatelessWidget {
  const _SkipButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      constraints: const BoxConstraints.tightFor(
        width: _kSkipButtonSize,
        height: _kSkipButtonSize,
      ),
      icon: Icon(icon, size: 40),
      color: AppColors.textPrimary,
    );
  }
}
