import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:love_space/core/utils/date_utils.dart';
import 'package:love_space/data/models/app_settings.dart';
import 'package:love_space/data/providers/data_providers.dart';
import 'package:love_space/features/couple_fun/presentation/daily_fortune_page.dart';
import 'package:love_space/features/couple_fun/presentation/love_quiz_page.dart';

void main() {
  Widget buildPage(Widget page) {
    return ProviderScope(
      overrides: [
        appSettingsProvider.overrideWith(
          (ref) => Stream.value(AppSettings()
            ..partner1Name = '小桃'
            ..partner2Name = '阿树'
            ..togetherSince = DateUtilsX.today()),
        ),
      ],
      child: MaterialApp(home: page),
    );
  }

  testWidgets('恋爱测试可从介绍页进入答题', (tester) async {
    await tester.pumpWidget(buildPage(const LoveQuizPage()));
    await tester.pumpAndSettle();

    expect(find.text('默契交换所'), findsOneWidget);
    expect(find.textContaining('小桃 和 阿树'), findsOneWidget);

    await tester.tap(find.text('开始交换答案'));
    await tester.pumpAndSettle();

    expect(find.text('小桃 的答案'), findsOneWidget);
    expect(find.text('1/8'), findsOneWidget);

    await tester.tap(find.text('窝在家里看电影'));
    await tester.pump();
    await tester.tap(find.text('下一题'));
    await tester.pumpAndSettle();

    expect(find.text('2/8'), findsOneWidget);
  });

  testWidgets('缘分签摇签后展示当日签文', (tester) async {
    await tester.pumpWidget(buildPage(const DailyFortunePage()));
    await tester.pumpAndSettle();

    expect(find.text('小桃 × 阿树'), findsOneWidget);
    await tester.tap(find.text('摇一摇'));
    await tester.pumpAndSettle();

    expect(find.text('缘分温度'), findsOneWidget);
    expect(find.text('幸运时刻'), findsOneWidget);
    expect(find.text('今日小行动'), findsOneWidget);
  });
}
