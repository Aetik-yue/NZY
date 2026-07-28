import 'package:isar/isar.dart';
import '../models/crawl_log.dart';

/// 爬取日志数据仓库
class CrawlLogRepository {
  CrawlLogRepository(this._isar);
  final Isar _isar;

  /// 按小说 id 查询日志（最新在前）
  Future<List<CrawlLog>> getByNovel(int novelId) => _isar.crawlLogs
      .where()
      .novelIdEqualTo(novelId)
      .sortByCrawledAtDesc()
      .findAll();

  /// 监听某小说的爬取日志（实时流）
  Stream<List<CrawlLog>> watchByNovel(int novelId) => _isar.crawlLogs
      .where()
      .novelIdEqualTo(novelId)
      .sortByCrawledAtDesc()
      .watch(fireImmediately: true);

  /// 新增日志
  Future<void> add(CrawlLog log) =>
      _isar.writeTxn(() async => _isar.crawlLogs.put(log));

  /// 删除某小说的全部日志
  Future<void> deleteByNovel(int novelId) =>
      _isar.writeTxn(() async {
        await _isar.crawlLogs.where().novelIdEqualTo(novelId).deleteAll();
      });
}
