import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../models/music_song.dart';
import '../../providers/music_memory_photo_provider.dart';
import '../../providers/music_player_provider.dart';
import '../music_player_page.dart';
import 'music_equalizer_bars.dart';

/// 底部常驻迷你播放器。
///
/// 显示全屏页最后一张 App 相册照片，但不会在后台持续轮播；整条点击进入全屏页。
/// 左右滑动超过阈值可关闭（同时暂停播放），未达阈值时平滑回弹。
class MiniPlayerBar extends ConsumerStatefulWidget {
  const MiniPlayerBar({super.key});

  @override
  ConsumerState<MiniPlayerBar> createState() => _MiniPlayerBarState();
}

class _MiniPlayerBarState extends ConsumerState<MiniPlayerBar>
    with SingleTickerProviderStateMixin {
  static const _dismissDistanceRatio = 0.28;
  static const _dismissVelocity = 700.0;

  double _dragX = 0;
  double _springFrom = 0;
  late final AnimationController _springController;

  @override
  void initState() {
    super.initState();
    _springController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    )..addListener(() {
        final progress = Curves.easeOut.transform(_springController.value);
        setState(() => _dragX = _springFrom * (1 - progress));
      });
  }

  @override
  void dispose() {
    _springController.dispose();
    super.dispose();
  }

  void _onHorizontalDragStart(DragStartDetails _) {
    _springController.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    setState(() => _dragX += details.delta.dx);
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    final width = MediaQuery.sizeOf(context).width;
    final velocity = details.primaryVelocity ?? 0;
    final crossedDistance = _dragX.abs() >= width * _dismissDistanceRatio;
    final crossedVelocity = velocity.abs() >= _dismissVelocity;
    if (crossedDistance || crossedVelocity) {
      _springController.stop();
      setState(() => _dragX = 0);
      ref.read(musicPlayerProvider.notifier).hidePlayer();
      return;
    }
    _springBack();
  }

  void _springBack() {
    if (_dragX == 0) return;
    _springFrom = _dragX;
    _springController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicPlayerProvider);
    final song = state.currentSong;
    final memoryPhotoPath = ref.watch(musicMemoryPhotoPathProvider);
    if (song == null || state.isHidden) return const SizedBox.shrink();

    final total = state.duration?.inMilliseconds ?? 0;
    final progress = total > 0
        ? (state.position.inMilliseconds / total).clamp(0.0, 1.0)
        : 0.0;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final opacity = (1 - _dragX.abs() / screenWidth).clamp(0.0, 1.0);

    return Semantics(
      button: true,
      label: '打开音乐播放器，当前歌曲${song.title}',
      hint: '左右滑动可关闭迷你播放器',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => MusicPlayerPage.show(context),
        onHorizontalDragStart: _onHorizontalDragStart,
        onHorizontalDragUpdate: _onHorizontalDragUpdate,
        onHorizontalDragEnd: _onHorizontalDragEnd,
        onHorizontalDragCancel: _springBack,
        child: Transform.translate(
          offset: Offset(_dragX, 0),
          child: Opacity(
            opacity: opacity,
            child: Container(
              key: const Key('mini_player_surface'),
              margin: const EdgeInsets.fromLTRB(
                AppColors.spacingSm,
                0,
                AppColors.spacingSm,
                AppColors.spacing2xs,
              ),
              decoration: BoxDecoration(
                color: AppColors.bgCard,
                borderRadius: BorderRadius.circular(AppColors.radiusPill),
                border: Border.all(color: AppColors.borderSoft),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowPink,
                    blurRadius: 18,
                    offset: Offset(0, 5),
                    spreadRadius: -5,
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(
                    value: progress,
                    minHeight: 2,
                    color: AppColors.accentRose,
                    backgroundColor: AppColors.accentPinkSoft,
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppColors.spacingSm,
                      AppColors.spacingXs,
                      AppColors.spacingXs,
                      AppColors.spacingXs,
                    ),
                    child: Row(
                      children: [
                        _Cover(
                          song: song,
                          memoryPhotoPath: memoryPhotoPath,
                          size: 40,
                        ),
                        const SizedBox(width: AppColors.spacingSm),
                        MusicEqualizerBars(playing: state.isPlaying),
                        const SizedBox(width: AppColors.spacingXs),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                song.title,
                                style: AppTextStyles.body.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                song.artist,
                                style: AppTextStyles.caption,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                        _MiniPlayButton(state: state),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _MiniPlayButton extends ConsumerWidget {
  const _MiniPlayButton({required this.state});

  final MusicPlayerState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Semantics(
      button: true,
      label: state.isPlaying ? '暂停' : '播放',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () async {
          try {
            await ref.read(musicPlayerProvider.notifier).togglePlay();
          } catch (_) {
            if (context.mounted) AppSnackbar.show(context, '播放失败');
          }
        },
        child: SizedBox.square(
          dimension: 48,
          child: Center(
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                gradient: AppColors.pinkButtonGradient,
                shape: BoxShape.circle,
              ),
              child: state.isLoading
                  ? const Padding(
                      padding: EdgeInsets.all(AppColors.spacingSm),
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnPink,
                      ),
                    )
                  : Icon(
                      state.isPlaying
                          ? Icons.pause_rounded
                          : Icons.play_arrow_rounded,
                      color: AppColors.textOnPink,
                      size: 24,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 迷你封面优先使用回忆照片，文件失效时回退到歌曲原封面或渐变占位。
class _Cover extends StatelessWidget {
  const _Cover({
    required this.song,
    required this.memoryPhotoPath,
    required this.size,
  });

  final MusicSong song;
  final String? memoryPhotoPath;
  final double size;

  @override
  Widget build(BuildContext context) {
    final path = memoryPhotoPath;
    final artwork = song.coverBytes == null
        ? DecoratedBox(
            decoration: BoxDecoration(
              gradient: AppColors.coverGradients[song.coverIndex],
            ),
            child: const Center(
              child: Icon(
                Icons.music_note_rounded,
                color: AppColors.textOnPink,
                size: 20,
              ),
            ),
          )
        : Image.memory(song.coverBytes!, fit: BoxFit.cover);

    return Semantics(
      image: true,
      label: path == null ? '音乐封面' : 'App 相册照片',
      child: SizedBox.square(
        dimension: size,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          child: path != null && File(path).existsSync()
              ? Image.file(
                  File(path),
                  fit: BoxFit.cover,
                  cacheWidth: 160,
                  gaplessPlayback: true,
                  errorBuilder: (_, __, ___) => artwork,
                )
              : artwork,
        ),
      ),
    );
  }
}
