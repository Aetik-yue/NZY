import 'package:flutter/foundation.dart';

import '../../core/network/app_http_client.dart';
import '../crawler/base_crawler.dart';
import '../crawler/biquge_crawler.dart';
import '../crawler/content_cleaner.dart';
import '../crawler/crawler_result.dart';
import '../models/crawl_config.dart';
import '../models/crawl_log.dart';
import '../models/novel.dart';
import '../models/novel_chapter.dart';
import '../models/novel_source.dart';
import 'crawl_config_repository.dart';
import 'crawl_log_repository.dart';
import 'novel_chapter_repository.dart';
import 'novel_repository.dart';
import 'novel_source_repository.dart';

/// 爬取协调器
///
/// 对外提供高层爬取接口，协调爬虫引擎、Repository 与配置。
class CrawlRepository {
  CrawlRepository({
    required this.novelRepository,
    required this.novelChapterRepository,
    required this.sourceRepository,
    required this.configRepository,
    required this.logRepository,
  });

  final NovelRepository novelRepository;
  final NovelChapterRepository novelChapterRepository;
  final NovelSourceRepository sourceRepository;
  final CrawlConfigRepository configRepository;
  final CrawlLogRepository logRepository;

  /// 取消令牌（UI 取消时设为 true）
  bool _cancelled = false;

  /// 取消当前爬取操作
  void cancel() {
    _cancelled = true;
  }

  /// 重置取消状态（每次操作前调用）
  void _resetCancellation() {
    _cancelled = false;
  }

  /// 检查是否已取消，若是则抛出异常
  void _checkCancelled() {
    if (_cancelled) {
      throw const CancelledException();
    }
  }

  /// 搜索小说（跨所有启用的源）
  Future<List<SearchResult>> search(String keyword) async {
    final sources = await sourceRepository.getEnabled();
    if (sources.isEmpty) return [];

    final config = await configRepository.getOrCreate();
    final results = <SearchResult>[];

    for (final source in sources) {
      try {
        final crawler = _createCrawler(source, config);
        final searchResults = await crawler.search(keyword);
        results.addAll(searchResults);
      } catch (e) {
        debugPrint('[CrawlRepository] 搜索失败 (${source.name}): $e');
      }
    }

    return results;
  }

  /// 按分类浏览小说（跨所有启用的源）
  ///
  /// [categoryId] 为分类 ID（1=玄幻 2=修真 3=都市 4=历史 5=网游 6=科幻 7=恐怖 8=其他），
  /// [page] 为页码（从 1 开始）。
  ///
  /// 搜索不可靠时，分类浏览是找书的可靠替代方案。
  Future<List<CategoryBook>> browseCategory(int categoryId,
      {int page = 1}) async {
    final sources = await sourceRepository.getEnabled();
    if (sources.isEmpty) return [];

    final config = await configRepository.getOrCreate();
    final results = <CategoryBook>[];

    for (final source in sources) {
      try {
        final crawler = _createCrawler(source, config);
        final books = await crawler.browseCategory(categoryId, page: page);
        results.addAll(books);
      } catch (e) {
        debugPrint('[CrawlRepository] 分类浏览失败 (${source.name}): $e');
      }
    }

    return results;
  }

