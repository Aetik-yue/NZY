import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/anniversary_utils.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/check_in.dart';
import '../../../shared/widgets/section_header.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../data/providers/data_providers.dart';
import '../../../shared/widgets/pill_nav_bar.dart';
import '../../anniversary/presentation/anniversary_page.dart';
import '../../music/presentation/music_player_page.dart';
import '../../pomodoro/presentation/pomodoro_page.dart';
import '../../profile/presentation/all_features_page.dart';
import 'widgets/add_timeline_sheet.dart';
import 'widgets/timeline_detail_sheet.dart';
import 'checkin_history_page.dart';
import 'timeline_all_page.dart';

/// 首页 · 时光
/// 还原设计稿：问候区 → 纪念日主卡片 → 今日打卡 → 快捷入口 → 时间轴
class HomePage extends ConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _GreetingHeader(),
          SizedBox(height: 20),
          _AnniversaryHeroCard(),
          SizedBox(height: 14),
          _NextAnniversaryCard(),
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
    // 隐私开关：隐藏在一起天数
    final hideDays = ref.watch(appSettingsProvider).valueOrNull?.hideDaysTogether ?? false;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(greeting, style: AppTextStyles.titleLarge),
            const SizedBox(height: 4),
            Text(hideDays ? '今天也是爱你们的一天 💕' : '今天是你们相伴的第 $days 天',
                style: AppTextStyles.caption),
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
            child: _Avatar(gradient: AppColors.avatarGradients[0]),
          ),
          // 我的头像（左）
          _Avatar(gradient: AppColors.avatarGradients[1]),
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

