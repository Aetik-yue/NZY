import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../shared/widgets/pill_nav_bar.dart';
import '../database/isar_provider.dart';
import '../repositories/wish_repository.dart';
import '../repositories/timeline_repository.dart';
import '../repositories/album_repository.dart';
import '../repositories/checkin_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/anniversary_repository.dart';
import '../repositories/novel_repository.dart';
import '../repositories/novel_chapter_repository.dart';
import '../repositories/reader_settings_repository.dart';
import '../repositories/novel_source_repository.dart';
import '../repositories/crawl_config_repository.dart';
import '../repositories/crawl_log_repository.dart';
import '../repositories/crawl_repository.dart';
import '../repositories/memo_repository.dart';
import '../repositories/pomodoro_settings_repository.dart';
import '../repositories/focus_session_repository.dart';
import '../../core/utils/greeting.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/streak.dart';
import '../../core/utils/tag_utils.dart';
import '../../core/utils/anniversary_utils.dart';
import '../../core/constants/seed_data.dart';
import '../models/wish.dart';
import '../models/timeline_event.dart';
import '../models/app_settings.dart';
import '../models/anniversary.dart';
import '../models/check_in.dart';
import '../models/album_photo.dart';
import '../models/novel.dart';
import '../models/novel_chapter.dart';
import '../models/reader_settings.dart';
import '../models/novel_source.dart';
import '../models/crawl_config.dart';
import '../models/crawl_log.dart';
import '../models/memo.dart';
import '../models/pomodoro_settings.dart';
import '../models/focus_session.dart';

// ═══════════════════════════════════════════════════════════════
// Repository providers（依赖 isarProvider）
// ═══════════════════════════════════════════════════════════════

/// 当前激活的底部 Tab（驱动 MainShell 的 IndexedStack 切换）
final currentTabProvider = StateProvider<NavTab>((ref) => NavTab.home);

final wishRepositoryProvider = Provider((ref) =>
    WishRepository(ref.watch(isarProvider)));

final timelineRepositoryProvider = Provider((ref) =>
    TimelineRepository(ref.watch(isarProvider)));

final albumRepositoryProvider = Provider((ref) =>
    AlbumRepository(ref.watch(isarProvider)));

final checkinRepositoryProvider = Provider((ref) =>
    CheckinRepository(ref.watch(isarProvider)));

final settingsRepositoryProvider = Provider((ref) =>
    SettingsRepository(ref.watch(isarProvider)));

final anniversaryRepositoryProvider = Provider((ref) =>
    AnniversaryRepository(ref.watch(isarProvider)));

// ═══════════════════════════════════════════════════════════════
// Data stream providers（监听数据库变化）
// ═══════════════════════════════════════════════════════════════

/// 所有愿望
final wishesProvider = StreamProvider<List<Wish>>((ref) =>
    ref.watch(wishRepositoryProvider).watchAll());

/// 所有时间轴事件
final timelineEventsProvider = StreamProvider<List<TimelineEvent>>((ref) =>
    ref.watch(timelineRepositoryProvider).watchAll());


/// 应用设置
final appSettingsProvider = StreamProvider<AppSettings?>((ref) =>
    ref.watch(settingsRepositoryProvider).watch());

/// 所有打卡记录
final checkinsProvider = StreamProvider<List<CheckIn>>((ref) =>
    ref.watch(checkinRepositoryProvider).watchAll());

// ═══════════════════════════════════════════════════════════════
// 纪念日模块 providers（多节点管理 + 首页倒数）
// ═══════════════════════════════════════════════════════════════

/// 所有纪念日（实时流，按日期升序）
final anniversariesProvider = StreamProvider<List<Anniversary>>((ref) =>
    ref.watch(anniversaryRepositoryProvider).watchAll());

/// 距今天最近的下一个纪念日（含今天当天），无数据返回 null
final nextAnniversaryProvider = Provider<Anniversary?>((ref) {
  final items = ref.watch(anniversariesProvider).valueOrNull;
  if (items == null || items.isEmpty) return null;
  return AnniversaryUtils.nextFrom(items, DateUtilsX.today());
});

