import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/album_photo.dart';
import '../../../data/providers/data_providers.dart';
import '../models/music_song.dart';
import '../providers/music_library_provider.dart';
import '../providers/music_player_provider.dart';
import 'widgets/memory_photo_carousel.dart';
import 'widgets/music_player_states.dart';
import 'widgets/music_player_widgets.dart';

/// 全屏音乐播放页。
///
/// 奶油粉背景中的“回忆唱片”：播放时轮播 App 内相册照片，照片不可用时回退到
/// 歌曲封面；进度与播放控制保持音乐播放器的主视觉层级。
class MusicPlayerPage extends ConsumerStatefulWidget {
  const MusicPlayerPage({super.key});

  /// 以全屏 BottomSheet 弹出播放页。
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: false,
      backgroundColor: Colors.transparent,
      builder: (_) => const MusicPlayerPage(),
    );
  }

  @override
  ConsumerState<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends ConsumerState<MusicPlayerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _slideCtrl;
  late final ProviderSubscription<AsyncValue<List<MusicSong>>> _librarySub;

  @override
  void initState() {
    super.initState();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    // 只有真正打开音乐页才触发系统音频权限和扫描，避免冷启动弹权限框。
    _librarySub = ref.listenManual<AsyncValue<List<MusicSong>>>(
      musicLibraryProvider,
      (_, next) {
        final songs = next.valueOrNull;
        if (songs == null) return;
        final controller = ref.read(musicPlayerProvider.notifier);
        unawaited(controller.reconcilePlaylist(songs));
      },
      fireImmediately: true,
    );
    ref.read(musicPlayerProvider.notifier).showPlayer();
  }

  @override
  void dispose() {
    _librarySub.close();
    _slideCtrl.dispose();
    super.dispose();
  }

  void _onVerticalDragUpdate(DragUpdateDetails details) {
    _slideCtrl.value = (_slideCtrl.value +
            details.delta.dy / MediaQuery.sizeOf(context).height)
        .clamp(0.0, 1.0);
  }

  void _onVerticalDragEnd(DragEndDetails details) {
    final velocity = details.primaryVelocity ?? 0;
    if (_slideCtrl.value > 0.25 || velocity > 800) {
      _slideCtrl.animateTo(1).then((_) {
        if (context.mounted) Navigator.of(context).pop();
      });
      return;
    }
    _slideCtrl.animateBack(0, curve: Curves.easeOut);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicPlayerProvider);
    final library = ref.watch(musicLibraryProvider);
    // 这里只消费 App 内 Isar 相册数据，不调用 image_picker 或系统相册接口。
    final albumPhotos =
        ref.watch(allPhotosTypedProvider).valueOrNull ?? const <AlbumPhoto>[];

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: _onVerticalDragUpdate,
      onVerticalDragEnd: _onVerticalDragEnd,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0, 1.08),
        ).animate(_slideCtrl),
        child: Scaffold(
          backgroundColor: AppColors.bgPrimary,
          body: DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topRight,
                radius: 1.15,
                colors: [
                  AppColors.accentPinkSoft.withValues(alpha: 0.72),
                  AppColors.bgPrimary,
                  AppColors.bgCream,
                ],
                stops: const [0, 0.48, 1],
              ),
            ),
            child: SafeArea(
              child: library.when(
                loading: () => _stateContent(
                  const CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (error, _) => _stateContent(
                  error is MusicPermissionDeniedException
                      ? MusicPermissionState(
                          onRetry: () => ref.refresh(musicLibraryProvider),
                        )
                      : MusicLoadErrorState(
                          onRetry: () => ref.refresh(musicLibraryProvider),
                        ),
                ),
                data: (songs) => songs.isEmpty
                    ? _stateContent(
                        MusicEmptyState(
                          onRetry: () => ref.refresh(musicLibraryProvider),
                        ),
                      )
                    : _playerContent(state, albumPhotos),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _stateContent(Widget child) {
    return Column(
      children: [
        _PlayerTopBar(
          title: '回忆唱片',
          onClose: () => Navigator.of(context).pop(),
        ),
        Expanded(child: Center(child: child)),
      ],
    );
  }

  Widget _playerContent(
    MusicPlayerState state,
    List<AlbumPhoto> albumPhotos,
  ) {
    final song = state.currentSong;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 680;
        final sectionGap = compact ? AppColors.spacingSm : AppColors.spacingLg;
        return Column(
          children: [
            _PlayerTopBar(
              title: state.isLoading
                  ? '正在准备'
                  : state.isPlaying
                      ? '正在播放'
                      : '回忆唱片',
              onClose: () => Navigator.of(context).pop(),
            ),
            SizedBox(
                height: compact ? AppColors.spacing2xs : AppColors.spacingXs),
            Expanded(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: compact
                        ? AppColors.spacing2xl
                        : AppColors.spacing2xl + AppColors.spacingXs,
                  ),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      maxWidth: 360,
                      maxHeight: 360,
                    ),
                    child: AspectRatio(
                      aspectRatio: 1,
                      child: MemoryPhotoCarousel(
                        photos: albumPhotos,
                        song: song,
                        isPlaying: state.isPlaying,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SizedBox(height: sectionGap),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Padding(
                key: ValueKey<int?>(song?.id),
                padding: const EdgeInsets.symmetric(
                  horizontal: AppColors.spacingXl,
                ),
                child: Column(
                  children: [
                    Text(
                      song?.title ?? '',
                      style: AppTextStyles.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppColors.spacing2xs),
                    Text(
                      song?.artist ?? '',
                      style: AppTextStyles.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(
                height: compact ? AppColors.spacingXs : AppColors.spacingSm),
            MusicProgressRow(state: state),
            SizedBox(
                height: compact ? AppColors.spacingXs : AppColors.spacingMd),
            MusicControls(state: state),
            SizedBox(
                height: compact ? AppColors.spacingXs : AppColors.spacingMd),
          ],
        );
      },
    );
  }
}

class _PlayerTopBar extends StatelessWidget {
  const _PlayerTopBar({required this.title, required this.onClose});

  final String title;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.only(left: AppColors.spacingXs),
              child: IconButton(
                tooltip: '收起播放器',
                onPressed: onClose,
                icon: const Icon(Icons.keyboard_arrow_down_rounded, size: 30),
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textPrimary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
