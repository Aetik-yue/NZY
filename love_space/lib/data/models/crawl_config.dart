import 'package:isar/isar.dart';

part 'crawl_config.g.dart';

/// 全局爬取配置（单例行）
///
/// 控制爬虫的请求频率、重试策略、UA 轮换与广告关键词黑名单。
@collection
class CrawlConfig {
  Id id = Isar.autoIncrement;

  /// 请求最小间隔（毫秒），避免触发反爬
  late int requestIntervalMs;

  /// 最大重试次数
  late int maxRetries;

  /// 单次请求超时（毫秒）
  late int timeoutMs;

  /// 是否轮换 User-Agent
  late bool rotateUserAgent;

  /// 广告关键词黑名单（含这些词的行会被内容清洗器移除）
  late List<String> adKeywords;

  /// 首次抓取时预取章节数（仅首章免费/试读策略不需要时用全部）
  late int prefetchChapters;
}
