import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../providers/music_library_provider.dart';
import '../providers/music_player_provider.dart';
import 'widgets/music_player_widgets.dart';
import 'widgets/playlist_sheet.dart';

/// 全屏音乐播放页（网易云风格）
///
/// 通过 [show] 以全屏 BottomSheet 弹出，渐变背景 + 旋转封面 + 进度/控制/列表。
class MusicPlayerPage extends ConsumerStatefulWidget {
  const MusicPlayerPage({super.key});

  /// 以全屏 BottomSheet 弹出播放页
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const MusicPlayerPage(),
    );
  }

  @override
  ConsumerState<MusicPlayerPage> createState() => _MusicPlayerPageState();
}

class _MusicPlayerPageState extends ConsumerState<MusicPlayerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _rotateCtrl;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
  }

  @override
  void dispose() {
    _rotateCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(musicPlayerProvider);
    final library = ref.watch(musicLibraryProvider);

    // 旋转动画跟随播放状态
    if (state.isPlaying) {
      if (!_rotateCtrl.isAnimating) _rotateCtrl.repeat();
    } else {
      _rotateCtrl.stop();
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.headerGradient,
        ),
        child: SafeArea(
          child: library.when(
            loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2)),
            error: (e, _) => e is MusicPermissionDeniedException
                ? MusicPermissionState(
                    onRetry: () => ref.refresh(musicLibraryProvider))
                : Center(child: Text('加载失败', style: AppTextStyles.body)),
            data: (songs) => songs.isEmpty
                ? const MusicEmptyState()
                : _playerContent(state),
          ),
        ),
      ),
    );
  }

  /// 播放器主体内容：收起条 + 歌名 + 旋转封面 + 进度 + 控制 + 列表按钮
  Widget _playerContent(MusicPlayerState state) {
    final song = state.currentSong;
    return Column(
      children: [
        // 顶部收起条
        GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: AppColors.textOnPink.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(song?.title ?? '',
            style: AppTextStyles.titleLarge
                .copyWith(color: AppColors.textOnPink),
            maxLines: 1,
            overflow: TextOverflow.ellipsis),
        Text(song?.artist ?? '',
            style: AppTextStyles.caption
                .copyWith(color: AppColors.textOnPink)),
        const SizedBox(height: 24),
        // 大封面（旋转）
        Expanded(
          child: Center(
            child: RotationTransition(
              turns: _rotateCtrl,
              child: MusicBigCover(song: song),
            ),
          ),
        ),
        // 进度条
        MusicProgressRow(state: state),
        const SizedBox(height: 8),
        // 控制区
        MusicControls(state: state),
        const SizedBox(height: 8),
        // 列表按钮
        IconButton(
          icon: const Icon(Icons.queue_music_rounded,
              color: AppColors.textOnPink),
          onPressed: () => PlaylistSheet.show(context),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
