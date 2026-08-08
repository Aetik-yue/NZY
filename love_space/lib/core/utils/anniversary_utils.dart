import '../../data/models/anniversary.dart';

/// 纪念日计算工具
///
/// 纪念日按「月日」年度循环（年份仅作展示），与年份无关。
class AnniversaryUtils {
  AnniversaryUtils._();

  /// 计算距 [from]（当天 00:00）最近的下一个纪念日：
  /// - 今天当天（月日相等）优先返回（剩余 0 天）
  /// - 否则返回从明天起最近的一次
  /// 返回 null 表示无纪念日。
  static Anniversary? nextFrom(List<Anniversary> items, DateTime from) {
    if (items.isEmpty) return null;
    final today = DateTime(from.year, from.month, from.day);
    Anniversary? best;
    var bestGap = 367; // 大于一年，保证有候选
    for (final item in items) {
      final gap = daysUntil(item.date, today);
      if (gap >= 0 && gap < bestGap) {
        bestGap = gap;
        best = item;
      }
    }
    return best;
  }

  /// 距 [from] 最近一次“即将到来”（今天起 0..[withinDays] 天内）的纪念日
  static Anniversary? upcomingWithin(
    List<Anniversary> items,
    DateTime from, {
    int withinDays = 7,
  }) {
    final next = nextFrom(items, from);
    if (next == null) return null;
    final gap = daysUntil(next.date, from);
    return gap <= withinDays ? next : null;
  }

  /// 距 [from]（当天 00:00）下一次纪念日还有几天（0 = 今天就是）
  static int daysUntil(DateTime date, DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    // 今年这一次（月日）
    var thisYear = DateTime(today.year, date.month, date.day);
    if (thisYear.isBefore(today)) {
      // 今年已过，算到明年
      thisYear = DateTime(today.year + 1, date.month, date.day);
    }
    return thisYear.difference(today).inDays;
  }

  /// 下一次纪念日的「周年数」（用于展示文案：今天/明天/还有 N 天/X 周年）
  ///
  /// 返回 null 表示还未到第一次（起始当年，周年概念不适用）。
  static int? anniversaryYearsOf(DateTime date, DateTime from) {
    final today = DateTime(from.year, from.month, from.day);
    final d = DateTime(date.year, date.month, date.day);
    var years = today.year - d.year;
    // 今年纪念日尚未到，周年数减 1（即“第 N 周年”未达成，正在奔向它）
    final thisYear = DateTime(today.year, d.month, d.day);
    if (thisYear.isAfter(today)) {
      years -= 1;
    }
    return years >= 0 ? years : null;
  }

  /// 格式化剩余文案：今天 / 明天 / 还有 N 天
  static String countdownText(int days) {
    if (days == 0) return '就是今天 🎉';
    if (days == 1) return '明天就是！';
    return '还有 $days 天';
  }
}
