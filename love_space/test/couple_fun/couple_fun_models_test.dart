import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/features/couple_fun/models/daily_fortune.dart';
import 'package:love_space/features/couple_fun/models/love_quiz.dart';

void main() {
  group('love quiz', () {
    test('题库选项完整且数量一致', () {
      expect(loveQuizQuestions, hasLength(8));
      for (final question in loveQuizQuestions) {
        expect(question.options, hasLength(4));
      }
    });

    test('完全相同答案得到满分', () {
      final result = scoreLoveQuiz(
        [0, 1, 2, 3, 0, 1, 2, 3],
        [0, 1, 2, 3, 0, 1, 2, 3],
      );

      expect(result.matches, 8);
      expect(result.percentage, 100);
      expect(result.title, '心有灵犀');
    });

    test('只按相同选项计分', () {
      final result = scoreLoveQuiz([0, 1, 2, 3], [0, 2, 2, 0]);

      expect(result.matches, 2);
      expect(result.percentage, 50);
    });

    test('双方答题数不一致时拒绝计算', () {
      expect(() => scoreLoveQuiz([0, 1], [0]), throwsArgumentError);
      expect(() => scoreLoveQuiz([], []), throwsArgumentError);
    });
  });

  group('daily fortune', () {
    test('同一情侣同一天结果稳定', () {
      final first = drawDailyFortune(DateTime(2026, 8, 25), '越|名');
      final second = drawDailyFortune(DateTime(2026, 8, 25), '越|名');

      expect(second.fortune.title, first.fortune.title);
      expect(second.temperature, first.temperature);
      expect(second.luckyMoment, first.luckyMoment);
    });

    test('缘分温度始终位于展示区间', () {
      for (int day = 1; day <= 31; day++) {
        final draw = drawDailyFortune(DateTime(2026, 8, day), '越|名');
        expect(draw.temperature, inInclusiveRange(80, 100));
      }
    });

    test('连续日期能产生多种签文', () {
      final titles = <String>{};
      for (int day = 1; day <= 20; day++) {
        titles.add(
          drawDailyFortune(DateTime(2026, 8, day), '越|名').fortune.title,
        );
      }
      expect(titles.length, greaterThan(1));
    });
  });
}
