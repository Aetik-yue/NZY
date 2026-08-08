import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_snackbar.dart';
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
            _EqualizerBars(playing: state.isPlaying),
            const SizedBox(width: 8),
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
              onTap: () async {
                try {
                  await ref.read(musicPlayerProvider.notifier).togglePlay();
                } catch (_) {
                  if (context.mounted) AppSnackbar.show(context, '播放失败');
                }
              },
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

/// 播放中等化器动效（3 条竖线跳动；暂停时静止半透明）
class _EqualizerBars extends StatefulWidget {
  final bool playing;
  const _EqualizerBars({required this.playing});

  @override
  State<_EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<_EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _a;
  late final Animation<double> _b;
  late final Animation<double> _c;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    if (widget.playing) {
      _ctrl.repeat(reverse: true);
    } else {
      // 首屏暂停态静止在中间高度，与 didUpdateWidget 暂停分支对称，
      // 避免默认 value=0 时中间条满高（14px 灰色）形似"仍在播放"
      _ctrl.value = 0.5;
    }
    _a = Tween(begin: 0.3, end: 1.0)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _b = Tween(begin: 1.0, end: 0.3)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
    _c = Tween(begin: 0.6, end: 0.9)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void didUpdateWidget(_EqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing && !_ctrl.isAnimating) {
      _ctrl.repeat(reverse: true);
    } else if (!widget.playing && _ctrl.isAnimating) {
      _ctrl.stop();
      _ctrl.value = 0.5; // 静止在中间高度
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        const barHeight = 14.0;
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _bar(_a.value * barHeight),
            const SizedBox(width: 2),
            _bar(_b.value * barHeight),
            const SizedBox(width: 2),
            _bar(_c.value * barHeight),
          ],
        );
      },
    );
  }

  Widget _bar(double height) {
    return Container(
      width: 3,
      height: height.clamp(4, 14),
      decoration: BoxDecoration(
        color: widget.playing
            ? AppColors.accentRose
            : AppColors.textTertiary,
        borderRadius: BorderRadius.circular(AppColors.radiusXs),
      ),
    );
  }
}
