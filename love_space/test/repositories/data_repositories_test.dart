// 数据层 Repository 单元测试
//
// 使用 Isar 内存库（directory: ''），覆盖各仓库 CRUD 与关键幂等逻辑。
//
// 注意：Isar 原生库在 flutter test 环境（如 Windows 未注册 Flutter 插件）
// 可能无法加载，此时用例会跳过而非失败；在可加载原生库的环境（配置正确的
// CI 或桌面构建）中测试会真实执行。
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:love_space/data/models/wish.dart';
import 'package:love_space/data/models/timeline_event.dart';
import 'package:love_space/data/models/album_photo.dart';
import 'package:love_space/data/models/check_in.dart';
import 'package:love_space/data/models/app_settings.dart';
import 'package:love_space/data/models/novel.dart';
import 'package:love_space/data/models/novel_chapter.dart';
import 'package:love_space/data/models/reader_settings.dart';
import 'package:love_space/data/models/novel_source.dart';
import 'package:love_space/data/models/crawl_config.dart';
import 'package:love_space/data/models/crawl_log.dart';
import 'package:love_space/data/models/memo.dart';
import 'package:love_space/data/repositories/wish_repository.dart';
import 'package:love_space/data/repositories/checkin_repository.dart';
import 'package:love_space/data/repositories/memo_repository.dart';
import 'package:love_space/data/repositories/album_repository.dart';
import 'package:love_space/data/repositories/crawl_config_repository.dart';
import 'package:love_space/data/repositories/reader_settings_repository.dart';
import 'package:love_space/data/repositories/novel_repository.dart';
import 'package:love_space/data/repositories/novel_chapter_repository.dart';

/// 打开一个全新的内存 Isar 实例
Future<Isar> _openTestIsar() {
  return Isar.open(
    [
      WishSchema,
      TimelineEventSchema,
      AlbumPhotoSchema,
      CheckInSchema,
      AppSettingsSchema,
      NovelSchema,
      NovelChapterSchema,
      ReaderSettingsSchema,
      NovelSourceSchema,
      CrawlConfigSchema,
      CrawlLogSchema,
      MemoSchema,
    ],
    directory: '',
  );
}

