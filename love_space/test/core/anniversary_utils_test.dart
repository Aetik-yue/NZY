// 纪念日计算工具单元测试：倒数 / 即将到来 / 周年 / 文案
import 'package:flutter_test/flutter_test.dart';

import 'package:love_space/core/utils/anniversary_utils.dart';
import 'package:love_space/data/models/anniversary.dart';

Anniversary _item(int month, int day) => Anniversary()
  ..title = '测试纪念日'
  ..date = DateTime(2024, month, day);

void main() {
  group('daysUntil 剩余天数', () {
    test('未来同月同日返回正确天数', () {
      final from = DateTime(2026, 1, 1);
      final gap = AnniversaryUtils.daysUntil(DateTime(2026, 1, 10), from);
      expect(gap, 9);
    });

    test('今年已过则算到明年', () {
      final from = DateTime(2026, 12, 31);
      final gap = AnniversaryUtils.daysUntil(DateTime(2024, 1, 1), from);
      expect(gap, 1); // 2027-01-01
    });

    test('当天返回 0', () {
      final from = DateTime(2026, 3, 5);
      final gap = AnniversaryUtils.daysUntil(DateTime(2024, 3, 5), from);
      expect(gap, 0);
    });
  });

  group('nextFrom 最近的下一个纪念日', () {
    test('从多个纪念日中选出最近的下一个', () {
      final items = [_item(1, 1), _item(5, 20), _item(12, 25)];
      final next = AnniversaryUtils.nextFrom(items, DateTime(2026, 2, 1));
      expect(next, isNotNull);
      expect(next!.date.month, 5);
      expect(next.date.day, 20);
    });

    test('今天是纪念日时优先返回它（剩余 0 天）', () {
      final items = [_item(1, 1), _item(5, 20)];
      final next = AnniversaryUtils.nextFrom(items, DateTime(2026, 5, 20));
      expect(next, isNotNull);
      expect(next!.date.month, 5);
    });

    test('空列表返回 null', () {
      expect(AnniversaryUtils.nextFrom([], DateTime(2026, 1, 1)), isNull);
    });
  });

  group('upcomingWithin 即将到来（7 天内）', () {
    test('7 天内的纪念日被命中', () {
      final items = [_item(1, 1), _item(6, 10)];
      final hit = AnniversaryUtils.upcomingWithin(
        items,
        DateTime(2026, 6, 3),
      );
      expect(hit, isNotNull);
      expect(hit!.date.month, 6);
    });

    test('超过 7 天返回 null', () {
      final items = [_item(1, 1), _item(6, 20)];
      final hit = AnniversaryUtils.upcomingWithin(
        items,
        DateTime(2026, 6, 3),
      );
      expect(hit, isNull);
    });
  });

  group('anniversaryYearsOf 周年数', () {
    test('今年纪念日已过：按已达成周年', () {
      final years = AnniversaryUtils.anniversaryYearsOf(
        DateTime(2024, 3, 1),
        DateTime(2026, 5, 1),
      );
      expect(years, 2);
    });

    test('今年纪念日未到：周年数减一（奔向 N+1 周年）', () {
      final years = AnniversaryUtils.anniversaryYearsOf(
        DateTime(2024, 3, 1),
        DateTime(2026, 2, 1),
      );
      expect(years, 1);
    });

    test('起始当年返回 0', () {
      final years = AnniversaryUtils.anniversaryYearsOf(
        DateTime(2024, 3, 1),
        DateTime(2024, 3, 1),
      );
      expect(years, 0);
    });
  });

  group('countdownText 文案', () {
    test('当天 / 明天 / 还有 N 天', () {
      expect(AnniversaryUtils.countdownText(0), contains('今天'));
      expect(AnniversaryUtils.countdownText(1), contains('明天'));
      expect(AnniversaryUtils.countdownText(9), contains('9 天'));
    });
  });
}
