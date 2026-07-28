import 'package:isar/isar.dart';

part 'crawl_log.g.dart';

/// 爬取日志
///
/// 记录每次爬取操作的结果，用于在详情页展示爬取历史。
@collection
class CrawlLog {
  Id id = Isar.autoIncrement;

  /// 关联小说 id
  @Index()
  late int novelId;

  /// 爬取时间
  late DateTime crawledAt;

  /// 结果："success" / "failed"
  late String status;

  /// 详情（错误信息或 "新增 N 章"）
  String? message;

  /// 新增章节数
  int? newChapters;
}