/// 即将到来的纪念日（今天起 7 天内，用于首页提前提醒提示）
final upcomingAnniversaryProvider = Provider<Anniversary?>((ref) {
  final items = ref.watch(anniversariesProvider).valueOrNull;
  if (items == null || items.isEmpty) return null;
  return AnniversaryUtils.upcomingWithin(items, DateUtilsX.today());
});

// ═══════════════════════════════════════════════════════════════
// Derived / computed providers（跨页一致性的单一数据源）
// ═══════════════════════════════════════════════════════════════

/// 时钟（每分钟刷新），驱动问候语更新
final clockProvider = StreamProvider<DateTime>((ref) =>
    Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now()));

/// 问候语（特殊节点优先：在一起周年 / 阳历节日，否则按时段）
final greetingProvider = Provider<String>((ref) {
  ref.watch(clockProvider);
  final settings = ref.watch(appSettingsProvider).valueOrNull;
  return Greeting.special(DateTime.now(), settings?.togetherSince) ??
      Greeting.now();
});

/// 在一起天数（第 1 天起，边界归一化）
///
/// - 设置缺失：取种子默认起始日（正常启动后种子必然存在）
/// - 起始日当天：第 1 天
/// - togetherSince 在未来：返回 0（不显示负数）
final daysTogetherProvider = Provider<int>((ref) {
  final settings = ref.watch(appSettingsProvider).valueOrNull;
  final since = settings?.togetherSince ?? Seed.togetherSince;
  final days = DateUtilsX.daysBetween(DateUtilsX.today(), since);
  if (days < 0) return 0;
  return days + 1;
});

/// 相册照片总数
final photoCountProvider = Provider<int>((ref) =>
    ref.watch(allPhotosTypedProvider).valueOrNull?.length ?? 0);

/// 愿望统计
class WishStats {
  final int done;
  final int total;
  const WishStats({required this.done, required this.total});

  double get percent => total == 0 ? 0 : done / total;

  int get percentInt => (percent * 100).round();
}

final wishStatsProvider = Provider<WishStats>((ref) {
  final wishes = ref.watch(wishesProvider).valueOrNull ?? [];
  return WishStats(
    done: wishes.where((w) => w.done).length,
    total: wishes.length,
  );
});

/// 连续打卡天数
final checkinStreakProvider = Provider<int>((ref) {
  final checkins = ref.watch(checkinsProvider).valueOrNull ?? [];
  return computeStreak(checkins.map((c) => c.date).toList());
});

/// 相册筛选分类（null = 全部）
final albumFilterProvider = StateProvider<PhotoCategory?>((ref) => null);

/// 根据筛选条件过滤后的照片
final filteredAlbumPhotosProvider = StreamProvider<List<AlbumPhoto>>((ref) {
  final filter = ref.watch(albumFilterProvider);
  final repo = ref.watch(albumRepositoryProvider);
  if (filter == null) {
    return repo.watchAll();
  }
  return repo.watchByCategory(filter);
});

// ═══════════════════════════════════════════════════════════════
// 时间轴相关（按年月分组）
// ═══════════════════════════════════════════════════════════════

/// 所有照片（强类型，供时间轴分组使用）
final allPhotosTypedProvider = StreamProvider<List<AlbumPhoto>>((ref) =>
    ref.watch(albumRepositoryProvider).watchAll());

/// 照片按年月分组
class PhotoGroup {
  final int year;
  final int month;
  final List<AlbumPhoto> photos;

  PhotoGroup({
    required this.year,
    required this.month,
    required List<AlbumPhoto> photos,
  }) : photos = List.unmodifiable(photos);

  /// 分组标题，如 "2024年8月"
  String get label => '$year年$month月';

  /// 短标题，如 "8月"
  String get shortLabel => '$month月';

  /// 该分组的排序键（用于跳转定位）
  int get key => year * 100 + month;

