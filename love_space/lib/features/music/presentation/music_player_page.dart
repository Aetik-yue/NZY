import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../models/music_song.dart';
import '../providers/music_library_provider.dart';
import '../providers/music_player_provider.dart';
import 'widgets/music_player_widgets.dart';

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
    with TickerProviderStateMixin {
  late final AnimationController _rotateCtrl;
  late final AnimationController _slideCtrl; // 下滑位移（0=原位，1=移出屏外）
  late final ProviderSubscription<AsyncValue<List<MusicSong>>> _librarySub;

  @override
  void initState() {
    super.initState();
    _rotateCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 20),
    )..repeat();
    _slideCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    // 页面打开才监听扫描结果：权限/扫描仅在真正打开播放页时触发。
    // MiniPlayerBar 与 profile 卡只 watch musicPlayerProvider，启动与切 tab 不弹权限框。
    // fireImmediately: true —— musicLibraryProvider 是非 autoDispose FutureProvider，
    // 扫描结果缓存终生；若首次打开时扫描未完成就收起 sheet，重开时 provider 已是
    // AsyncData 不再重发通知，故需立即回调缓存值，配合去重注入歌单，避免播放器成死角。
    _librarySub = ref.listenManual<AsyncValue<List<MusicSong>>>(
      musicLibraryProvider,
      (_, next) {
        final songs = next.valueOrNull;
        if (songs == null || songs.isEmpty) return;
        final controller = ref.read(musicPlayerProvider.notifier);
        if (_sameSongs(ref.read(musicPlayerProvider).playlist, songs)) {
          return; // 去重：当前歌单已是这批，跳过注入
        }
        controller.setPlaylist(songs);
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _librarySub.close();
    _rotateCtrl.dispose();
    _slideCtrl.dispose();
    super.dispose();
  }

  /// 歌单是否与当前注入的相同（按长度 + id 比对，避免重复注入）
  bool _sameSongs(List<MusicSong> a, List<MusicSong> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i].id != b[i].id) return false;
    }
    return true;
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
                ? MusicEmptyState(
                    onRetry: () => ref.refresh(musicLibraryProvider))
                : _playerContent(state),
          ),
        ),
      ),
    );
  }

  /// 播放器主体内容：收起条 + 歌名 + 旋转封面 + 进度 + 控制（含列表入口）
  Widget _playerContent(MusicPlayerState state) {
    final song = state.currentSong;
    return GestureDetector(
      // 下滑手势：跟随手指向下位移，松手超阈值收起、否则回弹
      onVerticalDragUpdate: (details) {
        // 双向跟手：上下都跟随，clamp 到 [0,1] 防止越界
        _slideCtrl.value =
            (_slideCtrl.value +
                    details.delta.dy / MediaQuery.of(context).size.height)
                .clamp(0.0, 1.0);
      },
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (_slideCtrl.value > 0.25 || velocity > 800) {
          // 先滑出屏幕再收起，观感更顺
          _slideCtrl.animateTo(1).then((_) {
            if (context.mounted) Navigator.of(context).pop();
          });
        } else {
          _slideCtrl.animateBack(0, curve: Curves.easeOut);
        }
      },
      child: SlideTransition(
        position: Tween<Offset>(
          begin: Offset.zero,
          end: const Offset(0, 1.2),
        ).animate(_slideCtrl), // 线性跟手，回弹由 animateBack 的 curve 提供
        child: Column(
          children: [
            // 顶部收起条
            GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: AppColors.textOnPink.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(AppColors.radiusXs),
                ),
              ),
            ),
            const SizedBox(height: 16),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(song?.title ?? '',
                  key: ValueKey<int?>(song?.id),
                  style: AppTextStyles.titleLarge
                      .copyWith(color: AppColors.textOnPink),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(song?.artist ?? '',
                  key: ValueKey<int?>(song?.id),
                  style: AppTextStyles.caption
                      .copyWith(color: AppColors.textOnPink)),
            ),
            const SizedBox(height: 24),
            // 大封面（旋转）
            Expanded(
              child: Center(
                child: RotationTransition(
                  turns: _rotateCtrl,
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 300),
                    child: MusicBigCover(
                      key: ValueKey<int?>(song?.id),
                      song: song,
                    ),
                  ),
                ),
              ),
            ),
            // 进度条
            MusicProgressRow(state: state),
            const SizedBox(height: 8),
            // 控制区（含播放模式 / 列表入口）
            MusicControls(state: state),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
