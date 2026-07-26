import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/isar_provider.dart';
import '../repositories/wish_repository.dart';
import '../repositories/timeline_repository.dart';
import '../repositories/album_repository.dart';
import '../repositories/checkin_repository.dart';
import '../repositories/settings_repository.dart';
import '../../core/utils/greeting.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/streak.dart';
import '../models/wish.dart';
import '../models/app_settings.dart';
import '../models/check_in.dart';
import '../models/album_photo.dart';

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
final timelineEventsProvider = StreamProvider<List<dynamic>>((ref) =>
    ref.watch(timelineRepositoryProvider).watchAll());

/// 相册照片（全部，用于统计数量）
final allAlbumPhotosProvider = StreamProvider<List<dynamic>>((ref) =>
    ref.watch(albumRepositoryProvider).watchAll());

/// 最近的相册照片（用于网格展示）
final albumPhotosProvider = StreamProvider<List<dynamic>>((ref) =>
    ref.watch(albumRepositoryProvider).watchRecent(6));

/// 应用设置
final appSettingsProvider = StreamProvider<AppSettings?>((ref) =>
    ref.watch(settingsRepositoryProvider).watch());

/// 所有打卡记录
final checkinsProvider = StreamProvider<List<CheckIn>>((ref) =>
    ref.watch(checkinRepositoryProvider).watchAll());

// ═══════════════════════════════════════════════════════════════
// Derived / computed providers（跨页一致性的单一数据源）
// ═══════════════════════════════════════════════════════════════

/// 问候语
final greetingProvider = Provider<String>((ref) => Greeting.now());

/// 在一起天数
final daysTogetherProvider = Provider<int>((ref) {
  final settings = ref.watch(appSettingsProvider).valueOrNull;
  if (settings == null) return 0;
  return DateUtilsX.daysBetween(DateUtilsX.today(), settings.togetherSince);
});

/// 相册照片总数
final photoCountProvider = Provider<int>((ref) =>
    ref.watch(allAlbumPhotosProvider).valueOrNull?.length ?? 0);

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
    return repo.watchRecent(6);
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

    final groups = <PhotoGroup>[];
    for (final p in sorted) {
      if (groups.isEmpty ||
          groups.last.year != p.date.year ||
          groups.last.month != p.date.month) {
        groups.add(PhotoGroup(
          year: p.date.year,
          month: p.date.month,
          photos: [p],
        ));
      } else {
        groups.last.photos.add(p);
      }
    }
    return groups;
  });
});

