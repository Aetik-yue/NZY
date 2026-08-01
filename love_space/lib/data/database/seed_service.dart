import 'package:isar/isar.dart';
import '../../core/constants/seed_data.dart';
import '../../data/models/timeline_event.dart';
import '../../data/models/check_in.dart';
import '../../data/models/app_settings.dart';
import '../../data/models/novel_source.dart';
import '../../data/models/memo.dart';
import '../repositories/crawl_config_repository.dart';

/// 首次启动种子数据服务
class SeedService {
  SeedService(this._isar);
  final Isar _isar;

  /// 若数据库为空则写入种子数据（幂等，可安全地在每次启动时调用）
  static Future<void> seedIfEmpty(Isar isar) async {
    final existing = await isar.appSettings.where().findFirst();
    if (existing != null) return; // 已初始化过

    final service = SeedService(isar);
    await service._seed();
  }

  Future<void> _seed() async {
    await _isar.writeTxn(() async {
      // 设置
      await _isar.appSettings.put(Seed.settings());

      // 时间轴
      await _isar.timelineEvents.putAll(Seed.timelineEvents());

      // 打卡
      await _isar.checkIns.putAll(Seed.checkIns());

      // 备忘录种子数据
      await _isar.memos.putAll([
        Memo()
          ..content = '第一次牵手的那天，心跳得好快 💕'
          ..author = 1
          ..isPinned = true
          ..colorValue = 0xFFFF8FB1
          ..createdAt = DateTime.now().subtract(const Duration(days: 30)),
        Memo()
          ..content = '一起去北海道看雪！#旅行计划'
          ..author = 2
          ..isPinned = false
          ..colorValue = 0xFFFFD1BF
          ..createdAt = DateTime.now().subtract(const Duration(days: 15)),
        Memo()
          ..content = '记得买牛奶和面包 #购物'
          ..author = 1
          ..isPinned = false
          ..colorValue = 0xFFFF8FB1
          ..createdAt = DateTime.now().subtract(const Duration(hours: 3)),
      ]);
    });

    // 爬虫默认源与配置（独立事务，避免重复写入）
    await _seedCrawlDefaults();
  }

  /// 写入爬虫默认数据（幂等）
  Future<void> _seedCrawlDefaults() async {
    // 默认爬取源：笔趣阁
    final existingSource = await _isar.novelSources
        .where()
        .keyEqualTo('biquge')
        .findFirst();

    if (existingSource == null) {
      // 新建源
      await _isar.writeTxn(() async {
        await _isar.novelSources.put(NovelSource()
          ..key = 'biquge'
          ..name = '笔趣阁'
          ..baseUrl = 'https://www.biquge2.net'
          ..enabled = true
          ..createdAt = DateTime.now()
          ..selectors = _biqugeSelectors);
      });
    } else if (existingSource.baseUrl.contains('xbiquge.la')) {
      // 迁移：旧域名已失效，更新为新域名
      existingSource.baseUrl = 'https://www.biquge2.net';
      await _isar.writeTxn(() async {
        await _isar.novelSources.put(existingSource);
      });
    }

    // 补充搜索源：bqgbb.cc（搜索有效，作为 biquge2.net 的搜索替代）
    final bqgbbSource = await _isar.novelSources
        .where()
        .keyEqualTo('bqgbb')
        .findFirst();
    if (bqgbbSource == null) {
      await _isar.writeTxn(() async {
        await _isar.novelSources.put(NovelSource()
          ..key = 'bqgbb'
          ..name = '笔趣阁（搜索源）'
          ..baseUrl = 'https://www.bqgbb.cc'
          ..enabled = true
          ..createdAt = DateTime.now()
          ..selectors = _bqgbbSelectors);
      });
    }

    // 默认爬取配置
    final configRepo = CrawlConfigRepository(_isar);
    await configRepo.getOrCreate();
  }

  /// 笔趣阁默认选择器配置
  static const String _biqugeSelectors = '''
{
  "searchUrl": "/modules/article/search.php?searchkey={keyword}",
  "bookLinkSelector": "table.grid tr td a",
  "titleSelector": "#info h1",
  "authorSelector": "#info p a",
  "introSelector": "#intro",
  "chapterListSelector": "#list dd a",
  "chapterTitleSelector": ".bookname h1",
  "chapterContentSelector": "#content"
}
''';

  /// bqgbb.cc 选择器配置（搜索源）
  static const String _bqgbbSelectors = '''
{
  "searchUrl": "/search.php?searchkey={keyword}",
  "bookLinkSelector": "li a[href*=\\"/book/\\"]",
  "titleSelector": ".details h2",
  "authorSelector": ".details p a[href*=\\"/zuozhe/\\"]",
  "introSelector": ".intro .p2",
  "chapterListSelector": ".yanqing_list li a",
  "chapterTitleSelector": ".bookname h1",
  "chapterContentSelector": "#content"
}
''';
}
