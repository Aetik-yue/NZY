import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/isar_provider.dart';
import '../repositories/wish_repository.dart';
import '../repositories/timeline_repository.dart';
import '../repositories/album_repository.dart';
import '../repositories/checkin_repository.dart';
import '../repositories/settings_repository.dart';
import '../repositories/novel_repository.dart';
import '../repositories/novel_chapter_repository.dart';
import '../repositories/reader_settings_repository.dart';
import '../../core/utils/greeting.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/streak.dart';
import '../models/wish.dart';
import '../models/timeline_event.dart';
import '../models/app_settings.dart';
import '../models/check_in.dart';
import '../models/album_photo.dart';
import '../models/novel.dart';
import '../models/novel_chapter.dart';
import '../models/reader_settings.dart';

// ═══════════════════════════════════════════════════════════════
// Repository providers（依赖 isarProvider）
// ═══════════════════════════════════════════════════════════════

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
// Derived / computed providers（跨页一致性的单一数据源）
// ═══════════════════════════════════════════════════════════════

/// 时钟（每分钟刷新），驱动问候语更新
final clockProvider = StreamProvider<DateTime>((ref) =>
    Stream.periodic(const Duration(minutes: 1), (_) => DateTime.now()));

/// 问候语
final greetingProvider = Provider<String>((ref) {
  ref.watch(clockProvider);
  return Greeting.now();
});

/// 在一起天数
final daysTogetherProvider = Provider<int>((ref) {
  final settings = ref.watch(appSettingsProvider).valueOrNull;
  if (settings == null) return 0;
  return DateUtilsX.daysBetween(DateUtilsX.today(), settings.togetherSince);
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

