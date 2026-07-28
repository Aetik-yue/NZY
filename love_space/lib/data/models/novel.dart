import 'package:isar/isar.dart';

part 'novel.g.dart';

/// 书架小说条目
///
/// 既承载预置（isBuiltin=true）的示例小说，也支持用户后续添加的自定义小说。
@collection
class Novel {
  Id id = Isar.autoIncrement;

  /// 书名
  late String title;

  /// 作者
  late String author;

  /// 简介
  late String intro;

  /// 封面占位色（取自 AppColors 渐变值，运行时读取，非硬编码）
  late int coverColorValue;

  /// 标签（Isar 标量列表）
  late List<String> tags;

  /// 章节数（与 novelChapters 实际条数保持一致）
  late int chapterCount;

  /// 是否预置（种子数据）
  late bool isBuiltin;

  /// 最近阅读章节下标（-1 表示未读）
  late int lastChapterIndex;

  /// 阅读进度比例 0..1（按当前章节内的滚动/翻页位置）
  late double lastPosition;

  /// 最近阅读时间
  DateTime? lastReadAt;

  /// 创建时间（用于书架排序）
  late DateTime createdAt;

  // ──────── 爬虫关联（null = 预置种子数据） ────────

  /// 关联的爬取源 key（对应 NovelSource.key）
  String? sourceKey;

  /// 源站书籍 ID（用于拼接源站 URL）
  String? sourceBookId;

  /// 源站书籍详情页 URL（更新时直接请求）
  String? sourceUrl;

  /// 最后爬取时间
  DateTime? lastCrawlAt;

  /// 爬取状态：idle / crawling / success / failed
  String crawlStatus = 'idle';
}
