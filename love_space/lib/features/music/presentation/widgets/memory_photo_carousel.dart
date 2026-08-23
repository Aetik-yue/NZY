import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../data/models/album_photo.dart';
import '../../models/memory_photo_deck.dart';
import '../../models/music_song.dart';
import '../../providers/music_memory_photo_provider.dart';

/// App 内相册照片轮播封面。
///
/// 播放中每 12 秒切换，暂停时冻结，切歌时立即前进一张。照片只来自
/// [AlbumPhoto.filePath]，不会访问手机系统相册。
class MemoryPhotoCarousel extends ConsumerStatefulWidget {
  const MemoryPhotoCarousel({
    super.key,
    required this.photos,
    required this.song,
    required this.isPlaying,
  });

  final List<AlbumPhoto> photos;
  final MusicSong? song;
  final bool isPlaying;

  @override
  ConsumerState<MemoryPhotoCarousel> createState() =>
      _MemoryPhotoCarouselState();
}

class _MemoryPhotoCarouselState extends ConsumerState<MemoryPhotoCarousel> {
  static const _interval = Duration(seconds: 12);

  final MemoryPhotoDeck _deck = MemoryPhotoDeck();
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _deck.updatePaths(_validPhotoPaths(widget.photos));
    _publishCurrentPhoto();
    _syncTimer();
  }

  @override
  void didUpdateWidget(MemoryPhotoCarousel oldWidget) {
    super.didUpdateWidget(oldWidget);
    // 播放进度每 500ms 都会让父组件重建；照片列表实例未变化时跳过文件检查，
    // 避免对大相册反复 existsSync。
    final pathsChanged = !identical(oldWidget.photos, widget.photos) &&
        _deck.updatePaths(_validPhotoPaths(widget.photos));
    final songChanged = oldWidget.song?.id != widget.song?.id;
    if (songChanged && _deck.length > 1) {
      _deck.advance();
    }
    if (pathsChanged || songChanged) {
      _publishCurrentPhoto();
    }
    if (pathsChanged ||
        songChanged ||
        oldWidget.isPlaying != widget.isPlaying) {
      _syncTimer();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  List<String> _validPhotoPaths(List<AlbumPhoto> photos) {
    return [
      for (final photo in photos)
        if (photo.filePath != null && File(photo.filePath!).existsSync())
          photo.filePath!,
    ];
  }

  void _syncTimer() {
    _timer?.cancel();
    _timer = null;
    if (!widget.isPlaying || _deck.length <= 1) return;
    _timer = Timer.periodic(_interval, (_) => _advance());
  }

  void _advance() {
    if (!mounted || _deck.length <= 1) return;
    setState(_deck.advance);
    _publishCurrentPhoto();
  }

  void _publishCurrentPhoto() {
    final path = _deck.current;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final notifier = ref.read(musicMemoryPhotoPathProvider.notifier);
      if (notifier.state != path) notifier.state = path;
    });
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final path = _deck.current;
    final child = path == null
        ? _SongCover(
            key: ValueKey('song-${widget.song?.id}'), song: widget.song)
        : _MemoryPhotoCover(
            key: ValueKey('memory-$path'),
            path: path,
            fallbackSong: widget.song,
          );

    return RepaintBoundary(
      child: AnimatedSwitcher(
        duration:
            reduceMotion ? Duration.zero : const Duration(milliseconds: 800),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.center,
          children: [
            ...previousChildren,
            if (currentChild != null) currentChild
          ],
        ),
        transitionBuilder: (child, animation) {
          if (reduceMotion) return child;
          return FadeTransition(
            opacity: animation,
            child: ScaleTransition(
              scale: Tween<double>(begin: 0.985, end: 1).animate(animation),
              child: child,
            ),
          );
        },
        child: child,
      ),
    );
  }
}

/// 白色相框中的 App 相册照片：模糊填充背景，前景完整显示，避免裁掉人物。
class _MemoryPhotoCover extends StatelessWidget {
  const _MemoryPhotoCover({
    super.key,
    required this.path,
    required this.fallbackSong,
  });

  final String path;
  final MusicSong? fallbackSong;

  @override
  Widget build(BuildContext context) {
    final file = File(path);
    return Semantics(
      image: true,
      label: 'App 相册照片',
      child: _CoverFrame(
        child: Stack(
          fit: StackFit.expand,
          children: [
            ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 14, sigmaY: 14),
              child: Image.file(
                file,
                fit: BoxFit.cover,
                cacheWidth: 720,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _SongArtwork(song: fallbackSong),
              ),
            ),
            ColoredBox(color: AppColors.bgCard.withValues(alpha: 0.16)),
            Padding(
              padding: const EdgeInsets.all(AppColors.spacingXs),
              child: Image.file(
                file,
                fit: BoxFit.contain,
                cacheWidth: 1080,
                gaplessPlayback: true,
                errorBuilder: (_, __, ___) => _SongArtwork(song: fallbackSong),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SongCover extends StatelessWidget {
  const _SongCover({super.key, required this.song});

  final MusicSong? song;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: song == null ? '音乐封面' : '${song!.title}的音乐封面',
      child: _CoverFrame(child: _SongArtwork(song: song)),
    );
  }
}

class _CoverFrame extends StatelessWidget {
  const _CoverFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppColors.spacingXs),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowPinkMedium,
            blurRadius: 28,
            offset: Offset(0, 12),
            spreadRadius: -10,
          ),
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: child,
      ),
    );
  }
}

class _SongArtwork extends StatelessWidget {
  const _SongArtwork({required this.song});

  final MusicSong? song;

  @override
  Widget build(BuildContext context) {
    final current = song;
    final gradient = current == null
        ? AppColors.musicCardGradient
        : AppColors.coverGradients[current.coverIndex];
    if (current?.coverBytes != null) {
      return Image.memory(
        current!.coverBytes!,
        fit: BoxFit.cover,
        gaplessPlayback: true,
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(gradient: gradient),
      child: const Center(
        child: Icon(
          Icons.music_note_rounded,
          size: 88,
          color: AppColors.textOnPink,
        ),
      ),
    );
  }
}