  /// 从源站添加小说到书架
  ///
  /// [sourceUrl] 为书籍详情页 URL。
  /// [prefetchChapters] 为首抓时预取的章节正文数。
  ///
  /// 返回新增的 Novel。
  Future<Novel> addNovel(
    String sourceUrl, {
    int? prefetchChapters,
    void Function(String message, int current, int total)? onProgress,
  }) async {
    _resetCancellation();

    // 1. 确定源
    final source = await _resolveSourceByUrl(sourceUrl);
    final config = await configRepository.getOrCreate();
    final crawler = _createCrawler(source, config);

    // 2. 抓取书籍详情
    _checkCancelled();
    onProgress?.call('正在获取书籍详情...', 0, 0);
    final detail = await crawler.fetchBookDetail(sourceUrl);

    // 3. 写入 Novel
    final novel = Novel()
      ..title = detail.title.isEmpty ? '未知书名' : detail.title
      ..author = detail.author.isEmpty ? '佚名' : detail.author
      ..intro = detail.intro
      ..tags = []
      ..chapterCount = detail.chapters.length
      ..isBuiltin = false
      ..lastChapterIndex = -1
      ..lastPosition = 0.0
      ..coverColorValue = _coverColorFor(detail.title)
      ..createdAt = DateTime.now()
      ..sourceKey = source.key
      ..sourceBookId = _extractBookId(sourceUrl)
      ..sourceUrl = sourceUrl
      ..lastCrawlAt = DateTime.now()
      ..crawlStatus = 'success';

    _checkCancelled();
    await novelRepository.add(novel);

    // 4. 写入章节列表 + 预取正文
    final prefetch =
        prefetchChapters ?? config.prefetchChapters;
    final chaptersToFetch =
        detail.chapters.length < prefetch ? detail.chapters.length : prefetch;

    final chapters = <NovelChapter>[];
    for (var i = 0; i < detail.chapters.length; i++) {
      _checkCancelled();
      final ref = detail.chapters[i];
      String content = '';

      // 仅预取前 N 章正文
      if (i < chaptersToFetch) {
        onProgress?.call('正在抓取章节 ${i + 1}/$chaptersToFetch', i + 1, chaptersToFetch);
        try {
          final chapterContent = await crawler.fetchChapterContent(ref.url);
          content = chapterContent.content;
        } on CancelledException {
          rethrow;
        } catch (e) {
          debugPrint('[CrawlRepository] 章节抓取失败 (${ref.title}): $e');
          content = '（本章内容抓取失败，请稍后重试）';
        }
      }

      chapters.add(NovelChapter()
        ..novelId = novel.id
        ..chapterIndex = i
        ..title = ref.title
        ..content = content
        ..sourceChapterId = ref.sourceId
        ..sourceUrl = ref.url);
    }

    await novelChapterRepository.addAll(chapters);

    // 5. 更新日志
    await logRepository.add(CrawlLog()
      ..novelId = novel.id
      ..crawledAt = DateTime.now()
      ..status = 'success'
      ..message = '新增 ${detail.chapters.length} 章'
      ..newChapters = detail.chapters.length);

    onProgress?.call('完成', chaptersToFetch, chaptersToFetch);

    return novel;
  }

  /// 手动更新：抓取新章节（增量，基于 sourceChapterId 去重）
  ///
  /// 返回新增章节数。
  Future<int> updateNovel(
    int novelId, {
    void Function(String message, int current, int total)? onProgress,
  }) async {
    _resetCancellation();

    final novel = await novelRepository.getById(novelId);
    if (novel == null) {
      throw Exception('小说不存在');
    }
    if (novel.sourceUrl == null || novel.sourceKey == null) {
      throw Exception('该小说不支持更新（无源站信息）');
    }

    // 标记爬取中
    novel.crawlStatus = 'crawling';
    await novelRepository.update(novel);

    try {
      final source = await sourceRepository.getByKey(novel.sourceKey!);
      if (source == null) {
        throw Exception('爬取源不存在: ${novel.sourceKey}');
      }

      final config = await configRepository.getOrCreate();
      final crawler = _createCrawler(source, config);

      // 抓取最新详情
      _checkCancelled();
      onProgress?.call('正在获取最新章节列表...', 0, 0);
      final detail = await crawler.fetchBookDetail(novel.sourceUrl!);

      // 获取已有章节的 sourceChapterId 集合（用于去重）
      final existingChapters = await novelChapterRepository.watchByNovel(novelId).first;
      final existingIds = existingChapters
          .map((c) => c.sourceChapterId)
          .whereType<String>()
          .toSet();

      // 筛选新章节
      final newRefs = detail.chapters
          .where((ref) =>
              ref.sourceId.isNotEmpty && !existingIds.contains(ref.sourceId))
          .toList();

      if (newRefs.isEmpty) {
        // 无新章节
        novel.lastCrawlAt = DateTime.now();
        novel.crawlStatus = 'success';
        await novelRepository.update(novel);

        await logRepository.add(CrawlLog()
          ..novelId = novelId
          ..crawledAt = DateTime.now()
          ..status = 'success'
          ..message = '暂无新章节'
          ..newChapters = 0);

        return 0;
      }

      // 抓取新章节正文
      final startIndex = existingChapters.length;
      final newChapters = <NovelChapter>[];
      for (var i = 0; i < newRefs.length; i++) {
        _checkCancelled();
        final ref = newRefs[i];
        onProgress?.call(
          '正在抓取新章节 ${i + 1}/${newRefs.length}',
          i + 1,
          newRefs.length,
        );

        String content;
        try {
          final chapterContent = await crawler.fetchChapterContent(ref.url);
          content = chapterContent.content;
        } on CancelledException {
          rethrow;
        } catch (e) {
          debugPrint('[CrawlRepository] 新章节抓取失败 (${ref.title}): $e');
          content = '（本章内容抓取失败，请稍后重试）';
        }

        newChapters.add(NovelChapter()
          ..novelId = novelId
          ..chapterIndex = startIndex + i
          ..title = ref.title
          ..content = content
          ..sourceChapterId = ref.sourceId
          ..sourceUrl = ref.url);
      }

      await novelChapterRepository.addAll(newChapters);

      // 更新小说
      novel.chapterCount = detail.chapters.length;
      novel.lastCrawlAt = DateTime.now();
      novel.crawlStatus = 'success';
      await novelRepository.update(novel);

      // 写日志
      await logRepository.add(CrawlLog()
        ..novelId = novelId
        ..crawledAt = DateTime.now()
        ..status = 'success'
        ..message = '新增 ${newRefs.length} 章'
        ..newChapters = newRefs.length);

      onProgress?.call('完成', newRefs.length, newRefs.length);

      return newRefs.length;
    } catch (e) {
      // 标记失败
      novel.crawlStatus = 'failed';
      await novelRepository.update(novel);

      await logRepository.add(CrawlLog()
        ..novelId = novelId
        ..crawledAt = DateTime.now()
        ..status = 'failed'
        ..message = '更新失败: $e');

      rethrow;
    }
  }

