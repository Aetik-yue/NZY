import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../data/providers/data_providers.dart';
import '../../../shared/widgets/pill_nav_bar.dart';

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
class _GreetingHeader extends ConsumerWidget {
  const _GreetingHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final greeting = ref.watch(greetingProvider);
    final days = ref.watch(daysTogetherProvider);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting, style: AppTextStyles.titleLarge),
            const SizedBox(height: 4),
            Text('今天是你们相伴的第 $days 天', style: AppTextStyles.caption),
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

/// 根据在一起天数生成 Hero 卡片副标题
String _heroSubtitle(int days) {
  if (days <= 0) return '记录我们的每一个瞬间';
  if (days < 30) return '爱正在悄然生长';
  if (days < 100) return '百日相伴，温暖如初';
  if (days < 365) return '爱正在茁壮成长';
  if (days == 365) return '满一周年的爱，未来继续同行';
  return '超越一年的爱，历久弥新';
}

/// 纪念日主卡片（渐变粉 + 装饰爱心）
class _AnniversaryHeroCard extends ConsumerWidget {
  const _AnniversaryHeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(daysTogetherProvider);
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
                  Text('$days', style: AppTextStyles.heroNumber),
                  const SizedBox(width: 4),
                  Text('天', style: AppTextStyles.onPink.copyWith(
                    fontSize: 20, fontWeight: FontWeight.w700,
                  )),
                ],
              ),
              const SizedBox(height: 6),
              Text(_heroSubtitle(days),
                style: AppTextStyles.onPink.copyWith(fontSize: 13).copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                )),
            ],
          ),
        ],
      ),
    );
  }
}

/// 今日打卡卡
class _CheckinCard extends ConsumerWidget {
  const _CheckinCard();

  Future<void> _handleCheckin(BuildContext context, WidgetRef ref) async {
    final repository = ref.read(checkinRepositoryProvider);
    final hasChecked = await repository.hasCheckedInToday();
    if (!context.mounted) return;

    if (hasChecked) {
      AppSnackbar.show(context, '今天已经打卡过了哦 💕');
      return;
    }

    await repository.checkInToday();
    if (context.mounted) {
      AppSnackbar.show(context, '打卡成功！连续加油 💪');
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final streak = ref.watch(checkinStreakProvider);
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
              Text('连续打卡 $streak 天，继续加油', style: AppTextStyles.caption),
            ],
          ),
          // 心形打卡按钮
          GestureDetector(
            onTap: () => _handleCheckin(context, ref),
            child: Container(
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
          ),
        ],
      ),
    );
  }
}

/// 快捷功能入口（相册/愿望/音乐/小说）
class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      _QuickAction(
        icon: Icons.photo_library_rounded,
        label: '相册',
        bg: AppColors.accentPinkSoft,
        onTap: () => ref.read(currentTabProvider.notifier).state = NavTab.album,
      ),
      _QuickAction(
        icon: Icons.star_rounded,
        label: '愿望清单',
        bg: AppColors.accentPeach,
        onTap: () => ref.read(currentTabProvider.notifier).state = NavTab.wishes,
      ),
      _QuickAction(
        icon: Icons.music_note_rounded,
        label: '音乐',
        bg: AppColors.accentPinkSoft,
        onTap: () => AppSnackbar.show(context, '即将上线 🎵'),
      ),
      _QuickAction(
        icon: Icons.menu_book_rounded,
        label: '小说',
        bg: AppColors.accentPinkSoft,
        onTap: () => ref.read(currentTabProvider.notifier).state = NavTab.novel,
      ),
    ];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: actions
          .map((a) => SizedBox(
                width: 76,
                child: GestureDetector(
                  onTap: a.onTap,
                  behavior: HitTestBehavior.opaque,
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
  final VoidCallback onTap;

  const _QuickAction({
    required this.icon,
    required this.label,
    required this.bg,
    required this.onTap,
  });
}

/// 恋爱时间轴区块
class _TimelineSection extends ConsumerWidget {
  const _TimelineSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventsAsync = ref.watch(timelineEventsProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeader(
          title: '我们的时光',
          actionText: '全部',
          onAction: () => AppSnackbar.show(context, '即将上线 📅'),
        ),
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
          child: eventsAsync.when(
            data: (events) {
              if (events.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('还没有时光记录，快去添加第一个吧'),
                );
              }
              return Column(
                children: [
                  for (var i = 0; i < events.length; i++) ...[
                    if (i > 0) const SizedBox(height: 18),
                    _TimelineItem(
                      date: _formatDate(events[i].date),
                      title: events[i].title,
                      desc: events[i].description,
                      dotColor: Color(events[i].dotColorValue),
                      showLine: i < events.length - 1,
                      onDelete: () async {
                        final confirmed = await showConfirmDeleteDialog(
                          context,
                          content: '确定要删除这条时光记录吗？',
                        );
                        if (confirmed && context.mounted) {
                          final eventToDelete = events[i];
                          await ref.read(timelineRepositoryProvider).delete(events[i].id);
                          if (context.mounted) {
                            AppSnackbar.showUndo(context, '时光已删除', () async {
                              await ref.read(timelineRepositoryProvider).add(eventToDelete);
                            });
                          }
                        }
                      },
                    ),
                  ],
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (_, __) => const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text('加载失败'),
            ),
          ),
        ),
      ],
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}.${date.month.toString().padLeft(2, '0')}.${date.day.toString().padLeft(2, '0')}';
  }
}

class _TimelineItem extends StatelessWidget {
  final String date;
  final String title;
  final String desc;
  final Color dotColor;
  final bool showLine;
  final VoidCallback? onDelete;

  const _TimelineItem({
    required this.date,
    required this.title,
    required this.desc,
    required this.dotColor,
    required this.showLine,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onDelete,
      child: Row(
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
    ),
    );
  }
}
