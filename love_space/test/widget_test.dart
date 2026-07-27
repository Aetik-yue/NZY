// 冒烟测试：验证应用能正常构建并渲染首页
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:love_space/app/app.dart';
import 'package:love_space/data/providers/data_providers.dart';
import 'package:love_space/data/models/timeline_event.dart';
import 'package:love_space/data/models/app_settings.dart';
import 'package:love_space/data/models/reader_settings.dart';
import 'package:love_space/core/utils/date_utils.dart';

void main() {
  testWidgets('App renders home page smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // 问候语
          greetingProvider.overrideWithValue('早上好，亲爱的'),
          // 在一起天数
          daysTogetherProvider.overrideWithValue(365),
          // 连续打卡天数
          checkinStreakProvider.overrideWithValue(128),
          // 时间轴事件
          timelineEventsProvider.overrideWith(
            (ref) => Stream.value([
              TimelineEvent()
                ..date = DateTime(2024, 5, 20)
                ..title = '表白纪念日'
                ..description = '那天下着小雨'
                ..dotColorValue = 0xFFFF6B9D,
            ]),
          ),
          // 相册照片数量
          photoCountProvider.overrideWithValue(128),
          // 相册照片
          allPhotosTypedProvider.overrideWith((ref) => Stream.value([])),
          // 愿望列表
          wishesProvider.overrideWith((ref) => Stream.value([])),
          // 愿望统计
          wishStatsProvider.overrideWithValue(
            const WishStats(done: 8, total: 32),
          ),
          // 打卡记录
          checkinsProvider.overrideWith((ref) => Stream.value([])),
          // 应用设置
          appSettingsProvider.overrideWith(
            (ref) => Stream.value(AppSettings()
              ..partner1Name = '小桃'
              ..partner2Name = '阿树'
              ..togetherSince = DateUtilsX.today().subtract(
                const Duration(days: 365),
              )
              ..memoCount = 86),
          ),
          // 书架小说
          novelsProvider.overrideWith((ref) => Stream.value([])),
          // 小说章节（family）
          chaptersProvider.overrideWith(
            (ref, novelId) => Stream.value([]),
          ),
          // 阅读设置
          readerSettingsProvider.overrideWith(
            (ref) => Stream.value(ReaderSettings()
              ..fontSize = 18
              ..lineHeight = 1.6
              ..pageMode = 0
              ..bgTheme = 0
              ..keepScreenOn = true),
          ),
        ],
        child: const LoveSpaceApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 验证首页问候语存在
    expect(find.text('早上好，亲爱的'), findsOneWidget);
    // 验证底部导航 Tab 标签存在
    expect(find.text('时光'), findsWidgets);
    expect(find.text('相册'), findsWidgets);
  });
}