  /// 是否为纪念日所在月
  bool isHighlight(int? annivMonth) {
    if (annivMonth == null) return false;
    return month == annivMonth;
  }
}

/// 照片按年月分组（降序，最新在前）
final groupedAlbumPhotosProvider =
    Provider<AsyncValue<List<PhotoGroup>>>((ref) {
  final photosAsync = ref.watch(allPhotosTypedProvider);

  return photosAsync.whenData((photos) {
    final sorted = List<AlbumPhoto>.from(photos)
      ..sort((a, b) => b.date.compareTo(a.date));

    // 先用 Map 按年月分组（可变列表），再构造不可变的 PhotoGroup
    final map = <int, List<AlbumPhoto>>{};
    for (final p in sorted) {
      final key = p.date.year * 100 + p.date.month;
      map.putIfAbsent(key, () => []).add(p);
    }
    return map.entries.map((e) => PhotoGroup(
      year: e.key ~/ 100,
      month: e.key % 100,
      photos: e.value,
    )).toList();
  });
});

// ═══════════════════════════════════════════════════════════════
// 小说模块 providers（书架 / 章节 / 阅读设置）
// ═══════════════════════════════════════════════════════════════

/// 小说书架数据仓库
final novelRepositoryProvider = Provider((ref) =>
    NovelRepository(ref.watch(isarProvider)));

/// 小说章节数据仓库
final novelChapterRepositoryProvider = Provider((ref) =>
    NovelChapterRepository(ref.watch(isarProvider)));

/// 阅读设置数据仓库（单例行）
final readerSettingsRepositoryProvider = Provider((ref) =>
    ReaderSettingsRepository(ref.watch(isarProvider)));

/// 所有书架小说
final novelsProvider = StreamProvider<List<Novel>>((ref) =>
    ref.watch(novelRepositoryProvider).watchAll());

/// 某本小说的章节列表（按小说 id 过滤）
final chaptersProvider =
    StreamProvider.family<List<NovelChapter>, int>((ref, novelId) =>
        ref.watch(novelChapterRepositoryProvider).watchByNovel(novelId));

/// 阅读器设置
final readerSettingsProvider = StreamProvider<ReaderSettings?>((ref) =>
    ref.watch(readerSettingsRepositoryProvider).watch());

// ═══════════════════════════════════════════════════════════════
// 小说爬虫模块 providers（源 / 配置 / 日志 / 协调器）
// ═══════════════════════════════════════════════════════════════

/// 小说爬取源数据仓库
final novelSourceRepositoryProvider = Provider((ref) =>
    NovelSourceRepository(ref.watch(isarProvider)));

/// 全局爬取配置数据仓库
final crawlConfigRepositoryProvider = Provider((ref) =>
    CrawlConfigRepository(ref.watch(isarProvider)));

/// 爬取日志数据仓库
final crawlLogRepositoryProvider = Provider((ref) =>
    CrawlLogRepository(ref.watch(isarProvider)));

/// 爬取协调器（依赖其他 4 个 repository）
final crawlRepositoryProvider = Provider<CrawlRepository>((ref) {
  final repo = CrawlRepository(
    novelRepository: ref.watch(novelRepositoryProvider),
    novelChapterRepository: ref.watch(novelChapterRepositoryProvider),
    sourceRepository: ref.watch(novelSourceRepositoryProvider),
    configRepository: ref.watch(crawlConfigRepositoryProvider),
    logRepository: ref.watch(crawlLogRepositoryProvider),
  );
  // 应用退出时释放底层 HTTP 连接
  ref.onDispose(repo.dispose);
  return repo;
});

/// 所有爬取源
final novelSourcesProvider = StreamProvider<List<NovelSource>>((ref) =>
    ref.watch(novelSourceRepositoryProvider).watchAll());

/// 全局爬取配置
final crawlConfigProvider = FutureProvider<CrawlConfig>((ref) =>
    ref.watch(crawlConfigRepositoryProvider).getOrCreate());

