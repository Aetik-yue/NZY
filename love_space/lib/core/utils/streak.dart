/// 计算连续打卡天数
///
/// 以「今天」为锚点回溯；今天未打卡时以「昨天」为锚点，
/// 避免早上还没打卡就把 128 天的连续记录打回 0。
/// [today] 可注入，便于测试。
int computeStreak(List<DateTime> dates, {DateTime? today}) {
  final set = dates.map((d) => DateTime(d.year, d.month, d.day)).toSet();

  final now = today ?? DateTime.now();
  final anchor = DateTime(now.year, now.month, now.day);

  // 今天没打卡则从昨天开始回溯（保住已积累的连续天数）
  var day =
      set.contains(anchor) ? anchor : anchor.subtract(const Duration(days: 1));

  var streak = 0;
  while (set.contains(day)) {
    streak++;
    day = day.subtract(const Duration(days: 1));
  }
  return streak;
}
