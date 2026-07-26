import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/models/album_photo.dart';
import '../../../features/album/presentation/widgets/add_photo_sheet.dart';
import '../../../features/album/presentation/photo_timeline_page.dart';

/// 相册页
/// 还原设计稿：标题+统计+添加 → 筛选 chip → 九宫格照片
class AlbumPage extends ConsumerWidget {
  const AlbumPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photoCount = ref.watch(photoCountProvider);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部栏：标题 + 添加按钮
          Row(
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
          const SizedBox(height: 16),
          // 筛选 chip 行
          const _FilterChips(),
          const SizedBox(height: 16),
          // 九宫格
          const _PhotoGrid(),
        ],
      ),
    );
  }
}

/// 预设渐变色（与原来保持一致的 6 组）
const _photoGradients = [
  [Color(0xFFFFBFD0), Color(0xFFFF8FB1)],
  [Color(0xFFFFD1BF), Color(0xFFFFB5A1)],
  [Color(0xFFFFB5CC), Color(0xFFFFD4E0)],
  [Color(0xFFFFBFCC), Color(0xFFFFA1B5)],
  [Color(0xFFFFE0D4), Color(0xFFFFB5CC)],
  [Color(0xFFFF8FB1), Color(0xFFFF6B9D)],
];

class _AddButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => AddPhotoSheet.show(context),
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: AppColors.pinkButtonGradient,
          shape: BoxShape.circle,
          boxShadow: const [
            BoxShadow(
              color: Color(0x59FF6B9D),
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
            onTap: () => ref.read(albumFilterProvider.notifier).state = category,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: isActive ? AppColors.pinkButtonGradient : null,
                color: isActive ? null : AppColors.bgCard,
                borderRadius: BorderRadius.circular(16),
                border: isActive
                    ? null
                    : Border.all(color: AppColors.borderSoft),
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
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text('还没有照片，快去添加第一张吧'),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: 6,
            crossAxisSpacing: 6,
            childAspectRatio: 110 / 130,
          ),
          itemCount: photos.length,
          itemBuilder: (context, index) {
            final photo = photos[index];
            final gradient = _photoGradients[photo.gradientIndex % _photoGradients.length];
            return Container(
              padding: const EdgeInsets.only(bottom: 8, left: 8),
              alignment: Alignment.bottomLeft,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: gradient,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowCard,
                    blurRadius: 12,
                    offset: Offset(0, 4),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Text(
                _formatPhotoDate(photo.date),
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('加载失败'),
      ),
    );
  }

  String _formatPhotoDate(DateTime date) {
    return '${date.month}月${date.day}日';
  }
}
