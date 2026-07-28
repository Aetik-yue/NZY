import 'package:isar/isar.dart';
import '../models/crawl_config.dart';

/// 全局爬取配置数据仓库（单例行）
class CrawlConfigRepository {
  CrawlConfigRepository(this._isar);
  final Isar _isar;

  /// 默认配置
  static const int defaultIntervalMs = 1000;
  static const int defaultMaxRetries = 3;
  static const int defaultTimeoutMs = 15000;
  static const bool defaultRotateUserAgent = true;
  static const int defaultPrefetchChapters = 5;
  static const List<String> defaultAdKeywords = [
    '笔趣阁',
    '请记住',
    '本章未完',
    '点击下载',
    '推荐本书',
    '天才一秒',
    '最快更新',
    '无弹窗推荐',
    '免费阅读',
    '请收藏本站',
    '顶点小说',
    '八一中文网',
    '请记住本站',
    '手机版阅读网址',
    '笔趣阁 www',
    'https://',
    'http://',
    'www.',
    '.com',
    '.net',
    '.cc',
    '手机用户请',
    '请记住:域名',
    '章节错误',
    '点此举报',
    '加入书签',
    '方便下次阅读',
    '目录下载',
    '笔趣阁首发',
    '『章节错误',
    '顶点网址',
    '请记住:八一阵营',
    '天才地址',
    '燃文小说',
    '最快更新网站地址',
    '新域名',
    '请记住:新域名',
    'biqg.cc',
    'xbiquge.la',
  ];

  /// 获取配置，不存在则用默认值创建（幂等，线程安全）
  Future<CrawlConfig> getOrCreate() async {
    return _isar.writeTxn(() async {
      final existing = await _isar.crawlConfigs.where().findFirst();
      if (existing != null) return existing;

      final config = CrawlConfig()
        ..requestIntervalMs = defaultIntervalMs
        ..maxRetries = defaultMaxRetries
        ..timeoutMs = defaultTimeoutMs
        ..rotateUserAgent = defaultRotateUserAgent
        ..adKeywords = List<String>.from(defaultAdKeywords)
        ..prefetchChapters = defaultPrefetchChapters;

      await _isar.crawlConfigs.put(config);
      return config;
    });
  }

  /// 更新配置
  Future<void> update(CrawlConfig config) =>
      _isar.writeTxn(() async => _isar.crawlConfigs.put(config));
}