/// 某小说的爬取日志（按小说 id 过滤）
final crawlLogsProvider =
    StreamProvider.family<List<CrawlLog>, int>((ref, novelId) =>
        ref.watch(crawlLogRepositoryProvider).watchByNovel(novelId));

/// 当前爬取状态（UI 展示进度用）
final crawlStatusProvider = StateProvider<CrawlStatus>((ref) => CrawlStatus.idle);

/// 爬取状态（不可变数据类，驱动 UI 进度展示）
class CrawlStatus {
  final String state; // idle / searching / fetching / success / failed
  final String? message; // 当前操作描述
  final int? current; // 当前进度
  final int? total; // 总数

  const CrawlStatus({
    required this.state,
    this.message,
    this.current,
    this.total,
  });

  static const idle = CrawlStatus(state: 'idle');
  static const searching = CrawlStatus(state: 'searching');
  static const fetching = CrawlStatus(state: 'fetching');
  static const success = CrawlStatus(state: 'success');
  static const failed = CrawlStatus(state: 'failed');

  CrawlStatus copyWith({
    String? state,
    String? message,
    int? current,
    int? total,
  }) =>
      CrawlStatus(
        state: state ?? this.state,
        message: message ?? this.message,
        current: current ?? this.current,
        total: total ?? this.total,
      );
}

// ═══════════════════════════════════════════════════════════════
// 待办模块 providers（数据仓库 / 流 / 筛选 / 衍生）
// ═══════════════════════════════════════════════════════════════

/// 待办数据仓库
final memoRepositoryProvider = Provider((ref) =>
    MemoRepository(ref.watch(isarProvider)));

/// 所有待办（实时流，按创建时间降序）
final memosProvider = StreamProvider<List<Memo>>((ref) =>
    ref.watch(memoRepositoryProvider).watchAll());

/// 搜索关键词
final memoSearchProvider = StateProvider<String>((ref) => '');

/// 当前筛选标签（null = 全部）
final memoTagFilterProvider = StateProvider<String?>((ref) => null);

/// 当前作者筛选（null = 全部, 1 或 2）
final memoAuthorFilterProvider = StateProvider<int?>((ref) => null);

/// 待办筛选（全部/待办/已完成）
enum TodoFilter { all, active, done }

/// 当前待办筛选状态（默认全部）
final memoDoneFilterProvider =
    StateProvider<TodoFilter>((ref) => TodoFilter.all);

/// 过滤后的待办（搜索 + 标签 + 作者 + 完成状态 + 排序）
///
/// 搜索词先 trim（避免尾随空格搜不到）；标签按独立标签精确匹配
/// （选「旅行」不会误命中「#旅行计划」）。
/// 排序规则：未完成在前、已完成沉底；同状态内按优先级
/// （high>medium>low>none）+ 截止日期（近在前，无截止在后）；
/// 最后按创建时间降序兜底。
final filteredMemosProvider = Provider<List<Memo>>((ref) {
  final memos = ref.watch(memosProvider).valueOrNull ?? [];
  final query = ref.watch(memoSearchProvider).trim().toLowerCase();
  final tag = ref.watch(memoTagFilterProvider);
  final author = ref.watch(memoAuthorFilterProvider);
  final doneFilter = ref.watch(memoDoneFilterProvider);

  var result = memos.where((m) {
    if (author != null && m.author != author) return false;
    if (tag != null && !contentHasTag(m.content, tag)) return false;
    if (query.isNotEmpty && !m.content.toLowerCase().contains(query)) {
      return false;
    }
    // done 筛选
    if (doneFilter == TodoFilter.active && m.done) return false;
    if (doneFilter == TodoFilter.done && !m.done) return false;
    return true;
  }).toList();

  // 排序：未完成在前、已完成沉底；同状态内按优先级 + 截止日期 + 创建时间
  result.sort((a, b) {
    // 1. 未完成在前
    if (a.done != b.done) return a.done ? 1 : -1;
    // 2. 优先级（high>medium>low>none）
    final aPri = _priorityWeight(a.priority);
    final bPri = _priorityWeight(b.priority);
    if (aPri != bPri) return bPri - aPri;
    // 3. 截止日期（近在前，无截止在后）
    final aDue = a.dueDate;
    final bDue = b.dueDate;
    if (aDue != null && bDue != null) return aDue.compareTo(bDue);
    if (aDue != null && bDue == null) return -1;
    if (aDue == null && bDue != null) return 1;
    // 4. 创建时间降序（保留原序兜底）
    return b.createdAt.compareTo(a.createdAt);
  });

  return result;
});

