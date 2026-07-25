/// 日期工具函数
class DateUtilsX {
  /// 计算两个日期之间相差的天数（忽略时间部分）
  static int daysBetween(DateTime a, DateTime b) {
    final d1 = DateTime(a.year, a.month, a.day);
    final d2 = DateTime(b.year, b.month, b.day);
    return d1.difference(d2).inDays;
  }

  /// 返回今天的 00:00:00（去掉时间部分）
  static DateTime today() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }
}
