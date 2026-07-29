import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../data/models/album_photo.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/confirm_dialog.dart';

/// 照片全屏查看器
///
/// 支持：
/// - 双指缩放 / 双击放大
/// - 左右滑动切换照片
/// - 当前照片删除（带确认）
/// - 顶部索引指示器 + 日期
class PhotoViewer extends ConsumerStatefulWidget {
  final List<AlbumPhoto> photos;
  final int initialIndex;

  const PhotoViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
  });

  /// 全屏查看照片
  static Future<void> show(
    BuildContext context, {
    required List<AlbumPhoto> photos,
    int initialIndex = 0,
  }) {
    return Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.black,
        transitionDuration: const Duration(milliseconds: 250),
        reverseTransitionDuration: const Duration(milliseconds: 200),
        pageBuilder: (_, __, ___) => PhotoViewer(
          photos: photos,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  ConsumerState<PhotoViewer> createState() => _PhotoViewerState();
}

class _PhotoViewerState extends ConsumerState<PhotoViewer> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showAppBar = true;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _toggleAppBar() {
    setState(() => _showAppBar = !_showAppBar);
  }

  Future<void> _deleteCurrent() async {
    if (widget.photos.isEmpty) return;
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: '删除照片',
      content: '确定要删除这张照片吗？此操作无法撤销。',
    );
    if (!confirmed) return;
    if (!mounted) return;

    final photo = widget.photos[_currentIndex];
    await ref.read(albumRepositoryProvider).delete(photo.id);

    if (!mounted) return;
    AppSnackbar.show(context, '已删除照片');

    setState(() {
      widget.photos.removeAt(_currentIndex);
      if (widget.photos.isEmpty) {
        Navigator.of(context).pop();
        return;
      }
      if (_currentIndex >= widget.photos.length) {
        _currentIndex = widget.photos.length - 1;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 照片翻页
          GestureDetector(
            onTap: _toggleAppBar,
            child: PageView.builder(
              controller: _pageController,
              itemCount: widget.photos.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, i) {
                final photo = widget.photos[i];
                return InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: Center(
                    child: photo.filePath != null
                        ? Image.file(
                            File(photo.filePath!),
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.broken_image,
                                  color: Colors.white38, size: 64),
                            ),
                          )
                        : const Center(
                            child: Icon(Icons.image,
                                color: Colors.white24, size: 80),
                          ),
                  ),
                );
              },
            ),
          ),

          // 顶部栏
          AnimatedPositioned(
            duration: const Duration(milliseconds: 200),
            top: _showAppBar ? 0 : -80,
            left: 0,
            right: 0,
            child: SafeArea(
              bottom: false,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.6),
                      Colors.transparent,
                    ],
                  ),
                ),
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                    Expanded(
                      child: Text(
                        '${_currentIndex + 1} / ${widget.photos.length}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outline,
                          color: Colors.white),
                      onPressed: _deleteCurrent,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 底部日期信息
          if (_showAppBar && widget.photos.isNotEmpty)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.5),
                        Colors.transparent,
                      ],
                    ),
                  ),
                  child: Text(
                    _formatPhotoDate(widget.photos[_currentIndex].date),
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 14,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatPhotoDate(DateTime d) =>
      '${d.year}年${d.month}月${d.day}日';
}
