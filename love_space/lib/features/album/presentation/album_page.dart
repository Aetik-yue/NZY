import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/models/album_photo.dart';
import '../../../data/sync/sync_providers.dart';
import 'photo_timeline_page.dart';
import 'widgets/add_photo_sheet.dart';
import 'widgets/photo_viewer.dart';

/// 相册页
/// 还原设计稿：标题+统计+添加 → 筛选 chip → 九宫格照片
class AlbumPage extends ConsumerStatefulWidget {
  const AlbumPage({super.key});

  @override
  ConsumerState<AlbumPage> createState() => _AlbumPageState();
}

class _AlbumPageState extends ConsumerState<AlbumPage> {
  @override
  void initState() {
    super.initState();
    // 每次进入相册只触发一次；照片流/筛选变化造成的 rebuild 不重复请求云端。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        ref.read(photoSyncServiceProvider).syncPhotos();
      } catch (e) {
        debugPrint('[AlbumPage] 照片同步跳过: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final photoCount = ref.watch(photoCountProvider);
    return CustomScrollView(
      slivers: [
        // 顶部栏：标题 + 添加按钮
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('我们的相册', style: AppTextStyles.titleLarge),
                    const SizedBox(height: 2),
                    Text('共记录了 $photoCount 张照片', style: AppTextStyles.label),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _TimelineButton(),
                    const SizedBox(width: 10),
                    _AddButton(),
                  ],
                ),
              ],
            ),
          ),
        ),
        // 筛选 chip 行
        const SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 16),
            child: _FilterChips(),
          ),
        ),
        // 九宫格（懒加载）
        const _PhotoGrid(),
        // 底部留白
        const SliverToBoxAdapter(
          child: SizedBox(height: 100),
        ),
      ],
    );
  }
}

class _AddButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => AddPhotoSheet.show(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: const BoxDecoration(
          gradient: AppColors.pinkButtonGradient,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.shadowPinkStrong,
              blurRadius: 16,
              offset: Offset(0, 6),
              spreadRadius: -2,
            ),
          ],
        ),
        child: const Icon(Icons.add, color: Colors.white, size: 22),
      ),
    );
  }
}

/// 时间轴入口按钮
class _TimelineButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => const PhotoTimelinePage(),
          ),
        );
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowCard,
              blurRadius: 12,
              offset: Offset(0, 3),
              spreadRadius: -2,
            ),
          ],
        ),
        child: const Icon(
          Icons.timeline_rounded,
          color: AppColors.accentRose,
          size: 22,
        ),
      ),
    );
  }
}

class _FilterChips extends ConsumerWidget {
  const _FilterChips();

  static const _filters = [
    ('全部', null),
    ('旅行', PhotoCategory.travel),
    ('美食', PhotoCategory.food),
    ('日常', PhotoCategory.daily),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(albumFilterProvider);
    return SizedBox(
      height: 32,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: _filters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final (label, category) = _filters[index];
          final isActive = selected == category;
          return GestureDetector(
            onTap: () =>
                ref.read(albumFilterProvider.notifier).state = category,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: isActive ? AppColors.pinkButtonGradient : null,
                color: isActive ? null : AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border:
                    isActive ? null : Border.all(color: AppColors.borderSoft),
              ),
              child: Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: isActive ? Colors.white : AppColors.textSecondary,
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PhotoGrid extends ConsumerWidget {
  const _PhotoGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photosAsync = ref.watch(filteredAlbumPhotosProvider);
    return photosAsync.when(
      data: (photos) {
        if (photos.isEmpty) {
          return const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48),
              child: Center(
                child: Text('还没有照片，快去添加第一张吧'),
              ),
            ),
          );
        }
        // SliverGrid 实现懒加载，大量照片时只渲染可见项
        return SliverGrid.builder(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 110 / 130,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            // 统一使用设计令牌中的封面渐变（音乐封面同源）
            final gradient = AppColors
                .coverGradients[
                    photo.gradientIndex % AppColors.coverGradients.length]
                .colors;
            return GestureDetector(
              onTap: () => PhotoViewer.show(
                context,
                photos: photos,
                initialIndex: index,
                onDelete: (photo) {
                  // StreamProvider 会在 Isar 数据变化后自动刷新 UI
                },
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // 兜底渐变背景
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: gradient,
                        ),
                        boxShadow: const [
                          BoxShadow(
                            color: AppColors.shadowCard,
                            blurRadius: 12,
                            offset: Offset(0, 4),
                            spreadRadius: -2,
                          ),
                        ],
                      ),
                    ),
                    // 真实照片（缩略图降采样解码，避免原图内存开销）
                    if (photo.filePath != null)
                      Image.file(
                        File(photo.filePath!),
                        fit: BoxFit.cover,
                        cacheWidth: 400,
                        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                      ),
                    // 日期文字
                    Positioned(
                      left: 8,
                      bottom: 8,
                      child: Text(
                        _formatPhotoDate(photo.date),
                        style: AppTextStyles.caption.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
      loading: () => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
      ),
      error: (_, __) => const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 48),
          child: Center(child: Text('加载失败')),
        ),
      ),
    );
  }

  String _formatPhotoDate(DateTime date) {
    return '${date.month}月${date.day}日';
  }
}