  /// 按需抓取单章正文（用于阅读器中章节内容为空时）
  ///
  /// [chapterUrl] 为章节内容页 URL，[novelSourceKey] 为小说关联的源 key。
  /// 返回清洗后的正文文本。
  Future<String> fetchChapterContent({
    required String chapterUrl,
    required String novelSourceKey,
  }) async {
    final source = await sourceRepository.getByKey(novelSourceKey);
    if (source == null) {
      throw Exception('爬取源不存在: $novelSourceKey');
    }
    final config = await configRepository.getOrCreate();
    final crawler = _createCrawler(source, config);
    final chapterContent = await crawler.fetchChapterContent(chapterUrl);
    return chapterContent.content;
  }

  // ──────── 私有方法 ────────

  /// 创建爬虫实例
  BaseCrawler _createCrawler(NovelSource source, CrawlConfig config) {
    final httpClient = AppHttpClient(
      timeout: Duration(milliseconds: config.timeoutMs),
      maxRetries: config.maxRetries,
      minInterval: Duration(milliseconds: config.requestIntervalMs),
      rotateUserAgent: config.rotateUserAgent,
    );
    final contentCleaner = ContentCleaner(adPhrases: config.adKeywords);

    // 目前仅支持笔趣阁系列
    return BiqugeCrawler(
      source: source,
      httpClient: httpClient,
      contentCleaner: contentCleaner,
    );
  }

  /// 根据 URL 解析对应的源（基于 host 匹配，防止域名混淆攻击）
  Future<NovelSource> _resolveSourceByUrl(String url) async {
    final sources = await sourceRepository.getEnabled();
    final targetUri = Uri.tryParse(url);
    if (targetUri != null) {
      for (final source in sources) {
        final sourceUri = Uri.tryParse(source.baseUrl);
        if (sourceUri != null && targetUri.host == sourceUri.host) {
          return source;
        }
      }
    }
    // 兜底：返回第一个启用的源
    if (sources.isNotEmpty) return sources.first;
    throw Exception('没有可用的爬取源，请先在设置中添加');
  }

  /// 从书籍 URL 提取书籍 ID
  String _extractBookId(String url) {
    final match = RegExp(r'/(\d+)/?$').firstMatch(url);
    if (match != null) return match.group(1)!;

    final segments = url.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      return segments.last.replaceAll(RegExp(r'\.html?$'), '');
    }

    return url;
  }

  /// 根据书名生成稳定的封面色（取自 AppColors 调色板）
  static const List<int> _coverPalette = [
    0xFFFF6B9D, // accentRose
    0xFFFF8FB1, // accentPink
    0xFFFFB5A1, // accentCoral
    0xFFFFD1BF, // accentPeach
    0xFFB57DBA, // accentMauve
  ];

  int _coverColorFor(String title) {
    // 基于书名哈希选择颜色，同一本书每次结果一致
    final hash = title.hashCode;
    final index = hash.abs() % _coverPalette.length;
    return _coverPalette[index];
  }
}

/// 爬取操作被取消时抛出的异常
class CancelledException implements Exception {
  const CancelledException();
  @override
  String toString() => '爬取操作已取消';
}