/// 纪念日主卡片（渐变粉 + 装饰爱心），点击进入纪念日管理
class _AnniversaryHeroCard extends ConsumerWidget {
  const _AnniversaryHeroCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(daysTogetherProvider);
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AnniversaryPage()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppColors.heroGradient,
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowPinkHero,
              blurRadius: 32,
              offset: Offset(0, 12),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Stack(
          children: [
            // 装饰爱心（右上角）
            const Positioned(
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
                    Text('天',
                        style: AppTextStyles.onPink.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
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
            // 管理入口提示
            Positioned(
              right: 14,
              bottom: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('纪念日',
                      style: AppTextStyles.onPink.copyWith(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      )),
                  const Icon(Icons.chevron_right_rounded,
                      size: 16, color: Colors.white),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// 下一个纪念日倒数卡（点击进入纪念日管理）
class _NextAnniversaryCard extends ConsumerWidget {
  const _NextAnniversaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final next = ref.watch(nextAnniversaryProvider);
    final upcoming = ref.watch(upcomingAnniversaryProvider);

    // 无纪念日：引导添加
    if (next == null) {
      return GestureDetector(
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AnniversaryPage()),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
            border: Border.all(color: AppColors.borderSoft),
          ),
          child: Row(
            children: [
              const Icon(Icons.favorite_border_rounded,
                  size: 18, color: AppColors.accentRose),
              const SizedBox(width: 8),
              Expanded(
                child: Text('添加纪念日，不错过每个特别的日子',
                    style: AppTextStyles.bodySmall),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 18, color: AppColors.textTertiary),
            ],
          ),
        ),
      );
    }

    // 即将到来（7 天内）用强调样式
    final days = AnniversaryUtils.daysUntil(next.date, DateUtilsX.today());
    final isUpcoming = upcoming != null && upcoming.id == next.id;
    final countdown = AnniversaryUtils.countdownText(days);
    final years = AnniversaryUtils.anniversaryYearsOf(next.date, DateUtilsX.today());

    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AnniversaryPage()),
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: isUpcoming ? AppColors.pinkButtonGradient : null,
          color: isUpcoming ? null : AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          border: isUpcoming
              ? null
              : Border.all(color: AppColors.borderSoft),
          boxShadow: isUpcoming
              ? const [
                  BoxShadow(
                    color: AppColors.shadowPinkStrong,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                    spreadRadius: -4,
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            Icon(
              days == 0 ? Icons.celebration_rounded : Icons.favorite_rounded,
              size: 20,
              color: isUpcoming ? Colors.white : AppColors.accentRose,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUpcoming ? '即将到来：${next.title}' : '下一个纪念日：${next.title}',
                    style: (isUpcoming
                            ? AppTextStyles.onPink
                            : AppTextStyles.body)
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    years != null && years > 0 && days != 0
                        ? '$countdown · ${years + 1} 周年'
                        : countdown,
                    style: isUpcoming
                        ? AppTextStyles.onPink.copyWith(fontSize: 12)
                        : AppTextStyles.label,
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
                size: 18,
                color: isUpcoming ? Colors.white : AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

/// 今日打卡卡
class _CheckinCard extends ConsumerStatefulWidget {
  const _CheckinCard();

  @override
  ConsumerState<_CheckinCard> createState() => _CheckinCardState();
}

class _CheckinCardState extends ConsumerState<_CheckinCard> {
  /// 防连点：打卡进行中禁止再次点击
  bool _busy = false;

  bool _isTodayChecked(List<CheckIn> checkins) {
    final today = DateUtilsX.today();
    return checkins.any((c) =>
        c.date.year == today.year &&
        c.date.month == today.month &&
        c.date.day == today.day);
  }

  Future<void> _handleCheckin() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final repository = ref.read(checkinRepositoryProvider);
      if (await repository.hasCheckedInToday()) {
        if (!mounted) return;
        // 已打卡：提供撤销入口
        AppSnackbar.showUndo(context, '今天已经打卡过了 💕', () async {
          final today = DateUtilsX.today();
          final checkins = await repository.getAll();
          final todayCheckin = checkins
              .where((c) =>
                  c.date.year == today.year &&
                  c.date.month == today.month &&
                  c.date.day == today.day)
              .firstOrNull;
          if (todayCheckin != null) {
            await repository.delete(todayCheckin.id);
          }
        });
        return;
      }

      await repository.checkInToday();
      if (!mounted) return;
      AppSnackbar.show(context, '打卡成功！连续加油 💪');
    } catch (e) {
      debugPrint('[HomePage] 打卡失败: $e');
      if (mounted) AppSnackbar.show(context, '打卡失败，请重试');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final streak = ref.watch(checkinStreakProvider);
    final checkinsAsync = ref.watch(checkinsProvider);
    final checkedToday = checkinsAsync.valueOrNull != null &&
        _isTodayChecked(checkinsAsync.valueOrNull!);

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
              Text(checkedToday ? '今日已打卡' : '今日说爱你',
                  style: AppTextStyles.titleSmall),
              const SizedBox(height: 4),
              // 点击查看打卡历史
              GestureDetector(
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const CheckinHistoryPage()),
                ),
                child: Text('连续打卡 $streak 天，点击查看历史 ›',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.accentRose,
                    )),
              ),
            ],
          ),
          // 打卡按钮
          GestureDetector(
            onTap: _busy ? null : _handleCheckin,
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                gradient: checkedToday
                    ? null
                    : AppColors.pinkButtonGradient,
                color: checkedToday ? AppColors.bgCard : null,
                shape: BoxShape.circle,
                border: checkedToday
                    ? Border.all(color: AppColors.accentRose, width: 2)
                    : null,
                boxShadow: const [
                  BoxShadow(
                    color: AppColors.shadowPinkDeep,
                    blurRadius: 16,
                    offset: Offset(0, 6),
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: _busy
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.accentRose,
                      ),
                    )
                  : Icon(
                      checkedToday ? Icons.check_rounded : Icons.favorite,
                      color: checkedToday
                          ? AppColors.accentRose
                          : Colors.white,
                      size: 28,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// 快捷功能入口（番茄钟/愿望/音乐/小说/纪念日/更多）
///
/// 横向可滚动宫格：新功能只需在 [_QuickActions.build] 的列表里加一项，
/// 无需改动 Tab 结构。
class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      _QuickAction(
        icon: Icons.timer_rounded,
        label: '番茄钟',
        bg: AppColors.accentPinkSoft,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const PomodoroPage()),
        ),
      ),
      _QuickAction(
        icon: Icons.star_rounded,
        label: '愿望清单',
        bg: AppColors.accentPeach,
        onTap: () =>
            ref.read(currentTabProvider.notifier).state = NavTab.wishes,
      ),
      _QuickAction(
        icon: Icons.music_note_rounded,
        label: '音乐',
        bg: AppColors.accentPinkSoft,
        onTap: () => MusicPlayerPage.show(context),
      ),
      _QuickAction(
        icon: Icons.menu_book_rounded,
        label: '小说',
        bg: AppColors.accentPinkSoft,
        onTap: () => ref.read(currentTabProvider.notifier).state = NavTab.novel,
      ),
      _QuickAction(
        icon: Icons.favorite_rounded,
        label: '纪念日',
        bg: AppColors.accentPinkSoft,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AnniversaryPage()),
        ),
      ),
      // 「更多」固定收尾：跳转全部功能页，承载后续新增的低频功能
      _QuickAction(
        icon: Icons.apps_rounded,
        label: '全部功能',
        bg: AppColors.bgBlush,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AllFeaturesPage()),
        ),
      ),
    ];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: actions
            .map((a) => Padding(
                  padding: const EdgeInsets.only(right: 18),
                  child: SizedBox(
                    width: 64,
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
                              borderRadius:
                                  BorderRadius.circular(AppColors.radiusMd),
                            ),
                            child: Icon(a.icon,
                                color: AppColors.accentRose, size: 26),
                          ),
                          const SizedBox(height: 8),
                          Text(a.label,
                              style: AppTextStyles.caption,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                  ),
                ))
            .toList(),
      ),
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
          // 跳转全量时光线页（按年月分组）
          onAction: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const TimelineAllPage()),
          ),
          // 添加入口（表单此前为死代码，无任何调用点）
          trailing: IconButton(
            icon: const Icon(Icons.add_circle_rounded,
                color: AppColors.accentRose),
            tooltip: '添加时光',
            onPressed: () => AddTimelineSheet.show(context),
          ),
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
                // 空状态：友好提示 + 操作引导（规范 3.4）
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Column(
                    children: [
                      const Text('还没有时光记录'),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => AddTimelineSheet.show(context),
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.accentRose,
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusMd),
                          ),
                        ),
                        child: const Text('添加第一个'),
                      ),
                    ],
                  ),
                );
              }
              // 首页只展示最新 3 条，其余进全量页
              final visible =
                  events.length > 3 ? events.sublist(0, 3) : events;
              return Column(
                children: [
                  for (var i = 0; i < visible.length; i++) ...[
                    if (i > 0) const SizedBox(height: 18),
                    _TimelineItem(
                      date: _formatDate(visible[i].date),
                      title: visible[i].title,
                      desc: visible[i].description,
                      dotColor: Color(visible[i].dotColorValue),
                      showLine: i < visible.length - 1,
                      onTap: () => TimelineDetailSheet.show(
                        context,
                        event: visible[i],
                      ),
                      onEdit: () =>
                          AddTimelineSheet.show(context, initial: visible[i]),
                      onDelete: () async {
                        final confirmed = await showConfirmDeleteDialog(
                          context,
                          content: '确定要删除这条时光记录吗？',
                        );
                        if (!confirmed || !context.mounted) return;
                        try {
                          final eventToDelete = visible[i];
                          await ref
                              .read(timelineRepositoryProvider)
                              .delete(eventToDelete.id);
                          if (!context.mounted) return;
                          AppSnackbar.showUndo(context, '时光已删除', () async {
                            try {
                              await ref
                                  .read(timelineRepositoryProvider)
                                  .add(eventToDelete);
                            } catch (e) {
                              debugPrint('[HomePage] 撤销删除失败: $e');
                            }
                          });
                        } catch (e) {
                          debugPrint('[HomePage] 删除失败: $e');
                          if (context.mounted) {
                            AppSnackbar.show(context, '删除失败，请重试');
                          }
                        }
                      },
                    ),
                  ],
                  if (events.length > visible.length) ...[
                    const SizedBox(height: 12),
                    Center(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const TimelineAllPage()),
                        ),
                        child: Text(
                          '查看全部 ${events.length} 条',
                          style: AppTextStyles.caption
                              .copyWith(color: AppColors.accentRose),
                        ),
                      ),
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
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _TimelineItem({
    required this.date,
    required this.title,
    required this.desc,
    required this.dotColor,
    required this.showLine,
    this.onTap,
    this.onEdit,
    this.onDelete,
  });

  /// 长按弹操作单（编辑 / 删除）
  void _showActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded,
                  color: AppColors.textSecondary),
              title: const Text('编辑'),
              onTap: () {
                Navigator.of(context).pop();
                onEdit?.call();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.accentRose),
              title: const Text('删除'),
              onTap: () {
                Navigator.of(context).pop();
                onDelete?.call();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete == null && onEdit == null
          ? null
          : () => _showActions(context),
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
                  decoration:
                      BoxDecoration(color: dotColor, shape: BoxShape.circle),
                ),
                if (showLine)
                  Container(
                      width: 2, height: 36, color: AppColors.accentPinkSoft),
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
                Text(title,
                    style: AppTextStyles.titleSmall.copyWith(fontSize: 15)),
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
