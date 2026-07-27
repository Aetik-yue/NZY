import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/album_photo.dart';
import '../../../data/providers/data_providers.dart';

/// 相册时间轴页
///
/// 功能：
/// - 按拍摄时间（年-月）自动分组，降序排列（最新在前）
/// - 左侧时间轴轨道：圆点 + 竖线 + 年月标签
/// - 右侧：该月照片缩略图网格（2 列）
/// - 顶部悬浮时间节点导航条：点击快速跳转到对应分组
/// - 滚动时自动高亮当前可见分组
/// - 关键节点（纪念日所在月）特殊标记
class PhotoTimelinePage extends ConsumerStatefulWidget {
  const PhotoTimelinePage({super.key});

  @override
  ConsumerState<PhotoTimelinePage> createState() => _PhotoTimelinePageState();
}

class _PhotoTimelinePageState extends ConsumerState<PhotoTimelinePage> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _sectionKeys = [];
  int _currentIndex = 0;

  /// 顶部导航条 + AppBar 的预估高度，用于滚动高亮判断
  static const double _topThreshold = 140;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  /// 同步 section keys 数量（在 build 的数据就绪回调中调用）
  void _syncSectionKeys(int groupCount) {
    while (_sectionKeys.length < groupCount) {
      _sectionKeys.add(GlobalKey());
    }
    while (_sectionKeys.length > groupCount) {
      _sectionKeys.removeLast();
    }
  }

  /// 滚动时计算当前高亮的分组
  void _onScroll() {
    if (_sectionKeys.isEmpty) return;
    for (int i = 0; i < _sectionKeys.length; i++) {
      final ctx = _sectionKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final pos = box.localToGlobal(Offset.zero);
      // 找到第一个顶部 >= 阈值 的下一个，则当前是 i-1
      if (pos.dy > _topThreshold) {
        final target = i > 0 ? i - 1 : 0;
        if (_currentIndex != target) {
          setState(() => _currentIndex = target);
        }
        return;
      }
    }
    // 滚到底部，高亮最后一个
    final last = _sectionKeys.length - 1;
    if (_currentIndex != last && last >= 0) {
      setState(() => _currentIndex = last);
    }
  }

  /// 点击导航节点跳转到对应分组
  void _jumpTo(int index) {
    if (index < 0 || index >= _sectionKeys.length) return;
    final ctx = _sectionKeys[index].currentContext;
    if (ctx == null) return;
    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.0,
    );
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final groupsAsync = ref.watch(groupedAlbumPhotosProvider);
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final annivMonth = settings?.togetherSince.month;
    final annivDay = settings?.togetherSince.day;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        child: Column(
          children: [
            // 顶部栏
            _TopBar(onBack: () => Navigator.of(context).pop()),
            // 时间节点导航条
            groupsAsync.when(
              data: (groups) => groups.isEmpty
                  ? const SizedBox(height: 0)
                  : _TimelineNavStrip(
                      groups: groups,
                      currentIndex: _currentIndex,
                      onTap: _jumpTo,
                      annivMonth: annivMonth,
                    ),
              loading: () => const SizedBox(
                height: 44,
                child: Center(
                  child: SizedBox(
                    width: 16, height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              ),
              error: (_, __) => const SizedBox(height: 44),
            ),
            // 主体时间轴
            Expanded(
              child: groupsAsync.when(
                data: (groups) {
                  if (groups.isEmpty) {
                    return const _EmptyState();
                  }
                  // 同步 keys 数量
                  _syncSectionKeys(groups.length);
                  return SingleChildScrollView(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                    child: Column(
                      children: [
                        for (int i = 0; i < groups.length; i++)
                          _TimelineSection(
                            key: _sectionKeys[i],
                            group: groups[i],
                            isHighlight: groups[i].isHighlight(annivMonth),
                            annivMonth: annivMonth,
                            annivDay: annivDay,
                            isLast: i == groups.length - 1,
                          ),
                      ],
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('加载失败：$e')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 顶部栏
// ─────────────────────────────────────────────
class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 20, 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new, size: 20),
            color: AppColors.textPrimary,
            onPressed: onBack,
          ),
          Text('时光相册', style: AppTextStyles.titleLarge),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.accentPinkSoft,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '时间轴',
              style: AppTextStyles.label.copyWith(
                color: AppColors.accentRose,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 顶部时间节点导航条
// ─────────────────────────────────────────────
class _TimelineNavStrip extends StatelessWidget {
  final List<PhotoGroup> groups;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int? annivMonth;

  const _TimelineNavStrip({
    required this.groups,
    required this.currentIndex,
    required this.onTap,
    required this.annivMonth,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 12,
            offset: Offset(0, 2),
            spreadRadius: -2,
          ),
        ],
      ),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final g = groups[index];
          final isActive = index == currentIndex;
          final isHighlight = g.isHighlight(annivMonth);
          return GestureDetector(
            onTap: () => onTap(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: isActive ? AppColors.pinkButtonGradient : null,
                color: isActive ? null : AppColors.bgBlush,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (isHighlight) ...[
                    Icon(
                      Icons.favorite,
                      size: 10,
                      color: isActive
                          ? Colors.white
                          : AppColors.accentRose,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    g.shortLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: isActive
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontWeight:
                          isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────
// 时间轴单个分组 section
// ─────────────────────────────────────────────
class _TimelineSection extends StatelessWidget {
  final PhotoGroup group;
  final bool isHighlight;
  final int? annivMonth;
  final int? annivDay;
  final bool isLast;

  const _TimelineSection({
    super.key,
    required this.group,
    required this.isHighlight,
    required this.annivMonth,
    required this.annivDay,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 左侧时间轴轨道
          _TimelineTrack(
            group: group,
            isHighlight: isHighlight,
            isLast: isLast,
          ),
          const SizedBox(width: 14),
          // 右侧照片内容
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 分组标题
                  Row(
                    children: [
                      Text(
                        group.label,
                        style: AppTextStyles.titleSmall.copyWith(fontSize: 16),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${group.photos.length} 张',
                        style: AppTextStyles.label,
                      ),
                      if (isHighlight) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.accentRose.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.favorite,
                                  size: 10, color: AppColors.accentRose),
                              const SizedBox(width: 3),
                              Text(
                                '纪念日',
                                style: AppTextStyles.label.copyWith(
                                  color: AppColors.accentRose,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 10),
                  // 照片网格（2 列）
                  _PhotoGrid(photos: group.photos),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 左侧时间轴轨道（圆点 + 竖线 + 年标签）
class _TimelineTrack extends StatelessWidget {
  final PhotoGroup group;
  final bool isHighlight;
  final bool isLast;

  const _TimelineTrack({
    required this.group,
    required this.isHighlight,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      child: Column(
        children: [
          // 圆点
          Container(
            width: isHighlight ? 16 : 12,
            height: isHighlight ? 16 : 12,
            decoration: BoxDecoration(
              gradient: isHighlight
                  ? AppColors.pinkButtonGradient
                  : null,
              color: isHighlight ? null : AppColors.accentPink,
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white,
                width: isHighlight ? 3 : 2,
              ),
              boxShadow: isHighlight
                  ? [
                      BoxShadow(
                        color: AppColors.accentRose.withValues(alpha: 0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ]
                  : null,
            ),
          ),
          // 竖线（最后一个分组不显示）
          if (!isLast)
            Expanded(
              child: Container(
                width: 2,
                decoration: BoxDecoration(
                  color: AppColors.accentPinkSoft.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 照片网格（2 列）
class _PhotoGrid extends StatelessWidget {
  final List<AlbumPhoto> photos;
  const _PhotoGrid({required this.photos});

  static const _gradients = [
    [Color(0xFFFFBFD0), Color(0xFFFF8FB1)],
    [Color(0xFFFFD1BF), Color(0xFFFFB5A1)],
    [Color(0xFFFFB5CC), Color(0xFFFFD4E0)],
    [Color(0xFFFFBFCC), Color(0xFFFFA1B5)],
    [Color(0xFFFFE0D4), Color(0xFFFFB5CC)],
    [Color(0xFFFF8FB1), Color(0xFFFF6B9D)],
  ];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const spacing = 8.0;
        final width = (constraints.maxWidth - spacing) / 2;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final photo in photos)
              SizedBox(
                width: width,
                child: _PhotoThumb(
                  photo: photo,
                  gradient: _gradients[photo.gradientIndex % _gradients.length],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 单张照片缩略图
class _PhotoThumb extends StatelessWidget {
  final AlbumPhoto photo;
  final List<Color> gradient;

  const _PhotoThumb({required this.photo, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1 / 1.1,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
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
                    blurRadius: 10,
                    offset: Offset(0, 3),
                    spreadRadius: -2,
                  ),
                ],
              ),
            ),
            // 真实照片
            if (photo.filePath != null)
              Image.file(
                File(photo.filePath!),
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const SizedBox.shrink(),
              ),
            // 日期文字
            Positioned(
              left: 8,
              bottom: 8,
              child: Text(
                _formatDate(photo.date),
                style: AppTextStyles.label.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime d) => '${d.month}.${d.day}';
}

// ─────────────────────────────────────────────
// 空状态
// ─────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.photo_library_outlined,
              size: 64,
              color: AppColors.accentPinkSoft,
            ),
            const SizedBox(height: 16),
            Text('还没有照片', style: AppTextStyles.titleSmall),
            const SizedBox(height: 6),
            Text(
              '添加照片后，时间轴会自动按时间分组展示',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