/// 优先级权重（high>medium>low>none，数值越大越靠前）
///
/// 注意 TodoPriority 枚举声明顺序为 none/high/medium/low，
/// 其 index 与优先级高低不一致，故显式映射。
int _priorityWeight(TodoPriority p) => switch (p) {
      TodoPriority.high => 3,
      TodoPriority.medium => 2,
      TodoPriority.low => 1,
      TodoPriority.none => 0,
    };

/// 待办统计（完成数 / 总数 / 百分比）
class MemoStats {
  final int done;
  final int total;
  const MemoStats({required this.done, required this.total});

  double get percent => total == 0 ? 0 : done / total;

  int get percentInt => (percent * 100).round();
}

/// 待办统计（基于全部待办，不受筛选影响）
final memoStatsProvider = Provider<MemoStats>((ref) {
  final memos = ref.watch(memosProvider).valueOrNull ?? [];
  return MemoStats(
    done: memos.where((m) => m.done).length,
    total: memos.length,
  );
});

/// 待办总数
final memoCountProvider = Provider<int>((ref) =>
    ref.watch(memosProvider).valueOrNull?.length ?? 0);

/// 所有可用标签（去重排序）
final allTagsProvider = Provider<List<String>>((ref) {
  final memos = ref.watch(memosProvider).valueOrNull ?? [];
  final tags = <String>{};
  for (final m in memos) {
    tags.addAll(extractMemoTags(m.content));
  }
  return tags.toList()..sort();
});

// ═══════════════════════════════════════════════════════════════
// 番茄钟模块 providers（设置 / 记录 / 今日统计 / 连续天数）
// ═══════════════════════════════════════════════════════════════

/// 番茄钟设置数据仓库（单例，id 固定 0）
final pomodoroSettingsRepositoryProvider = Provider((ref) =>
    PomodoroSettingsRepository(ref.watch(isarProvider)));

/// 番茄钟设置（实时流，行不存在时仓库以默认值兜底）
final pomodoroSettingsProvider = StreamProvider<PomodoroSettings>((ref) =>
    ref.watch(pomodoroSettingsRepositoryProvider).watch());

/// 专注记录数据仓库
final focusSessionRepositoryProvider = Provider((ref) =>
    FocusSessionRepository(ref.watch(isarProvider)));

/// 所有专注记录（实时流，按开始时间降序）
final focusSessionsProvider = StreamProvider<List<FocusSession>>((ref) =>
    ref.watch(focusSessionRepositoryProvider).watchAll());

/// 今日专注统计（时长分钟 + 次数）
///
/// 从 focusSessionsProvider 内存过滤今日 completed 的 focus 记录，
/// 避免单独的 watchToday 查询依赖；每次记录变化自动重算。
final todayFocusProvider = Provider<({int minutes, int count})>((ref) {
  final sessions = ref.watch(focusSessionsProvider).valueOrNull ?? [];
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final today = sessions.where((s) =>
      s.type == FocusType.focus &&
      !s.startTime.isBefore(startOfDay) &&
      s.completed);
  final minutes = today.fold<int>(0, (sum, s) => sum + s.actualMin);
  return (minutes: minutes, count: today.length);
});

/// 连续专注天数（复用 computeStreak，按 completed focus 记录的日期回溯）
final focusStreakProvider = Provider<int>((ref) {
  final sessions = ref.watch(focusSessionsProvider).valueOrNull ?? [];
  final dates = sessions
      .where((s) => s.type == FocusType.focus && s.completed)
      .map((s) => s.startTime)
      .toList();
  return computeStreak(dates);
});

