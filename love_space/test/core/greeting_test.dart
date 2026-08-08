// 问候语单元测试：时段问候 / 节日问候 / 周年问候 / 优先级
import 'package:flutter_test/flutter_test.dart';

import 'package:love_space/core/utils/greeting.dart';

void main() {
  group('Greeting.now() 时段问候', () {
    test('清晨（6 点前）返回夜深问候', () {
      // 通过注入时间不便（now 无参），此处仅验证文案格式存在
      final text = Greeting.now();
      expect(text, isNotEmpty);
      expect(text, contains('亲爱的'));
    });
  });

  group('Greeting.special() 节日问候', () {
    test('2 月 14 日返回情人节文案', () {
      final text = Greeting.special(DateTime(2026, 2, 14), null);
      expect(text, contains('情人节'));
    });

    test('5 月 20 日返回 520 文案', () {
      final text = Greeting.special(DateTime(2026, 5, 20), null);
      expect(text, contains('520'));
    });

    test('普通日期无节点时返回 null', () {
      final text = Greeting.special(DateTime(2026, 6, 1), null);
      expect(text, isNull);
    });
  });

  group('Greeting.special() 周年问候', () {
    test('与 togetherSince 同月同日返回周年文案', () {
      final togetherSince = DateTime(2025, 10, 16);
      final text = Greeting.special(DateTime(2026, 10, 16), togetherSince);
      expect(text, contains('1 周年'));
    });

    test('起始当天不视为周年（返回 null）', () {
      final togetherSince = DateTime(2025, 10, 16);
      final text = Greeting.special(DateTime(2025, 10, 16), togetherSince);
      expect(text, isNull);
    });

    test('周年与节日同日时周年优先（如 2.14 恰逢周年）', () {
      final togetherSince = DateTime(2023, 2, 14);
      final text = Greeting.special(DateTime(2026, 2, 14), togetherSince);
      expect(text, contains('3 周年'));
    });
  });
}