void main() {
  late Isar isar;
  var isarOpened = false;

  setUp(() async {
    isarOpened = false;
    try {
      isar = await _openTestIsar();
      isarOpened = true;
    } catch (_) {
      // 原生库不可用：保持未打开状态，由各用例跳过
    }
  });

  tearDown(() async {
    if (isarOpened) await isar.close();
  });

  group('WishRepository', () {
    test('add/getAll/toggleDone/update/delete 全链路', () async {
      if (!isarOpened) {
        markTestSkipped('Isar 原生库不可用，跳过数据层测试');
        return;
      }
      final repo = WishRepository(isar);
      await repo.add(Wish()
        ..title = '去冰岛看极光'
        ..description = '一起追逐极光'
        ..iconCodePoint = 0xe588
        ..done = false
        ..createdAt = DateTime.now());

      final all = await repo.getAll();
      expect(all.length, 1);
      expect(all.first.title, '去冰岛看极光');

      // toggleDone
      await repo.toggleDone(all.first.id);
      expect((await isar.wishs.get(all.first.id))!.done, true);
      await repo.toggleDone(all.first.id);
      expect((await isar.wishs.get(all.first.id))!.done, false);

      // update
      final w = all.first;
      w.title = '去冰岛看极光与鲸鱼';
      await repo.update(w);
      expect((await isar.wishs.get(w.id))!.title, '去冰岛看极光与鲸鱼');

      // delete
      await repo.delete(w.id);
      expect(await repo.getAll(), isEmpty);
    });
  });

  group('CheckinRepository', () {
    test('checkInToday 幂等：同一天只插一条', () async {
      if (!isarOpened) {
        markTestSkipped('Isar 原生库不可用，跳过数据层测试');
        return;
      }
      final repo = CheckinRepository(isar);
      expect(await repo.hasCheckedInToday(), false);

      await repo.checkInToday(note: '想你');
      expect(await repo.hasCheckedInToday(), true);
      expect(await repo.getAll(), hasLength(1));

      // 再次打卡不重复插入
      await repo.checkInToday(note: '又想你');
      expect(await repo.getAll(), hasLength(1));

      // 删除后可再次打卡
      await repo.delete((await repo.getAll()).first.id);
      expect(await repo.hasCheckedInToday(), false);
    });
  });

  group('MemoRepository', () {
    test('add/togglePin/update/delete', () async {
      if (!isarOpened) {
        markTestSkipped('Isar 原生库不可用，跳过数据层测试');
        return;
      }
      final repo = MemoRepository(isar);
      await repo.add(Memo()
        ..content = '一起看海 #旅行'
        ..author = 1
        ..isPinned = false
        ..colorValue = 0xFFFF8FB1
        ..createdAt = DateTime.now());

      final all = await repo.getAll();
      expect(all, hasLength(1));

      // togglePin
      final id = all.first.id;
      await repo.togglePin(id);
      expect((await repo.getById(id))!.isPinned, true);

      // update
      final m = all.first;
      m.content = '一起看海和日出 #旅行';
      await repo.update(m);
      expect((await repo.getById(id))!.content, '一起看海和日出 #旅行');

      // delete
      await repo.delete(id);
      expect(await repo.getAll(), isEmpty);
    });
  });

  group('AlbumRepository', () {
    test('add/count/getRecent 与分类过滤', () async {
      if (!isarOpened) {
        markTestSkipped('Isar 原生库不可用，跳过数据层测试');
        return;
      }
      final repo = AlbumRepository(isar);
      await repo.add(AlbumPhoto()
        ..date = DateTime(2024, 5, 20)
        ..category = PhotoCategory.travel
        ..gradientIndex = 0);
      await repo.add(AlbumPhoto()
        ..date = DateTime(2024, 5, 21)
        ..category = PhotoCategory.food
        ..gradientIndex = 1);

      expect(await repo.count(), 2);

      final recent = await repo.getRecent(1);
      expect(recent, hasLength(1));
      expect(recent.first.category, PhotoCategory.food); // 最新在前

      final travel = await repo.watchByCategory(PhotoCategory.travel).first;
      expect(travel, hasLength(1));
      expect(travel.first.category, PhotoCategory.travel);
    });
  });

  group('CrawlConfigRepository', () {
    test('getOrCreate 幂等：多次调用返回同一配置', () async {
      if (!isarOpened) {
        markTestSkipped('Isar 原生库不可用，跳过数据层测试');
        return;
      }
      final repo = CrawlConfigRepository(isar);
      final a = await repo.getOrCreate();
      final b = await repo.getOrCreate();
      expect(a.id, b.id);
      expect(a.prefetchChapters, CrawlConfigRepository.defaultPrefetchChapters);
    });
  });

  group('ReaderSettingsRepository', () {
    test('getOrCreate 幂等 + 保存生效', () async {
      if (!isarOpened) {
        markTestSkipped('Isar 原生库不可用，跳过数据层测试');
        return;
      }
      final repo = ReaderSettingsRepository(isar);
      final a = await repo.getOrCreate();
      final b = await repo.getOrCreate();
      expect(a.id, b.id);

      // 保存后新读仍为同一行
      final updated = await repo.getOrCreate();
      updated.fontSize = 22;
      await repo.save(updated);
      final after = await repo.watch().first;
      expect(after!.fontSize, 22);
    });
  });

  group('NovelChapterRepository', () {
    test('addAll + updateContent 按需抓取写回', () async {
      if (!isarOpened) {
        markTestSkipped('Isar 原生库不可用，跳过数据层测试');
        return;
      }
      final chapterRepo = NovelChapterRepository(isar);
      final novelRepo = NovelRepository(isar);
      final novel = Novel()
        ..title = '测试书'
        ..author = '佚名'
        ..intro = ''
        ..coverColorValue = 0xFFFF6B9D
        ..tags = []
        ..chapterCount = 2
        ..isBuiltin = false
        ..lastChapterIndex = -1
        ..lastPosition = 0.0
        ..createdAt = DateTime.now()
        ..crawlStatus = 'success';
      await novelRepo.add(novel);

      await chapterRepo.addAll([
        NovelChapter()
          ..novelId = novel.id
          ..chapterIndex = 0
          ..title = '第一章'
          ..content = '',
        NovelChapter()
          ..novelId = novel.id
          ..chapterIndex = 1
          ..title = '第二章'
          ..content = '正文',
      ]);

      // 正文为空 → 模拟按需抓取写回
      await chapterRepo.updateContent(novel.id, 0, '新抓取的正文');
      final ch0 = await chapterRepo.getByNovelAndIndex(novel.id, 0);
      expect(ch0!.content, '新抓取的正文');
      expect((await chapterRepo.getByNovelAndIndex(novel.id, 1))!.content, '正文');
    });
  });

  group('NovelRepository', () {
    test('recoverInterruptedCrawls 恢复卡死状态 + 清理半成品', () async {
      if (!isarOpened) {
        markTestSkipped('Isar 原生库不可用，跳过数据层测试');
        return;
      }
      final repo = NovelRepository(isar);
      final chapterRepo = NovelChapterRepository(isar);

      // 1. 卡死 crawling + 有章节 → 恢复为 success
      final stuck = Novel()
        ..title = '卡死书'
        ..author = '佚名'
        ..intro = ''
        ..coverColorValue = 0xFFFF6B9D
        ..tags = []
        ..chapterCount = 1
        ..isBuiltin = false
        ..lastChapterIndex = -1
        ..lastPosition = 0.0
        ..createdAt = DateTime.now()
        ..crawlStatus = 'crawling';
      await repo.add(stuck);
      await chapterRepo.addAll([
        NovelChapter()
          ..novelId = stuck.id
          ..chapterIndex = 0
          ..title = '第一章'
          ..content = '正文',
      ]);

      // 2. 非内置 + 0 章节 → 半成品残骸，删除
      final partial = Novel()
        ..title = '半成品'
        ..author = '佚名'
        ..intro = ''
        ..coverColorValue = 0xFFFF6B9D
        ..tags = []
        ..chapterCount = 0
        ..isBuiltin = false
        ..lastChapterIndex = -1
        ..lastPosition = 0.0
        ..createdAt = DateTime.now()
        ..crawlStatus = 'success';
      await repo.add(partial);

      // 3. 内置 + 0 章节 → 保留
      final builtin = Novel()
        ..title = '内置书'
        ..author = '佚名'
        ..intro = ''
        ..coverColorValue = 0xFFFF6B9D
        ..tags = []
        ..chapterCount = 0
        ..isBuiltin = true
        ..lastChapterIndex = -1
        ..lastPosition = 0.0
        ..createdAt = DateTime.now()
        ..crawlStatus = 'success';
      await repo.add(builtin);

      await repo.recoverInterruptedCrawls();

      final afterStuck = await repo.getById(stuck.id);
      expect(afterStuck, isNotNull);
      expect(afterStuck!.crawlStatus, 'success');

      expect(await repo.getById(partial.id), isNull);
      expect(await repo.getById(builtin.id), isNotNull);
    });
  });
}
