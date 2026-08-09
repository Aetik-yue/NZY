import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/anniversary_utils.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/anniversary.dart';

/// 纪念日时间轴单个节点
///
/// 布局（Stack）：
/// - 右侧内容（非定位子项，决定 Stack 高度；底部 24 留白为节点间距）
/// - 左侧圆点（轨道顶部，随节点淡入并从右滑入）
/// - 左侧连接线段（自圆点底部向下生长至节点底部；末节点不绘制）
///
/// 多个节点的线段首尾相接（上一节点底部 = 下一节点圆点顶部），
/// 由外部 [AnimationController] 的 [progress] 驱动各段顺序生长，
/// 拼成「自上而下延伸」的竖线；节点则在各自区间内淡入并从右滑入 20px。
class AnniversaryTimelineItem extends StatelessWidget {
  final Anniversary item;
  final int index;
  final int total;
  final double progress; // 入场动画进度 0..1
  final bool isLast;
  final VoidCallback onTap;

  const AnniversaryTimelineItem({
    super.key,
    required this.item,
    required this.index,
    required this.total,
    required this.progress,
    required this.isLast,
    required this.onTap,
  });

  /// 左轨道宽度（圆点与竖线在其上居中）
  static const double _trackWidth = 44;
  /// 轨道与右侧内容的间距
  static const double _spacer = 12;
  /// 圆点直径
  static const double _dotSize = 16;
  /// 竖线宽度
  static const double _lineWidth = 2;

  /// 节点淡入区间起点：i/n * 0.7
  double get _fadeStart => (index / total) * 0.7;
  /// 节点淡入区间终点：(i+1)/n * 0.7 + 0.3（末节点恰为 1.0）
  double get _fadeEnd => ((index + 1) / total) * 0.7 + 0.3;

  @override
  Widget build(BuildContext context) {
    final opacity = _itemOpacity(progress);
    final dx = 20 * (1 - opacity); // 与淡入同步，从右滑入 20px
    final seg = isLast ? 0.0 : _segmentProgress(progress);

    return Stack(
      children: [
        // 右侧内容（左偏移 = 轨道宽 + 间距 = 56）
        Padding(
          padding: const EdgeInsets.only(left: _trackWidth + _spacer, bottom: 24),
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: _Content(item: item, onTap: onTap),
            ),
          ),
        ),
        // 圆点（在轨道内水平居中：左偏移 = (轨道宽 - 圆点直径) / 2 = 14）
        Positioned(
          left: (_trackWidth - _dotSize) / 2,
          top: 0,
          child: Opacity(
            opacity: opacity,
            child: Transform.translate(
              offset: Offset(dx, 0),
              child: _Dot(color: Color(item.colorValue)),
            ),
          ),
        ),
        // 连接线段（与圆点中心对齐：左偏移 = 轨道宽/2 - 线宽/2 = 21；
        // 自圆点底部 top=16 向下至节点底部）
        if (!isLast)
          Positioned(
            left: _trackWidth / 2 - _lineWidth / 2,
            top: _dotSize,
            bottom: 0,
            width: _lineWidth,
            child: _Connector(progress: seg),
          ),
      ],
    );
  }

  /// 节点淡入进度（0..1，easeOut）
  ///
  /// 在 [_fadeStart, _fadeEnd] 区间内由 0 升至 1；区间外取边界值。
  double _itemOpacity(double p) {
    final t = ((p - _fadeStart) / (_fadeEnd - _fadeStart)).clamp(0.0, 1.0);
    return Curves.easeOut.transform(t);
  }

  /// 本节点连接线段的生长进度（0..1）
  ///
  /// 将整段动画 [0,1] 等分为 (total-1) 段，节点 i 所在线段在第 i 段区间
  /// 内由 0 升至 1。各段首尾相接，拼成连续向下延伸的竖线。
  double _segmentProgress(double p) {
    if (total <= 1) return 0;
    final segDur = 1.0 / (total - 1);
    final start = index * segDur;
    return ((p - start) / segDur).clamp(0.0, 1.0);
  }
}

/// 时间轴圆点（带白色描边与柔光，落在竖线上）
class _Dot extends StatelessWidget {
  final Color color;
  const _Dot({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.35),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
    );
  }
}

/// 节点间连接线段（按 [progress] 从顶部向下生长）
///
/// 用 LayoutBuilder 取线段可用高度，按进度计算实际绘制高度，
/// 避免依赖外部测量；多段拼接即为完整竖线。
class _Connector extends StatelessWidget {
  final double progress; // 本线段生长进度 0..1
  const _Connector({required this.progress});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (_, c) {
        final h = (progress * c.maxHeight).clamp(0.0, c.maxHeight);
        return Align(
          alignment: Alignment.topCenter,
          child: Container(
            width: 2,
            height: h,
            decoration: BoxDecoration(
              color: AppColors.accentPink,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }
}

/// 右侧内容：日期徽章 + 标题 + 倒数 + 备注
class _Content extends StatelessWidget {
  final Anniversary item;
  final VoidCallback onTap;
  const _Content({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final today = DateUtilsX.today();
    final days = AnniversaryUtils.daysUntil(item.date, today);
    final years = AnniversaryUtils.anniversaryYearsOf(item.date, today);

    // 倒数文案：今天 / 明天 / 还有 N 天；非今天且已有周年记录则附「X 周年」
    final String countdown;
    final bool isToday;
    if (days == 0) {
      countdown = '就是今天 🎉';
      isToday = true;
    } else if (days == 1) {
      countdown = '明天就是！';
      isToday = false;
    } else {
      countdown = '还有 $days 天';
      isToday = false;
    }
    final sub = years != null && years > 0 && days != 0
        ? '$countdown · ${years + 1} 周年'
        : countdown;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 日期徽章
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.accentPinkSoft,
                borderRadius: BorderRadius.circular(AppColors.radiusXs),
              ),
              child: Text(
                '${item.date.month}月${item.date.day}日',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.accentRose,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(item.title, style: AppTextStyles.titleSmall),
            const SizedBox(height: 4),
            Text(
              sub,
              style: isToday
                  ? AppTextStyles.caption.copyWith(
                      color: AppColors.accentRose,
                      fontWeight: FontWeight.w600,
                    )
                  : AppTextStyles.caption,
            ),
            if (item.note.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                item.note,
                style: AppTextStyles.label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
