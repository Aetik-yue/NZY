// 权限时机测试：启动 / 切到「我的」tab 均不触发音频权限与扫描，
// 只有打开播放页（MusicPlayerPage）才触发扫描并注入歌单。
//
// 通过读计数 spy override musicLibraryProvider：provider 每执行一次扫描则计数 +1。
// 若启动或 profile 音乐卡误 watch musicLibraryProvider，计数会提前 > 0，测试失败。
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:love_space/app/app.dart';
import 'package:love_space/core/utils/date_utils.dart';
import 'package:love_space/data/models/app_settings.dart';
import 'package:love_space/data/models/reader_settings.dart';
import 'package:love_space/data/models/timeline_event.dart';
import 'package:love_space/data/providers/data_providers.dart';
import 'package:love_space/features/music/models/music_song.dart';
import 'package:love_space/features/music/providers/audio_backend.dart';
import 'package:love_space/features/music/providers/music_library_provider.dart';
import 'package:love_space/features/music/providers/music_player_provider.dart';
import 'package:love_space/shared/widgets/pill_nav_bar.dart';

MusicSong _song(int id) => MusicSong(
      id: id,
      title: '歌$id',
      artist: '歌手$id',
      duration: const Duration(seconds: 10),
      uri: 'file:///song$id.mp3',
      coverIndex: id % 6,
    );

/// 与 widget_test.dart 保持一致的 override 集合；
/// [onLibraryScan] 为扫描计数回调，每次 musicLibraryProvider 执行时调用。
List<Override> _appOverrides(void Function() onLibraryScan) => [
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
      // 相册筛选后的照片
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
          ..pageMode = 0
          ..bgTheme = 0
          ..keepScreenOn = true),
      ),
      // 待办
      memosProvider.overrideWith((ref) => Stream.value([])),
      // 待办总数
      memoCountProvider.overrideWithValue(0),
      // 音乐：Fake 后端 + 扫描计数 spy
      audioBackendProvider.overrideWithValue(FakeAudioBackend()),
      musicLibraryProvider.overrideWith((ref) async {
        onLibraryScan();
        return [_song(1), _song(2)];
      }),
    ];

void main() {
  testWidgets('权限时机：启动/我的 tab 不触发扫描，打开播放页才触发并注入歌单',
      (WidgetTester tester) async {
    var libraryCalls = 0;
    final container = ProviderContainer(
      overrides: _appOverrides(() => libraryCalls++),
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const LoveSpaceApp(),
      ),
    );
    await tester.pumpAndSettle();

    // 1. 启动：MiniPlayerBar 与首页都不 watch musicLibraryProvider，不触发扫描/权限
    expect(libraryCalls, 0, reason: 'App 启动不应触发音乐扫描/权限');

    // 2. 切到「我的」tab：profile 音乐卡只 watch musicPlayerProvider，仍不触发
    await tester.tap(
      find.descendant(
        of: find.byType(PillNavBar),
        matching: find.text('我的'),
      ),
    );
    await tester.pumpAndSettle();
    expect(libraryCalls, 0, reason: '打开「我的」tab 不应触发音乐扫描/权限');

    // 3. 打开播放页：initState 的 listenManual 触发扫描 + 注入歌单
    // profile「回忆唱片」整卡可点击 -> MusicPlayerPage.show
    await tester.tap(find.text('回忆唱片'));
    await tester.pump(); // 构建 BottomSheet，initState 执行 -> provider 执行
    await tester.pump(const Duration(milliseconds: 400)); // sheet 动画 + 微任务
    await tester.pump(const Duration(milliseconds: 100)); // 额外缓冲

    expect(libraryCalls, 1, reason: '只有打开播放页才应触发一次音乐扫描');
    final state = container.read(musicPlayerProvider);
    expect(state.playlist.length, 2, reason: '扫描结果应注入播放器歌单');
  });
}
