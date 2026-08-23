import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/providers/data_providers.dart';

/// 打卡历史月历页（二级页）
///
/// 以月历热力图展示打卡记录：粉色圆点为已打卡日期，
/// 今天带描边。支持上/下月切换。
class CheckinHistoryPage extends ConsumerStatefulWidget {
  const CheckinHistoryPage({super.key});

  @override
  ConsumerState<CheckinHistoryPage> createState() => _CheckinHistoryPageState();
}

class _CheckinHistoryPageState extends ConsumerState<CheckinHistoryPage> {
  late DateTime _displayedMonth;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _displayedMonth = DateTime(now.year, now.month);
  }

  @override
  Widget build(BuildContext context) {
    final streak = ref.watch(checkinStreakProvider);
    final checkinsAsync = ref.watch(checkinsProvider);

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('打卡记录', style: AppTextStyles.titleMedium),
        centerTitle: true,
      ),
      body: checkinsAsync.when(
        data: (checkins) {
          final checkedDates = checkins
              .map((c) => DateTime(c.date.year, c.date.month, c.date.day))
              .toSet();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              // 连续打卡提示卡
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(AppColors.radiusCard),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.local_fire_department_rounded,
                        color: AppColors.accentRose, size: 28),
                    const SizedBox(width: 12),
                    Text('已连续打卡 $streak 天', style: AppTextStyles.titleSmall),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // 月份切换
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left_rounded),
                    onPressed: _prevMonth,
                  ),
                  Text(
                    '${_displayedMonth.year}年${_displayedMonth.month}月',
                    style: AppTextStyles.titleSmall,
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right_rounded),
                    onPressed: _nextMonth,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // 月历
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgCard,
                  borderRadius: BorderRadius.circular(AppColors.radiusCard),
                ),
                child: _buildCalendar(checkedDates),
              ),
              const SizedBox(height: 12),
              Text('每天打卡，让爱有迹可循 💕',
                  style: AppTextStyles.caption, textAlign: TextAlign.center),
            ],
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, __) => const Center(child: Text('加载失败')),
      ),
    );
  }

  void _prevMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month - 1,
      );
    });
  }

  void _nextMonth() {
    setState(() {
      _displayedMonth = DateTime(
        _displayedMonth.year,
        _displayedMonth.month + 1,
      );
    });
  }

  /// 构建月历网格（周一为第一列）
  Widget _buildCalendar(Set<DateTime> checkedDates) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final firstDay = DateTime(_displayedMonth.year, _displayedMonth.month, 1);
    final daysInMonth =
        DateTime(_displayedMonth.year, _displayedMonth.month + 1, 0).day;
    // 周一 = 0 偏移（DateTime.monday = 1）
    final leadingBlanks = firstDay.weekday - 1;

    final weekdayLabels = ['一', '二', '三', '四', '五', '六', '日'];
    final cells = <Widget>[
      for (final label in weekdayLabels)
        Center(
          child: Text(label, style: AppTextStyles.label),
        ),
      for (var i = 0; i < leadingBlanks; i++) const SizedBox.shrink(),
      for (var day = 1; day <= daysInMonth; day++)
        _buildDayCell(
          DateTime(_displayedMonth.year, _displayedMonth.month, day),
          checkedDates,
          today,
        ),
    ];

    return GridView.count(
      crossAxisCount: 7,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 8,
      crossAxisSpacing: 4,
      children: cells,
    );
  }

  Widget _buildDayCell(
    DateTime date,
    Set<DateTime> checkedDates,
    DateTime today,
  ) {
    final checked = checkedDates.contains(date);
    final isToday = date == today;
    return Center(
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: checked ? AppColors.accentRose : Colors.transparent,
          shape: BoxShape.circle,
          border: isToday
              ? Border.all(color: AppColors.accentRose, width: 1.5)
              : null,
        ),
        child: Center(
          child: Text(
            '${date.day}',
            style: AppTextStyles.caption.copyWith(
              color: checked ? Colors.white : AppColors.textPrimary,
              fontWeight:
                  checked || isToday ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}
