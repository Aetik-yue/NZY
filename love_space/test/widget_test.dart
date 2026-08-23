// 冒烟测试：验证应用能正常构建并渲染首页，且所有 Tab 均不落入错误态
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:love_space/app/app.dart';
import 'package:love_space/data/providers/data_providers.dart';
import 'package:love_space/data/models/timeline_event.dart';
import 'package:love_space/data/models/app_settings.dart';
import 'package:love_space/data/models/pomodoro_settings.dart';
import 'package:love_space/data/models/reader_settings.dart';
import 'package:love_space/core/utils/date_utils.dart';
import 'package:love_space/features/games/breakout/breakout_page.dart';
import 'package:love_space/features/music/providers/audio_backend.dart';
import 'package:love_space/features/music/providers/music_player_provider.dart';
import 'package:love_space/features/music/providers/music_library_provider.dart';
import 'package:love_space/features/pomodoro/presentation/pomodoro_page.dart';
import 'package:love_space/data/sync/sync_providers.dart';
import 'package:love_space/shared/layouts/main_shell.dart';
import 'package:love_space/shared/widgets/pill_nav_bar.dart';

/// 公共 overrides：所有被页面 watch 的 provider 在此统一覆盖，
/// 避免依赖链走到真实 isarProvider / 原生插件
List<Override> _buildOverrides() => [
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
      // 相册筛选后的照片（相册页 build 时 watch，必须 override，
      // 否则依赖链会走到真实 isarProvider 抛 UnimplementedError）
      filteredAlbumPhotosProvider.overrideWith((ref) => Stream.value([])),
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
          )),
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
          ..paragraphSpacing = 12
          ..pageMode = 0
          ..bgTheme = 0
          ..keepScreenOn = true),
      ),
      // 纪念日（首页倒数卡 + 纪念日页 watch，必须 override）
      anniversariesProvider.overrideWith((ref) => Stream.value([])),
      // 待办
      memosProvider.overrideWith((ref) => Stream.value([])),
      // 待办总数
      memoCountProvider.overrideWithValue(0),
      // 音乐：Fake 后端 + 空歌单，避免 audioBackendProvider 抛
      // UnimplementedError 与 musicLibraryProvider 触发原生库
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
      musicLibraryProvider.overrideWith((ref) async => []),
      // 双人同步状态（我的页同步卡 watch；未配置云环境时保持未启用）
      syncStatusProvider.overrideWith(
        (ref) => Stream.value(
          const SyncStatus(
            isConfigured: false,
            isPaired: false,
            isSyncing: false,
          ),
        ),
      ),
    ];

void main() {
  testWidgets('App renders home page smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _buildOverrides(),
        child: const LoveSpaceApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 验证首页问候语存在
    expect(find.text('早上好，亲爱的'), findsOneWidget);
    // 验证底部导航 Tab 标签存在
    expect(find.text('时光'), findsWidgets);
    expect(find.text('相册'), findsWidgets);
    expect(find.text('加载失败'), findsNothing);

    // 切换到相册 Tab，验证数据层 override 生效（空状态而非错误态）
    await tester.tap(
      find.descendant(
        of: find.byType(PillNavBar),
        matching: find.text('相册'),
      ),
    );
    await tester.pumpAndSettle();

    // 空列表应渲染空状态引导，而非「加载失败」
    expect(find.text('还没有照片，快去添加第一张吧'), findsOneWidget);
    expect(find.text('加载失败'), findsNothing);
  });

  testWidgets('我的页点击小说卡应切换到小说 Tab', (WidgetTester tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: _buildOverrides(),
        child: const LoveSpaceApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 切换到「我的」Tab
    await tester.tap(
      find.descendant(
        of: find.byType(PillNavBar),
        matching: find.text('我的'),
      ),
    );
    await tester.pumpAndSettle();

    // 小说功能卡的副文案（书架为空时的引导文案），点击应触发切 Tab
    await tester.ensureVisible(find.text('一起读书吧'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('一起读书吧'));
    await tester.pumpAndSettle();

    // 验证 currentTabProvider 已切到小说 Tab
    final container = ProviderScope.containerOf(
      tester.element(find.byType(MainShell)),
    );
    expect(container.read(currentTabProvider), NavTab.novel);
    // 小说页已可见（书架空态）
    expect(find.text('书架还空空的'), findsOneWidget);
  });

  testWidgets('BreakoutPage renders with ready overlay', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: BreakoutPage()),
    );
    await tester.pump();
    expect(find.text('打砖块'), findsOneWidget);
    expect(find.text('准备好了吗'), findsOneWidget); // ready 遮罩
  });

  testWidgets('PomodoroPage renders smoke', (tester) async {
    // 番茄钟页 watch pomodoroSettingsProvider / pomodoroTimerProvider /
    // todayFocusProvider（间接 watch focusSessionsProvider）。
    // 计时器 build() 为纯初值（idle），onAppResumed 在 idle 时早退，
    // 故只需 override 两个会触达 isarProvider 的 StreamProvider。
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          pomodoroSettingsProvider.overrideWith(
            (ref) => Stream.value(PomodoroSettings()
              ..focusMin = 25
              ..shortBreakMin = 5
              ..longBreakMin = 15
              ..longBreakInterval = 4
              ..autoStartBreak = true
              ..autoStartFocus = false),
          ),
          focusSessionsProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: const MaterialApp(home: PomodoroPage()),
      ),
    );
    await tester.pump();

    expect(find.text('番茄钟'), findsOneWidget);
    expect(find.text('加载失败'), findsNothing);
  });
}
