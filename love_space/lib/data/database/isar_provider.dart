import 'package:isar/isar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/wish.dart';
import '../models/timeline_event.dart';
import '../models/album_photo.dart';
import '../models/check_in.dart';
import '../models/app_settings.dart';
import '../models/anniversary.dart';
import '../models/novel.dart';
import '../models/novel_chapter.dart';
import '../models/reader_settings.dart';
import '../models/novel_source.dart';
import '../models/crawl_config.dart';
import '../models/crawl_log.dart';
import '../models/memo.dart';
import '../models/secret_message.dart';
import '../models/pomodoro_settings.dart';
import '../models/focus_session.dart';

/// Isar 数据库实例 provider。
///
/// 默认抛出异常，必须在 main() 中通过 overrideWithValue 注入真实实例。
/// Widget 层不应直接使用该 provider，而是通过 repository / data provider 间接访问。
final isarProvider = Provider<Isar>((ref) {
  throw UnimplementedError('isarProvider 必须在 main() 中 override');
});

/// 所有 Isar collection schema，统一在 Isar.open() 时使用。
const isarSchemas = [
  WishSchema,
  TimelineEventSchema,
  AlbumPhotoSchema,
  CheckInSchema,
  AppSettingsSchema,
  AnniversarySchema,
  NovelSchema,
  NovelChapterSchema,
  ReaderSettingsSchema,
  NovelSourceSchema,
  CrawlConfigSchema,
  CrawlLogSchema,
  MemoSchema,
  SecretMessageSchema,
  PomodoroSettingsSchema,
  FocusSessionSchema,
];
