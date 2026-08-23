import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../app/theme/app_colors.dart';
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

  /// 章节预取/更新并发数（小窗口并行）。
  ///
  /// 配合 [AppHttpClient.minInterval] 做整站礼貌限速：同一批内 N 章并发，
  /// 批与批之间由 minInterval 保持间隔，兼顾速度与防封。
  static const int _chapterFetchConcurrency = 5;

  /// 源优先级：前两项是当前实测响应稳定的主搜索源，其余仅作降级。
  static const List<String> _sourcePriority = [
    'bqgbb',
    'biquge',
    'bqgecc',
    'bxwxorg',
    'biqumo',
  ];

  /// 同一关键词/分类短时间重复打开时直接复用结果，避免返回页面后再次爬站。
  static const Duration _positiveCacheTtl = Duration(minutes: 5);
  static const Duration _negativeCacheTtl = Duration(seconds: 30);

  final Map<String, ({DateTime expiresAt, List<SearchResult> value})>
      _searchCache = {};
  final Map<String, ({DateTime expiresAt, List<CategoryBook> value})>
      _categoryCache = {};

  /// 复用的 HTTP 客户端（避免每次操作新建连接后不释放）
  ///
  /// 配置未变化时复用同一实例；配置变化时关闭旧实例并重建。
  AppHttpClient? _httpClient;

  /// 获取（或复用）与配置匹配的 HTTP 客户端
  AppHttpClient _getHttpClient(CrawlConfig config) {
    final current = _httpClient;
    if (current != null &&
        current.timeout.inMilliseconds == config.timeoutMs &&
        current.maxRetries == config.maxRetries &&
        current.minInterval.inMilliseconds == config.requestIntervalMs &&
        current.rotateUserAgent == config.rotateUserAgent) {
      return current;
    }
    // 配置变化或首次创建：关闭旧实例避免连接泄漏
    current?.close();
    final client = AppHttpClient(
      timeout: Duration(milliseconds: config.timeoutMs),
      maxRetries: config.maxRetries,
      minInterval: Duration(milliseconds: config.requestIntervalMs),
      rotateUserAgent: config.rotateUserAgent,
    );
    _httpClient = client;
    return client;
  }

  /// 释放底层 HTTP 连接（应用退出时由 Provider 生命周期调用）
  void dispose() {
    _httpClient?.close();
    _httpClient = null;
    _searchCache.clear();
    _categoryCache.clear();
  }

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

  /// 有界并发映射
  ///
  /// 将 [items] 按 [concurrency] 分批，每批内并发执行 [fn]，批与批之间串行。
  /// 结果顺序与 [items] 一致。每批开始前检查取消；[fn] 抛出 [CancelledException]
  /// 时立即向上传播（取消整批），其他异常需由 [fn] 自行捕获并返回兜底值，
  /// 不中断批次。
  Future<List<R>> _mapWithConcurrency<T, R>(
    List<T> items,
    int concurrency,
    Future<R> Function(T item, int index) fn,
  ) async {
    final results = List<R?>.filled(items.length, null);
    for (var start = 0; start < items.length; start += concurrency) {
      _checkCancelled();
      final end = start + concurrency > items.length
          ? items.length
          : start + concurrency;
      final batch = <Future<void>>[];
      for (var i = start; i < end; i++) {
        final index = i;
        batch.add(fn(items[index], index).then((r) => results[index] = r));
      }
      await Future.wait(batch);
    }
    return results.cast<R>();
  }

  /// 搜索小说（主源优先，备用源按需启用）
  ///
  /// 旧实现同时启动所有源，并让每个源各自执行搜索引擎兜底；最终
  /// `Future.wait` 仍会等待最慢源。现在分为三级：
  /// 1. 两个主源并发站内搜索；有结果立即返回；
  /// 2. 主源无结果才并发探测备用源；
  /// 3. 全部站内搜索为空时，只选择一个主源做搜索引擎兜底。
  Future<List<SearchResult>> search(String keyword) async {
    final normalized = keyword.trim();
    if (normalized.isEmpty) return [];

    final cacheKey = normalized.toLowerCase();
    final cached = _searchCache[cacheKey];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.value;
    }

    final sources = _orderSources(await sourceRepository.getEnabled());
    if (sources.isEmpty) return [];

    final config = await configRepository.getOrCreate();
    final primarySources = sources.take(2).toList();
    final fallbackSources = sources.skip(primarySources.length).toList();

    List<SearchResult> results = await _searchSources(
      primarySources,
      config,
      normalized,
    );
    if (results.isEmpty && fallbackSources.isNotEmpty) {
      results = await _searchSources(
        fallbackSources,
        config,
        normalized,
      );
    }
    if (results.isEmpty) {
      // 所有站内搜索失败后只执行一次公共搜索引擎兜底。
      final crawler = _createCrawler(
        sources.first,
        config,
        enableSearchEngineFallback: false,
      );
      if (crawler is BiqugeCrawler) {
        results = await crawler.searchViaEngine(normalized);
      }
    }

    final deduped = List<SearchResult>.unmodifiable(
      _dedupeSearchResults(results),
    );
    _searchCache[cacheKey] = (
      expiresAt: DateTime.now().add(
        deduped.isEmpty ? _negativeCacheTtl : _positiveCacheTtl,
      ),
      value: deduped,
    );
    return deduped;
  }

  Future<List<SearchResult>> _searchSources(
    List<NovelSource> sources,
    CrawlConfig config,
    String keyword,
  ) async {
    if (sources.isEmpty) return [];

    final firstResult = Completer<List<SearchResult>>();
    var remaining = sources.length;
    for (final source in sources) {
      unawaited(() async {
        try {
          final crawler = _createCrawler(
            source,
            config,
            enableSearchEngineFallback: false,
          );
          return await crawler.search(keyword);
        } catch (e) {
          debugPrint('[CrawlRepository] 搜索失败 (${source.name}): $e');
          return <SearchResult>[];
        }
      }()
          .then((results) {
        if (results.isNotEmpty && !firstResult.isCompleted) {
          firstResult.complete(results);
        }
        remaining--;
        if (remaining == 0 && !firstResult.isCompleted) {
          firstResult.complete(<SearchResult>[]);
        }
      }));
    }
    return firstResult.future;
  }

  /// 按分类浏览小说（主源优先，备用源按需启用）
  ///
  /// [categoryId] 为分类 ID（1=玄幻 2=修真 3=都市 4=历史 5=网游 6=科幻 7=恐怖 8=其他），
  /// [page] 为页码（从 1 开始）。
  ///
  /// 搜索不可靠时，分类浏览是找书的可靠替代方案。
  Future<List<CategoryBook>> browseCategory(int categoryId,
      {int page = 1}) async {
    final cacheKey = '$categoryId:$page';
    final cached = _categoryCache[cacheKey];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached.value;
    }

    final sources = _orderSources(await sourceRepository.getEnabled());
    if (sources.isEmpty) return [];

    final config = await configRepository.getOrCreate();
    final primarySources = sources.take(2).toList();
    final fallbackSources = sources.skip(primarySources.length).toList();

    List<CategoryBook> results = await _browseSources(
      primarySources,
      config,
      categoryId,
      page,
    );
    if (results.isEmpty && fallbackSources.isNotEmpty) {
      results = await _browseSources(
        fallbackSources,
        config,
        categoryId,
        page,
      );
    }

    final deduped = List<CategoryBook>.unmodifiable(
      _dedupeCategoryBooks(results),
    );
    _categoryCache[cacheKey] = (
      expiresAt: DateTime.now().add(
        deduped.isEmpty ? _negativeCacheTtl : _positiveCacheTtl,
      ),
      value: deduped,
    );
    return deduped;
  }

  Future<List<CategoryBook>> _browseSources(
    List<NovelSource> sources,
    CrawlConfig config,
    int categoryId,
    int page,
  ) async {
    if (sources.isEmpty) return [];

    final firstResult = Completer<List<CategoryBook>>();
    var remaining = sources.length;
    for (final source in sources) {
      unawaited(() async {
        try {
          final crawler = _createCrawler(
            source,
            config,
            enableSearchEngineFallback: false,
          );
          return await crawler.browseCategory(categoryId, page: page);
        } catch (e) {
          debugPrint('[CrawlRepository] 分类浏览失败 (${source.name}): $e');
          return <CategoryBook>[];
        }
      }()
          .then((results) {
        if (results.isNotEmpty && !firstResult.isCompleted) {
          firstResult.complete(results);
        }
        remaining--;
        if (remaining == 0 && !firstResult.isCompleted) {
          firstResult.complete(<CategoryBook>[]);
        }
      }));
    }
    return firstResult.future;
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

    // 记录已创建的小说，用于中途失败/取消时回滚半成品
    Novel? created;

    try {
      // 1. 确定源
      final source = await _resolveSourceByUrl(sourceUrl);
      final config = await configRepository.getOrCreate();
      final crawler = _createCrawler(source, config);

      // 1.5 去重：同一源站 URL 已在书架则拒绝重复添加
      final existing = await novelRepository.findBySourceUrl(sourceUrl);
      if (existing != null) {
        throw NovelAlreadyExistsException(existing);
      }

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
      created = novel;
      await novelRepository.add(novel);

      // 4. 写入章节列表 + 预取正文（前 N 章有界并发抓取）
      final prefetch = prefetchChapters ?? config.prefetchChapters;
      final chaptersToFetch =
          detail.chapters.length < prefetch ? detail.chapters.length : prefetch;

      // 并发预取前 N 章正文：每批 _chapterFetchConcurrency 章并行，结果保持顺序。
      final prefetchRefs = detail.chapters.take(chaptersToFetch).toList();
      var prefetchedContents = <String>[];
      if (prefetchRefs.isNotEmpty) {
        var doneCount = 0;
        onProgress?.call('正在抓取章节 0/$chaptersToFetch', 0, chaptersToFetch);
        prefetchedContents = await _mapWithConcurrency<ChapterRef, String>(
          prefetchRefs,
          _chapterFetchConcurrency,
          (ref, _) async {
            try {
              final chapterContent = await crawler.fetchChapterContent(ref.url);
              return chapterContent.content;
            } on CancelledException {
              rethrow;
            } catch (e) {
              debugPrint('[CrawlRepository] 章节抓取失败 (${ref.title}): $e');
              // 留空正文：阅读器会对空章节自动按需重抓并提供重试入口
              return '';
            } finally {
              doneCount++;
              onProgress?.call(
                '正在抓取章节 $doneCount/$chaptersToFetch',
                doneCount,
                chaptersToFetch,
              );
            }
          },
        );
      }

      // 组装全部章节：预取的带正文，其余留空待阅读器按需重抓
      final chapters = <NovelChapter>[];
      for (var i = 0; i < detail.chapters.length; i++) {
        final ref = detail.chapters[i];
        chapters.add(NovelChapter()
          ..novelId = novel.id
          ..chapterIndex = i
          ..title = ref.title
          ..content = i < chaptersToFetch ? prefetchedContents[i] : ''
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
    } catch (_) {
      // 取消或失败：回滚半成品，避免书架残留 0 章/缺章小说
      if (created != null) {
        try {
          await novelChapterRepository.deleteByNovel(created.id);
          await novelRepository.delete(created.id);
        } catch (e) {
          debugPrint('[CrawlRepository] 添加回滚失败: $e');
        }
      }
      rethrow;
    }
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
      final existingChapters = await novelChapterRepository.getByNovel(novelId);
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

      // 用源站规范顺序重排已有章节索引（处理源站中段插章/删章导致的错乱）
      await _renumberChaptersToCanonical(
        detail.chapters,
        existingChapters,
      );

      // 抓取新章节正文（chapterIndex = 源站规范序列中的真实位置；有界并发）
      // newChapterIndices 与 newRefs 一一对应，均按源站规范顺序排列，
      // 故 newChapterIndices[j] 即 newRefs[j] 在 detail.chapters 中的位置。
      final newChapterIndices = <int>[];
      for (var i = 0; i < detail.chapters.length; i++) {
        final ref = detail.chapters[i];
        if (ref.sourceId.isNotEmpty && !existingIds.contains(ref.sourceId)) {
          newChapterIndices.add(i);
        }
      }

      final newChapters = <NovelChapter>[];
      if (newRefs.isNotEmpty) {
        var fetchedCount = 0;
        onProgress?.call('正在抓取新章节 0/${newRefs.length}', 0, newRefs.length);
        final contents = await _mapWithConcurrency<ChapterRef, String>(
          newRefs,
          _chapterFetchConcurrency,
          (ref, _) async {
            try {
              final chapterContent = await crawler.fetchChapterContent(ref.url);
              return chapterContent.content;
            } on CancelledException {
              rethrow;
            } catch (e) {
              debugPrint('[CrawlRepository] 新章节抓取失败 (${ref.title}): $e');
              // 留空正文：阅读器会对空章节自动按需重抓并提供重试入口
              return '';
            } finally {
              fetchedCount++;
              onProgress?.call(
                '正在抓取新章节 $fetchedCount/${newRefs.length}',
                fetchedCount,
                newRefs.length,
              );
            }
          },
        );

        for (var j = 0; j < newRefs.length; j++) {
          final ref = newRefs[j];
          newChapters.add(NovelChapter()
            ..novelId = novelId
            ..chapterIndex = newChapterIndices[j]
            ..title = ref.title
            ..content = contents[j]
            ..sourceChapterId = ref.sourceId
            ..sourceUrl = ref.url);
        }
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
    } on CancelledException {
      // 用户主动取消：恢复原状态（不标记失败、不写失败日志）
      novel.crawlStatus = 'success';
      await novelRepository.update(novel);
      rethrow;
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

  /// 按源站规范顺序重排已有章节的 chapterIndex
  ///
  /// 源站中段插章/删章后，既有章节的 index 会与规范顺序错位，导致
  /// 阅读器排序错乱。此方法将每个已有章节的 index 校正为其在源站
  /// 序列中的真实位置；源站已删除的章节（无对应条目）顺延到末尾，
  /// 保持相对顺序，避免与新章节的索引碰撞。
  Future<void> _renumberChaptersToCanonical(
    List<ChapterRef> canonical,
    List<NovelChapter> existing,
  ) async {
    final indexBySourceId = <String, int>{};
    for (var i = 0; i < canonical.length; i++) {
      if (canonical[i].sourceId.isNotEmpty) {
        indexBySourceId[canonical[i].sourceId] = i;
      }
    }

    final toUpdate = <NovelChapter>[];
    final unmapped = <NovelChapter>[];
    for (final ch in existing) {
      final sid = ch.sourceChapterId;
      final canonicalIndex = (sid != null) ? indexBySourceId[sid] : null;
      if (canonicalIndex != null) {
        if (ch.chapterIndex != canonicalIndex) {
          ch.chapterIndex = canonicalIndex;
          toUpdate.add(ch);
        }
      } else {
        unmapped.add(ch);
      }
    }

    // 源站已删除的章节：顺延到规范序列末尾，避免索引碰撞
    if (unmapped.isNotEmpty) {
      unmapped.sort((a, b) => a.chapterIndex.compareTo(b.chapterIndex));
      var tailIndex = canonical.length;
      for (final ch in unmapped) {
        ch.chapterIndex = tailIndex++;
        toUpdate.add(ch);
      }
    }

    if (toUpdate.isNotEmpty) {
      await novelChapterRepository.addAll(toUpdate);
    }
  }

  /// 按已知可用性排序；未知自定义源保持原始相对顺序并排在已知源之后。
  List<NovelSource> _orderSources(List<NovelSource> sources) {
    final priorities = <String, int>{
      for (var i = 0; i < _sourcePriority.length; i++) _sourcePriority[i]: i,
    };
    final originalOrder = <String, int>{
      for (var i = 0; i < sources.length; i++) sources[i].key: i,
    };
    final ordered = List<NovelSource>.from(sources);
    ordered.sort((a, b) {
      final pa = priorities[a.key] ?? _sourcePriority.length;
      final pb = priorities[b.key] ?? _sourcePriority.length;
      final priorityComparison = pa.compareTo(pb);
      if (priorityComparison != 0) return priorityComparison;
      return originalOrder[a.key]!.compareTo(originalOrder[b.key]!);
    });
    return ordered;
  }

  /// 跨镜像去重：标准化后的书名和作者均相同时，只保留优先源结果。
  List<SearchResult> _dedupeSearchResults(List<SearchResult> results) {
    final seen = <String>{};
    final deduped = <SearchResult>[];
    for (final result in results) {
      final key = _bookIdentity(result.title, result.author);
      if (!seen.add(key)) continue;
      deduped.add(result);
    }
    return deduped;
  }

  List<CategoryBook> _dedupeCategoryBooks(List<CategoryBook> books) {
    final seen = <String>{};
    final deduped = <CategoryBook>[];
    for (final book in books) {
      final key = _bookIdentity(book.title, book.author);
      if (!seen.add(key)) continue;
      deduped.add(book);
    }
    return deduped;
  }

  String _bookIdentity(String title, String author) {
    final normalizedTitle =
        title.replaceAll(RegExp(r'[《》\s]'), '').toLowerCase();
    final normalizedAuthor = author
        .replaceAll(RegExp(r'^(作者|著者)\s*[:：]?\s*'), '')
        .replaceAll(RegExp(r'\s'), '')
        .toLowerCase();
    return '$normalizedTitle|$normalizedAuthor';
  }

  /// 创建爬虫实例
  BaseCrawler _createCrawler(
    NovelSource source,
    CrawlConfig config, {
    bool enableSearchEngineFallback = true,
  }) {
    final httpClient = _getHttpClient(config);
    final contentCleaner = ContentCleaner(adPhrases: config.adKeywords);

    // 目前仅支持笔趣阁系列
    return BiqugeCrawler(
      source: source,
      httpClient: httpClient,
      contentCleaner: contentCleaner,
      enableSearchEngineFallback: enableSearchEngineFallback,
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
  ///
  /// 兼容多站点书籍详情页路径：
  /// - /book/{id}/ /read/{id}/ /chapter/{id}/   (biquge2 / bqgbb / bqge.cc / bxwxorg)
  /// - /{d}_{d}/                                (biqumo)
  /// - /{id}/                                   (纯数字末段)
  /// - /{d}/{d}/{d}.html                        (经典笔趣阁)
  String _extractBookId(String url) {
    // /book/{id}/ /read/{id}/ /chapter/{id}/
    var match = RegExp(r'/(?:book|read|chapter)/(\d+)/?$').firstMatch(url);
    if (match != null) return match.group(1)!;
    // biqumo: /{d}_{d}/
    match = RegExp(r'/(\d+_\d+)/?$').firstMatch(url);
    if (match != null) return match.group(1)!;
    // 末段纯数字 /{id}/
    match = RegExp(r'/(\d+)/?$').firstMatch(url);
    if (match != null) return match.group(1)!;

    final segments = url.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      return segments.last.replaceAll(RegExp(r'\.html?$'), '');
    }

    return url;
  }

  /// 根据书名生成稳定的封面色（取自 AppColors.coverPalette 设计令牌）
  int _coverColorFor(String title) {
    // 基于书名哈希选择颜色，同一本书每次结果一致
    final hash = title.hashCode;
    final index = hash.abs() % AppColors.coverPalette.length;
    return AppColors.coverPalette[index].toARGB32();
  }
}

/// 爬取操作被取消时抛出的异常
class CancelledException implements Exception {
  const CancelledException();
  @override
  String toString() => '爬取操作已取消';
}

/// 小说已在书架中时抛出的异常（携带已存在的条目，供 UI 跳转详情）
class NovelAlreadyExistsException implements Exception {
  const NovelAlreadyExistsException(this.novel);
  final Novel novel;
  @override
  String toString() => '《${novel.title}》已在书架中';
}
