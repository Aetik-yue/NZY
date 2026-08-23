import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/album_photo.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../data/sync/sync_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import 'add_photo_sheet.dart';

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

  /// 删除回调（通知父组件更新状态）
  final void Function(AlbumPhoto photo)? onDelete;

  const PhotoViewer({
    super.key,
    required this.photos,
    this.initialIndex = 0,
    this.onDelete,
  });

  /// 全屏查看照片
  static Future<void> show(
    BuildContext context, {
    required List<AlbumPhoto> photos,
    int initialIndex = 0,
    void Function(AlbumPhoto photo)? onDelete,
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
          onDelete: onDelete,
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
  late List<AlbumPhoto> _photos;
  bool _showAppBar = true;

  // 黑底沉浸场景专用样式（设计系统样式为浅色背景，此处不适用）
  static const _indexStyle = TextStyle(
    color: Colors.white,
    fontSize: 16,
    fontWeight: FontWeight.w600,
  );
  static const _dateStyle = TextStyle(
    color: Colors.white70,
    fontSize: 14,
  );

  @override
  void initState() {
    super.initState();
    // 复制列表，避免修改父组件的不可变列表
    _photos = List.from(widget.photos);
    // 空列表防护：clamp(0, -1) 会抛 ArgumentError
    _currentIndex =
        _photos.isEmpty ? 0 : widget.initialIndex.clamp(0, _photos.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
  }

  /// 编辑当前照片（改日期/分类）
  Future<void> _editCurrent() async {
    if (_photos.isEmpty) return;
    final updated = await AddPhotoSheet.show(
      context,
      initial: _photos[_currentIndex],
    );
    if (!mounted || updated == null) return;
    // 同步本地列表，保持查看器日期显示一致
    setState(() {
      _photos[_currentIndex] = updated;
    });
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
    if (_photos.isEmpty) return;
    final confirmed = await showConfirmDeleteDialog(
      context,
      title: '删除照片',
      content: '确定要删除这张照片吗？删除后可在提示中撤销。',
    );
    if (!confirmed) return;
    if (!mounted) return;

    final photo = _photos[_currentIndex];
    // 预先捕获仓库实例：撤销回调可能在查看器关闭后才执行，
    // 直接使用 State 的 ref 会因组件已销毁而报错。
    final repo = ref.read(albumRepositoryProvider);
    final syncEngine = ref.read(syncEngineProvider);
    final photoSyncService = ref.read(photoSyncServiceProvider);
    final cloudId = photo.cloudId;
    final cloudPath = photo.cloudPath;

    try {
      await repo.delete(photo.id);
      // 同步删除云端：先删云文件再删元数据（防对方侧残留文件）
      if (cloudPath != null) {
        try {
          await photoSyncService.deleteRemoteFile(cloudPath);
        } catch (e) {
          debugPrint('[PhotoViewer] 删除云文件失败: $e');
        }
      }
      if (cloudId != null) {
        syncEngine.markDeleted(cloudId);
      }
    } catch (e) {
      if (mounted) AppSnackbar.show(context, '删除失败，请重试');
      return;
    }

    // 通知父组件删除成功（在修改本地状态前）
    widget.onDelete?.call(photo);

    if (!mounted) return;
    // 删除仅移除数据库记录；图片文件保存在应用文档目录，撤销时恢复记录
    // 即可还原照片。后续可在明确不撤销后异步清理孤立文件。
    // 注：撤销只恢复数据库（相册网格经流刷新可见），查看器本地列表
    // 不恢复——删除动作本身已从查看器移除该项，属预期行为。
    AppSnackbar.showUndo(context, '已删除照片', () async {
      if (cloudId != null) {
        syncEngine.restoreDeleted(cloudId);
      }
      // 云文件可能已删除，清空对象名后由照片同步服务重新上传。
      if (cloudPath != null) photo.cloudPath = null;
      await repo.add(photo);
      await photoSyncService.syncPhotos();
    });

    // 更新本地列表
    _photos.removeAt(_currentIndex);

    if (_photos.isEmpty) {
      // 所有照片已删除，关闭查看器
      Navigator.of(context).pop();
      return;
    }

    // 调整当前索引
    if (_currentIndex >= _photos.length) {
      _currentIndex = _photos.length - 1;
    }
    // 同步 PageController 位置
    _pageController.jumpToPage(_currentIndex);

    setState(() {});
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
              itemCount: _photos.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              itemBuilder: (_, i) {
                final photo = _photos[i];
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
                        '${_currentIndex + 1} / ${_photos.length}',
                        style: _indexStyle,
                        textAlign: TextAlign.center,
                      ),
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.edit_outlined, color: Colors.white),
                      onPressed: _editCurrent,
                    ),
                    IconButton(
                      icon:
                          const Icon(Icons.delete_outline, color: Colors.white),
                      onPressed: _deleteCurrent,
                    ),
                  ],
                ),
              ),
            ),
          ),

          // 底部日期信息
          if (_showAppBar && _photos.isNotEmpty)
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
                    _formatPhotoDate(_photos[_currentIndex].date),
                    style: _dateStyle,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatPhotoDate(DateTime d) => '${d.year}年${d.month}月${d.day}日';
}
