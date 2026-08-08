import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/album_photo.dart';
import '../../../data/providers/data_providers.dart';
import 'widgets/photo_viewer.dart';

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
  bool _isJumping = false; // 跳转动画期间屏蔽 _onScroll 更新

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

  /// 顶部导航条 + AppBar 的预估高度，用于滚动高亮判断
  static const double _topThreshold = 120;

  /// 滚动时计算当前高亮的分组
  ///
  /// 策略：找到第一个顶部进入阈值区域（刚好在导航条下方）的 section，
  /// 其前一个 section 即为当前高亮项。
  /// 优化：跳转动画期间（_isJumping=true）不更新，避免与动画竞态。
  void _onScroll() {
    if (_sectionKeys.isEmpty) return;
    // 跳转动画期间不更新高亮，避免与动画竞态
    if (_isJumping) return;

    // 只在可见区域内检测（从当前索引附近开始，减少遍历）
    final viewportHeight = MediaQuery.of(context).size.height;
    for (int i = 0; i < _sectionKeys.length; i++) {
      final ctx = _sectionKeys[i].currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox || !box.attached) continue;
      final pos = box.localToGlobal(Offset.zero);
      // 跳过完全不在视口内的 section
      if (pos.dy > viewportHeight || pos.dy < -200) continue;
      // 找到第一个顶部 >= 阈值的 section，高亮其前一个
      if (pos.dy >= _topThreshold) {
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

    setState(() {
      _isJumping = true;
      _currentIndex = index;
    });

    Scrollable.ensureVisible(
      ctx,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      alignment: 0.0,
    ).whenComplete(() {
      // 动画结束后恢复滚动监听
      if (mounted) setState(() => _isJumping = false);
    });
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
                    width: 16,
                    height: 16,
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
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const Center(child: Text('加载失败')),
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
                      color: isActive ? Colors.white : AppColors.accentRose,
                    ),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    g.shortLabel,
                    style: AppTextStyles.caption.copyWith(
                      color: isActive ? Colors.white : AppColors.textSecondary,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                  // 照片数量角标
                  if (g.photos.length > 1)
                    Text(
                      '${g.photos.length}',
                      style: TextStyle(
                        fontSize: 9,
                        color: isActive
                            ? Colors.white.withValues(alpha: 0.8)
                            : AppColors.textTertiary,
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
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
                          color:
                              AppColors.accentRose.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.favorite,
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
        ],
      ),
    );
  }
}

/// 左侧时间轴轨道（圆点 + 竖线）
///
/// 使用 Stack 定位：圆点顶部居中，竖线从圆点底部延伸到 section 底部。
/// 最后一个分组不显示竖线。
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
    const dotSize = 12.0;
    const dotSizeHighlight = 16.0;
    final size = isHighlight ? dotSizeHighlight : dotSize;
    return SizedBox(
      width: 44,
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          // 竖线：从圆点底部到 section 底部（最后一个分组不显示）
          if (!isLast)
            Positioned(
              top: size,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                width: 2,
                margin: const EdgeInsets.symmetric(horizontal: 21),
                decoration: BoxDecoration(
                  color: AppColors.accentPinkSoft.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ),
          // 圆点
          Container(
            width: size,
            height: size,
            margin: const EdgeInsets.only(top: 4),
            decoration: BoxDecoration(
              gradient: isHighlight ? AppColors.pinkButtonGradient : null,
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
        ],
      ),
    );
  }
}

/// 照片网格（2 列）
class _PhotoGrid extends StatelessWidget {
  final List<AlbumPhoto> photos;
  const _PhotoGrid({required this.photos});

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
            for (var i = 0; i < photos.length; i++)
              SizedBox(
                width: width,
                child: _PhotoThumb(
                  photo: photos[i],
                  gradient: AppColors.coverGradients[photos[i].gradientIndex %
                          AppColors.coverGradients.length]
                      .colors,
                  onTap: () => PhotoViewer.show(
                    context,
                    photos: photos,
                    initialIndex: i,
                    onDelete: (photo) {
                      // 从 Isar 删除后，StreamProvider 会自动刷新 UI
                      // 这里不需要额外操作，但保留回调以便未来扩展
                    },
                  ),
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
  final VoidCallback? onTap;

  const _PhotoThumb({
    required this.photo,
    required this.gradient,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1 / 1.1,
      child: GestureDetector(
        onTap: onTap,
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
            const Icon(
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
