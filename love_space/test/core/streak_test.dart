// computeStreak 单元测试（纯 Dart，无 Isar 依赖，任何环境都可运行）
import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/core/utils/streak.dart';

void main() {
  final day0 = DateTime(2026, 8, 1);

  test('今天已打卡：从今天回溯连续天数', () {
    final dates = [
      day0,
      day0.subtract(const Duration(days: 1)),
      day0.subtract(const Duration(days: 2)),
    ];
    expect(computeStreak(dates, today: day0), 3);
  });

  test('今天未打卡但昨天连续：以昨天为锚点，保住连续天数', () {
    final dates = [
      day0.subtract(const Duration(days: 1)),
      day0.subtract(const Duration(days: 2)),
    ];
    expect(computeStreak(dates, today: day0), 2);
  });

  test('断档 2 天以上：返回 0', () {
    final dates = [
      day0.subtract(const Duration(days: 3)),
      day0.subtract(const Duration(days: 4)),
    ];
    expect(computeStreak(dates, today: day0), 0);
  });

  test('空列表：返回 0', () {
    expect(computeStreak([], today: day0), 0);
  });

  test('时间部分被忽略：同一天任意时刻视为同一天', () {
    final morning = DateTime(2026, 8, 1, 6, 30);
    final night = DateTime(2026, 7, 31, 23, 59);
    expect(computeStreak([morning, night], today: day0), 2);
  });
}
