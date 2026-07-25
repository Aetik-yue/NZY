import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../shared/widgets/section_header.dart';

/// 首页 · 时光
/// 还原设计稿：问候区 → 纪念日主卡片 → 今日打卡 → 快捷入口 → 时间轴
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: const [
          _GreetingHeader(),
          SizedBox(height: 20),
          _AnniversaryHeroCard(),
          SizedBox(height: 20),
          _CheckinCard(),
          SizedBox(height: 20),
          _QuickActions(),
          SizedBox(height: 20),
          _TimelineSection(),
        ],
      ),
    );
  }
}

/// 顶部问候区
class _GreetingHeader extends StatelessWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('早上好，亲爱的', style: AppTextStyles.titleLarge),
            const SizedBox(height: 4),
            Text('今天是你们相伴的第 365 天', style: AppTextStyles.caption),
          ],
        ),
        const _CoupleAvatars(),
      ],
    );
  }
}

/// 情侣头像组（重叠）
class _CoupleAvatars extends StatelessWidget {
  const _CoupleAvatars();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 68,
      height: 48,
      child: Stack(
        children: [
          // 女友头像（右）
          Positioned(
            left: 24,
            child: _Avatar(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFB5CC), Color(0xFFFF8FB1)],
              ),
            ),
          ),
          // 我的头像（左）
          _Avatar(
            gradient: const LinearGradient(
              colors: [Color(0xFFFFD1BF), Color(0xFFFFA1A1)],
            ),
          ),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Gradient gradient;
  const _Avatar({required this.gradient});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        gradient: gradient,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
      ),
    );
  }
}

/// 纪念日主卡片（渐变粉 + 装饰爱心）
class _AnniversaryHeroCard extends StatelessWidget {
  const _AnniversaryHeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40FF6B8F),
            blurRadius: 32,
            offset: Offset(0, 12),
            spreadRadius: -8,
          ),
        ],
      ),
      child: Stack(
        children: [
          // 装饰爱心（右上角）
          Positioned(
            right: 0,
            top: 0,
            child: Opacity(
              opacity: 0.25,
              child: Icon(Icons.favorite, size: 110, color: Colors.white),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('我们在一起', style: AppTextStyles.onPink.copyWith(fontSize: 15)),
              const SizedBox(height: 6),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text('365', style: AppTextStyles.heroNumber),
                  const SizedBox(width: 4),
                  Text('天', style: AppTextStyles.onPink.copyWith(
                    fontSize: 20, fontWeight: FontWeight.w700,
                  )),
                ],
              ),
              const SizedBox(height: 6),
              Text('满一周年的爱，未来继续同行',
                style: AppTextStyles.onPink.copyWith(fontSize: 13).copyWith(
                  color: Colors.white.withOpacity(0.85),
                )),
            ],
          ),
        ],
      ),
    );
  }
}

/// 今日打卡卡
class _CheckinCard extends StatelessWidget {
  const _CheckinCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 24,
            offset: Offset(0, 6),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('今日说爱你', style: AppTextStyles.titleSmall),
              const SizedBox(height: 4),
              Text('连续打卡 128 天，继续加油', style: AppTextStyles.caption),
            ],
          ),
          // 心形打卡按钮
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: AppColors.pinkButtonGradient,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(
                  color: Color(0x66FF6B9D),
                  blurRadius: 16,
                  offset: Offset(0, 6),
                  spreadRadius: -2,
                ),
              ],
            ),
            child: const Icon(Icons.favorite, color: Colors.white, size: 28),
          ),
        ],
      ),
    );
  }
}

/// 快捷功能入口（相册/愿望/音乐/小说）
class _QuickActions extends StatelessWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context) {
    final actions = [
      _QuickAction(icon: Icons.photo_library_rounded, label: '相册', bg: AppColors.accentPinkSoft),
      _QuickAction(icon: Icons.star_rounded, label: '愿望清单', bg: AppColors.accentPeach),
      _QuickAction(icon: Icons.music_note_rounded, label: '音乐', bg: AppColors.accentPinkSoft),
      _QuickAction(icon: Icons.menu_book_rounded, label: '小说', bg: AppColors.accentPinkSoft),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions
          .map((a) => SizedBox(
                width: 76,
                child: Column(
                  children: [
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: a.bg,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(a.icon, color: AppColors.accentRose, size: 26),
                    ),
                    const SizedBox(height: 8),
                    Text(a.label, style: AppTextStyles.caption),
                  ],
                ),
              ))
          .toList(),
    );
  }
}

class _QuickAction {
  final IconData icon;
  final String label;
  final Color bg;
  const _QuickAction({required this.icon, required this.label, required this.bg});
}

/// 恋爱时间轴区块
class _TimelineSection extends StatelessWidget {
  const _TimelineSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionHeader(title: '我们的时光', actionText: '全部'),
        const SizedBox(height: 14),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
            boxShadow: const [
              BoxShadow(
                color: AppColors.shadowCard,
                blurRadius: 20,
                offset: Offset(0, 4),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            children: const [
              _TimelineItem(
                date: '2024.05.20',
                title: '表白纪念日',
                desc: '那天下着小雨，你说了"我愿意"',
                dotColor: AppColors.accentRose,
                showLine: true,
              ),
              SizedBox(height: 18),
              _TimelineItem(
                date: '2024.08.08',
                title: '第一次旅行',
                desc: '去了海边，一起看了日落与星空',
                dotColor: AppColors.accentPink,
                showLine: false,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _TimelineItem extends StatelessWidget {
  final String date;
  final String title;
  final String desc;
  final Color dotColor;
  final bool showLine;

  const _TimelineItem({
    required this.date,
    required this.title,
    required this.desc,
    required this.dotColor,
    required this.showLine,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 标记列（圆点 + 连线）
        SizedBox(
          width: 16,
          child: Column(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
              ),
              if (showLine)
                Container(width: 2, height: 36, color: AppColors.accentPinkSoft),
            ],
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(date, style: AppTextStyles.dateLabel),
              const SizedBox(height: 3),
              Text(title, style: AppTextStyles.titleSmall.copyWith(fontSize: 15)),
              const SizedBox(height: 3),
              Text(desc, style: AppTextStyles.caption),
            ],
          ),
        ),
      ],
    );
  }
}
