/// 计算连续打卡天数
///
/// 从今天开始往前回溯，统计连续有记录的天数。
/// 如果今天没打卡，则返回 0。
int computeStreak(List<DateTime> dates) {
  final set = dates
      .map((d) => DateTime(d.year, d.month, d.day))
      .toSet();

  final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

  // 今天没打卡，连续天数为 0
  if (!set.contains(today)) return 0;

  var day = today;
  var streak = 0;
  while (set.contains(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}
