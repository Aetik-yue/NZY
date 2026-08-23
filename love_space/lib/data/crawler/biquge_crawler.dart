import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/network/app_http_client.dart';
import '../../core/network/user_agent_rotator.dart';
import '../models/novel_source.dart';
import 'base_crawler.dart';
import 'content_cleaner.dart';
import 'crawler_result.dart';

/// 搜索尝试配置（端点 + 参数）
class _SearchAttempt {
  final String path;
  final Map<String, String> params;
  const _SearchAttempt(this.path, this.params);
}

/// 单个目录分页的抓取结果。
class _TocPageResult {
  const _TocPageResult({
    required this.url,
    this.html,
    this.error,
  });

  final String url;
  final String? html;
  final Object? error;
}

/// 笔趣阁系列站点爬虫实现
///
/// 支持符合以下 HTML 结构的笔趣阁镜像站：
/// - 搜索页：搜索结果列表含书名链接
/// - 详情页：#info（书名/作者）、#intro（简介）、#list dd a（章节列表）
/// - 内容页：.bookname h1（章节标题）、#content（正文）
class BiqugeCrawler implements BaseCrawler {
  BiqugeCrawler({
    required this.source,
    AppHttpClient? httpClient,
    ContentCleaner? contentCleaner,
    this.enableSearchEngineFallback = true,
  })  : _httpClient = httpClient ?? AppHttpClient(),
        _contentCleaner = contentCleaner ?? ContentCleaner();

  final NovelSource source;
  final AppHttpClient _httpClient;
  final ContentCleaner _contentCleaner;

  /// 是否在站内搜索失败后继续请求公共搜索引擎。
  ///
  /// 跨源协调器会先快速探测全部站内搜索，仅在全部无结果时选择一个源执行
  /// 搜索引擎兜底，避免每个源都重复请求 Bing / 搜狗 / 360。
  final bool enableSearchEngineFallback;

  /// 搜索和分类都是“可切换源”的发现请求，单个端点不应占满正文抓取的 15 秒。
  static const Duration _discoveryTimeout = Duration(seconds: 8);

  /// 长篇小说目录常有数十页，每批并发 5 页可显著缩短加入书架等待时间。
  static const int _tocFetchConcurrency = 5;

  @override
  String get sourceKey => source.key;

  @override
  String get sourceName => source.name;

  @override
  String get baseUrl => source.baseUrl;

  @override
  Future<List<SearchResult>> search(String keyword) async {
    final kw = keyword.trim();
    if (kw.isEmpty) return [];

    // 搜索使用 POST 表单提交。按源选择已知正确端点，避免每个源都盲试同一组
    // 地址；未知的自定义源仍保留通用候选作为兼容路径。
    final searchAttempts = _searchAttemptsForSource(kw);

    for (final attempt in searchAttempts) {
      try {
        final url = '$baseUrl${attempt.path}';
        final body = await _httpClient.postOnce(
          url,
          body: attempt.params,
          headers: {'Referer': '$baseUrl/'},
          timeoutOverride: _discoveryTimeout,
        );

        // 检测搜索间隔限制提示
        if (body.contains('搜索间隔') || body.contains('请于')) {
          debugPrint('[BiqugeCrawler] 命中搜索间隔限制，跳过 $url');
          continue;
        }

        final results = _parseSearchResult(body, keyword: kw);
        if (results.isNotEmpty) return results;
      } catch (e) {
        debugPrint('[BiqugeCrawler] 搜索 ${attempt.path} 失败: $e');
      }
    }

    // 站内搜索全部失败。跨源搜索时由 Repository 统一选择一个源做兜底，
    // 单独使用 crawler 时仍保持原有完整行为。
    if (!enableSearchEngineFallback) return [];
    return searchViaEngine(kw);
  }

  /// 返回当前源最可能成功的站内搜索端点。
  ///
  /// 已知源只探测 1 个地址；未知自定义源才使用完整通用候选。
  List<_SearchAttempt> _searchAttemptsForSource(String keyword) {
    switch (source.key) {
      case 'bqgbb':
        return [
          _SearchAttempt('/search.php', {'searchkey': keyword}),
        ];
      case 'biquge':
        return [
          _SearchAttempt('/search.html', {'s': keyword}),
        ];
      case 'bqgecc':
        return [
          _SearchAttempt('/search.html', {'searchkey': keyword}),
        ];
      case 'biqumo':
      case 'bxwxorg':
        return [
          _SearchAttempt('/modules/article/search.php', {
            'searchkey': keyword,
            'searchtype': 'novelname',
          }),
        ];
      default:
        return [
          _SearchAttempt('/search.php', {'searchkey': keyword}),
          _SearchAttempt('/search.html', {'s': keyword}),
          _SearchAttempt('/search.html', {'searchkey': keyword}),
          _SearchAttempt('/modules/article/search.php', {
            'searchkey': keyword,
            'searchtype': 'novelname',
          }),
        ];
    }
  }

  /// 搜索引擎兜底：用多引擎 site: 搜索找书籍详情页 URL
  ///
  /// 笔趣阁镜像站站内搜索普遍失效（404 / JS 渲染 / 搜索索引损坏），
  /// 通过搜索引擎检索 `site:<baseUrl> 书名` 是找到书籍 URL 的最后手段。
  ///
  /// 并发尝试 Bing / 搜狗 / 360，在一个超时窗口内收集结果，任一命中即返回：
  /// - 国内网络下各引擎可用性不同，因此保留三个互补入口
  /// - 结果链接常被包装成重定向 URL（如 bing.com/ck/a），
  ///   需先解出真实地址再匹配书籍 URL 模式
  Future<List<SearchResult>> searchViaEngine(String keyword) async {
    final host = Uri.parse(baseUrl).host;
    // 转义 host 中的正则元字符（如 .）；注意不能用 raw string，否则 $hostPattern 不参与插值
    final hostPattern = RegExp.escape(host);
    // 匹配源站书籍 URL（bqgbb / biquge2 均为 /book/{id}/）
    final bookRe = RegExp('https?://[^/]*$hostPattern/book/[0-9]+/?');

    final query = Uri.encodeQueryComponent('site:$host $keyword');
    // 仅作为最后一级兜底，并发请求三个国内较常用入口；每个请求最多 8 秒。
    // 旧实现逐个请求 5 个引擎，最坏耗时会线性叠加。
    final engines = <String, String>{
      'bing': 'https://www.bing.com/search?q=$query',
      'sogou': 'https://www.sogou.com/web?query=$query',
      '360': 'https://www.so.com/s?q=$query',
    };

    final firstResult = Completer<List<SearchResult>>();
    var remaining = engines.length;

    for (final entry in engines.entries) {
      unawaited(() async {
        try {
          final body = await _httpClient.getOnce(entry.value,
              headers: {
                'User-Agent': UserAgentRotator.random,
                'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
              },
              timeoutOverride: _discoveryTimeout);

          final results = _parseEngineResults(body, bookRe);
          if (results.isNotEmpty) {
            debugPrint('[BiqugeCrawler] ${entry.key} 找到 ${results.length} 条');
          }
          return results;
        } catch (e) {
          debugPrint('[BiqugeCrawler] 搜索引擎 ${entry.key} 失败: $e');
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

    // 任一引擎先命中就立即返回；全部失败时最长仍只等待一个 8 秒窗口。
    return firstResult.future;
  }

  /// 解析搜索引擎结果页，提取指向源站书籍页的链接
  ///
  /// 每个结果链接先用 [_extractRedirectTarget] 解出真实地址（绕过搜索引擎的
  /// 重定向包装），再匹配书籍 URL 模式；命中后去重并截断到 10 条。
  List<SearchResult> _parseEngineResults(String html, RegExp bookRe) {
    final document = html_parser.parse(html);
    final results = <SearchResult>[];
    final seen = <String>{};

    for (final link in document.querySelectorAll('a[href]')) {
      final rawHref = link.attributes['href'] ?? '';
      final title = link.text.trim();
      if (title.isEmpty || title.length < 2) continue;

      final realUrl = _extractRedirectTarget(rawHref) ?? rawHref;
      final match = bookRe.firstMatch(realUrl);
      if (match == null) continue;

      final url = match.group(0)!;
      if (seen.contains(url)) continue;
      seen.add(url);
      results.add(SearchResult(title: title, author: '', url: url));
      if (results.length >= 10) break;
    }
    return results;
  }

  /// 从搜索引擎重定向 URL 中解出真实目标地址
  ///
  /// - Bing：`u=<base64url>`（对真实 URL encodeURIComponent 后 base64）
  /// - Google：`q=<url>`（URL 编码）
  /// - 360 / 搜狗：`url=<base64url>`
  /// 解不出时返回 null，由调用方直接用原 href 匹配。
  String? _extractRedirectTarget(String href) {
    final uri = Uri.tryParse(href);
    if (uri == null || uri.queryParameters.isEmpty) return null;

    final encoded = uri.queryParameters['u'] ??
        uri.queryParameters['q'] ??
        uri.queryParameters['url'];
    if (encoded == null || encoded.isEmpty) return null;

    // 优先按 base64url 解码（Bing / 360 常见）
    var b64 = encoded.replaceAll('-', '+').replaceAll('_', '/');
    while (b64.length % 4 != 0) {
      b64 += '=';
    }
    try {
      return utf8.decode(base64.decode(b64));
    } catch (_) {
      // 非 base64（如 Google 的 q= 直接是 URL）时按 URL 解码
      return Uri.decodeFull(encoded);
    }
  }

  @override
  Future<List<CategoryBook>> browseCategory(int categoryId,
      {int page = 1}) async {
    final urlCandidates = _categoryUrlsForSource(categoryId, page);

    for (final url in urlCandidates) {
      try {
        final body = await _httpClient.getOnce(
          url,
          timeoutOverride: _discoveryTimeout,
        );
        final books = _parseCategoryPage(body);
        if (books.isNotEmpty) return books;
      } catch (e) {
        debugPrint('[BiqugeCrawler] 分类浏览尝试失败 ($url): $e');
      }
    }

    return [];
  }

  /// 按源排列分类页 URL，常用正确地址优先。
  List<String> _categoryUrlsForSource(int categoryId, int page) {
    final biquge = '$baseUrl/fenlei/lastupdate_${categoryId}_0_0_$page.html';
    final bqgbb = '$baseUrl/fenlei/$categoryId/$page.html';
    final compact = '$baseUrl/fenlei/${categoryId}_$page/';
    final compactHtml = '$baseUrl/fenlei/${categoryId}_$page.html';

    return switch (source.key) {
      'biquge' => [biquge],
      'bqgbb' => [bqgbb],
      _ => [compact, compactHtml, bqgbb, biquge],
    };
  }

  /// 解析分类页 HTML，提取书籍列表
  ///
  /// 兼容两种镜像结构：
  /// - biquge2.net: <div class="item"> 卡片（含简介/字数/更新时间）
  /// - bqgbb.cc:    <li><a href="/book/xxx/">书名</a><span>作者</span></li>
  List<CategoryBook> _parseCategoryPage(String html) {
    final document = html_parser.parse(html);
    final results = <CategoryBook>[];
    final seen = <String>{};

    void addBook(String title, String href, String author,
        {String intro = '', String wordCount = '', String updateTime = ''}) {
      if (title.isEmpty || href.isEmpty) return;
      final bookUrl = _canonicalBookUrl(href);
      if (bookUrl == null) return;
      if (seen.contains(bookUrl)) return;
      seen.add(bookUrl);

      results.add(CategoryBook(
        title: title,
        author: author,
        url: bookUrl,
        intro: intro,
        wordCount: wordCount,
        updateTime: updateTime,
      ));
    }

    // 策略 1: biquge2.net 的 <div class="item"> 卡片
    final items = document.querySelectorAll('.item');
    for (final item in items) {
      final link = item.querySelector('a[href*="/book/"]');
      if (link == null) continue;
      final href = link.attributes['href'] ?? '';
      final title = link.attributes['title']?.trim() ?? link.text.trim();

      // 简介
      final introEl = item.querySelector('dd');
      final intro = introEl?.text.trim() ?? '';

      // 作者 + 字数 + 时间（在 .btm 中）
      String author = '';
      String wordCount = '';
      String updateTime = '';
      final btm = item.querySelector('.btm');
      if (btm != null) {
        final btmText = btm.text.trim();
        final ems = btm.querySelectorAll('em');
        author = btmText.split(RegExp(r'\s')).first.trim();
        if (ems.isNotEmpty) wordCount = ems.first.text.trim();
        if (ems.length > 1) updateTime = ems[1].text.trim();
      }

      addBook(title, href, author,
          intro: intro, wordCount: wordCount, updateTime: updateTime);
    }

    // 策略 2: bqgbb.cc 的 <li><a>书名</a><span>作者</span></li>
    if (results.isEmpty) {
      for (final li in document.querySelectorAll('li')) {
        final link = li.querySelector('a[href*="/book/"]');
        if (link == null) continue;
        final href = link.attributes['href'] ?? '';
        final title = link.text.trim();
        if (title.isEmpty) continue;

        String author = '';
        final authorSpan = li.querySelector('span');
        if (authorSpan != null) author = authorSpan.text.trim();

        addBook(title, href, author);
      }
    }

    return results;
  }

  @override
  Future<BookDetail> fetchBookDetail(String url) async {
    final body = await _httpClient.get(url);
    final detail = _parseBookDetail(body, url);

    // 尝试从完整章节目录页抓取章节列表（biquge2.net 的 /book/{id}/ml_*.html）
    // 详情页本身的章节列表通常不完整/乱序，目录页更可靠
    final tocChapters = await _fetchChaptersFromToc(url, body);
    if (tocChapters.isNotEmpty) {
      return BookDetail(
        title: detail.title,
        author: detail.author,
        intro: detail.intro,
        chapters: tocChapters,
      );
    }

    return detail;
  }

  /// 从章节目录页抓取完整章节列表
  ///
  /// biquge2.net 的目录页 URL 形如 /book/{id}/ml_1.html、ml_2.html...
  /// 详情页里会包含指向 ml_1.html 的链接。此处合并所有分页并按章号排序去重。
  Future<List<ChapterRef>> _fetchChaptersFromToc(
    String bookUrl,
    String detailHtml,
  ) async {
    var consecutiveEmptyTocPages = 0; // 连续无新章节的目录页数
    final doc = html_parser.parse(detailHtml);
    // 找目录页链接（ml_N.html 或 index_N.html），用于补充分页章节
    final tocLink = doc
        .querySelectorAll('a[href]')
        .map((a) => a.attributes['href'] ?? '')
        .firstWhere(
          (href) => RegExp(r'/book/\d+/(ml|index)_\d+\.html').hasMatch(href),
          orElse: () => '',
        );
    // 判断目录页前缀（ml_ 或 index_）
    final tocPrefix =
        RegExp(r'/(ml|index)_\d+\.html').firstMatch(tocLink)?.group(1) ?? 'ml';

    // 提取 bookId 用于构造后续分页 URL（兼容 /book/ /read/ /chapter/ 路径）
    final bookIdMatch =
        RegExp(r'/(?:book|read|chapter)/(\d+)/').firstMatch(bookUrl);
    final bookId = bookIdMatch?.group(1);
    if (bookId == null) return [];

    final allChapters = <ChapterRef>[];
    final seenIds = <String>{};

    // 0. 先从详情页本身提取章节链接（biquge2.net 详情页含最近 ~100 章正序链接）
    final detailDoc = html_parser.parse(detailHtml);
    for (final link in detailDoc.querySelectorAll('a[href]')) {
      final href = link.attributes['href'] ?? '';
      // 匹配章节内容页（兼容 /book/ /read/ /chapter/ /{d}_{d}/ 路径，含分页 _N.html）
      if (!_chapterUrlRe.hasMatch(href)) continue;
      // 跳过目录分页
      if (RegExp(r'/ml_\d+\.html$').hasMatch(href)) continue;

      final title = link.text.trim();
      if (title.isEmpty ||
          title.contains('目录') ||
          title.contains('书页') ||
          title.contains('开始阅读')) {
        continue;
      }

      final chapterUrl = _resolveUrl(href, bookUrl);
      final sourceId = _extractChapterId(chapterUrl);
      if (seenIds.contains(sourceId)) continue;
      seenIds.add(sourceId);

      allChapters.add(ChapterRef(
        title: title,
        url: chapterUrl,
        sourceId: sourceId,
      ));
    }

    // 1. 抓取目录分页补充详情页未覆盖的章节（仅当详情页存在目录链接时）。
    //    URL 页码是可预测的，因此按 5 页一批并发获取、按页码顺序解析；
    //    相比逐页等待，长篇目录的墙钟时间约降为原来的 1/5。最后一批可能
    //    多探测最多 4 页，但空页/404 会很快结束。100 页是病态站点安全上限。
    if (tocLink.isNotEmpty) {
      var reachedEnd = false;
      for (var batchStart = 1;
          batchStart <= 100 && !reachedEnd;
          batchStart += _tocFetchConcurrency) {
        final pageNumbers = <int>[];
        for (var offset = 0; offset < _tocFetchConcurrency; offset++) {
          final page = batchStart + offset;
          if (page > 100) break;
          pageNumbers.add(page);
        }

        final batch = await Future.wait(
          pageNumbers.map(
            (page) => _fetchTocPage(bookId, tocPrefix, page),
          ),
        );

        // 网络完成顺序不影响章节顺序；始终按 pageNumbers 的顺序解析。
        for (final result in batch) {
          if (result.error != null || result.html == null) {
            debugPrint(
              '[BiqugeCrawler] 目录页 ${result.url} 抓取失败: ${result.error}',
            );
            reachedEnd = true;
            break;
          }

          final pageDoc = html_parser.parse(result.html!);
          final links = pageDoc.querySelectorAll('a[href]');

          var hasAnyChapterLink = false;
          var foundNewChapter = false;
          for (final link in links) {
            final href = link.attributes['href'] ?? '';
            // 匹配章节内容页（兼容多站点路径，含分页 _N.html），排除 ml_*.html 目录页自身
            if (!_chapterUrlRe.hasMatch(href)) continue;
            if (RegExp(r'/ml_\d+\.html$').hasMatch(href)) continue;

            hasAnyChapterLink = true;

            final title = link.text.trim();
            if (title.isEmpty || title.contains('目录') || title.contains('书页')) {
              continue;
            }

            // 用基础 chapterId 去重（135023 而非 135023_1）
            final chapterUrl = _resolveUrl(href, result.url);
            final sourceId = _extractChapterId(chapterUrl);
            if (seenIds.contains(sourceId)) continue;
            seenIds.add(sourceId);

            allChapters.add(ChapterRef(
              title: title,
              url: chapterUrl,
              sourceId: sourceId,
            ));
            foundNewChapter = true;
          }
          // 只有该页完全没有章节链接时才终止（说明已到目录末尾）
          // 如果该页有章节但全为重复，继续抓下一页（可能有新章节）
          if (!hasAnyChapterLink) {
            reachedEnd = true;
            break;
          }
          // 连续 2 页无新章节时终止（避免无限抓取空页）
          if (!foundNewChapter) {
            if (consecutiveEmptyTocPages++ >= 1) {
              reachedEnd = true;
              break;
            }
          } else {
            consecutiveEmptyTocPages = 0;
          }
        }
      }
    }

    // 按章号排序（从标题提取"第N章"的数字）
    allChapters.sort((a, b) {
      final na = _chapterNumber(a.title);
      final nb = _chapterNumber(b.title);
      if (na == null && nb == null) return 0;
      if (na == null) return 1;
      if (nb == null) return -1;
      return na.compareTo(nb);
    });

    return allChapters;
  }

  Future<_TocPageResult> _fetchTocPage(
    String bookId,
    String tocPrefix,
    int page,
  ) async {
    final url = '$baseUrl/book/$bookId/${tocPrefix}_$page.html';
    try {
      return _TocPageResult(
        url: url,
        html: await _httpClient.get(url),
      );
    } catch (error) {
      return _TocPageResult(url: url, error: error);
    }
  }

  /// 从章节标题提取章号（"第123章..." → 123）
  int? _chapterNumber(String title) {
    final m = RegExp(r'第\s*(\d+)\s*章').firstMatch(title);
    if (m != null) return int.tryParse(m.group(1)!);
    return null;
  }

  @override
  Future<ChapterContent> fetchChapterContent(String url) async {
    final parts = <String>[];
    var title = '';
    var currentUrl = url;
    // 已抓取 URL 集合：彻底防回链 / 重复分页（与 _nextPageUrl 的 page+1 递进双保险）
    final seen = <String>{};
    // 防止恶意循环，最多拼接 20 页
    for (var i = 0; i < 20; i++) {
      // 已抓过此 URL 则终止（回链 / 重复页）
      if (!seen.add(currentUrl)) break;
      String body;
      try {
        body = await _httpClient.get(currentUrl);
      } catch (e) {
        // 中间页抓取失败：返回已抓取的部分内容，不全部丢弃
        debugPrint('[BiqugeCrawler] 第 ${i + 1} 页抓取失败，返回部分内容: $e');
        break;
      }
      final parsed = _parseChapterContent(body);
      if (title.isEmpty) title = parsed.title;
      parts.add(parsed.content);

      // 检测同章下一页链接（{chapterId}_{N}.html 模式）
      final nextPageUrl = _nextPageUrl(body, currentUrl);
      if (nextPageUrl == null) break;
      // 防止自指链接导致死循环
      if (nextPageUrl == currentUrl) break;
      currentUrl = nextPageUrl;
    }
    // 用双换行连接分页，保持段落结构
    return ChapterContent(title: title, content: parts.join('\n\n'));
  }

  /// 从章节页 HTML 提取同章"下一页"URL
  ///
  /// biquge2.net 将长章节分页：第1页 `135023.html`，第2页 `135023_1.html`...
  /// 下一章则是不同的 chapterId（如 `135025.html`）。只返回同章分页链接。
  ///
  /// 不依赖链接文案：bqgbb.cc 等站点把同章分页按钮文案标成"下一章"会被
  /// 文案过滤漏掉，致 [fetchChapterContent] 只抓第1页、章节字数被截断。
  /// 改为遍历所有 a[href]，resolve 后用 [_chapterIdAndPage] 取目标
  /// chapterId + page，仅当 [_isSameChapterPage]（同章）且
  /// `page == 当前页 + 1`（严格递进）时返回。这样对"下一章"误标 /
  /// 图片按钮 / 无文案链接都鲁棒，`page == current + 1` 杜绝回链循环。
  String? _nextPageUrl(String html, String currentUrl) {
    final current = _chapterIdAndPage(currentUrl);
    if (current == null) return null;
    final doc = html_parser.parse(html);
    for (final a in doc.querySelectorAll('a[href]')) {
      final href = a.attributes['href'] ?? '';
      if (href.isEmpty) continue;
      final resolved = _resolveUrl(href, currentUrl);
      final target = _chapterIdAndPage(resolved);
      if (target == null) continue;
      // 同章分页且严格为下一页才跟随：_isSameChapterPage 确保不跨章，
      // page == current + 1 严格递进，杜绝回链与跨章误入。
      if (_isSameChapterPage(currentUrl, resolved) &&
          target.page == current.page + 1) {
        return resolved;
      }
    }
    return null;
  }

  /// 判断两个 URL 是否属于同一章节的不同分页
  ///
  /// 同章分页模式：`{base}/{chapterId}.html` 与 `{base}/{chapterId}_{N}.html`
  bool _isSameChapterPage(String urlA, String urlB) {
    final a = _chapterIdAndPage(urlA);
    final b = _chapterIdAndPage(urlB);
    if (a == null || b == null) return false;
    return a.chapterId == b.chapterId; // chapterId 相同即同章
  }

  /// 从 URL 提取 (chapterId, 页码)，页码 0 表示首页
  ({String chapterId, int page})? _chapterIdAndPage(String url) {
    // 135023.html -> (135023, 0)
    var m = RegExp(r'/(\d+)\.html$').firstMatch(url);
    if (m != null) return (chapterId: m.group(1)!, page: 0);
    // 135023_3.html -> (135023, 3)
    m = RegExp(r'/(\d+)_(\d+)\.html$').firstMatch(url);
    if (m != null) {
      return (chapterId: m.group(1)!, page: int.parse(m.group(2)!));
    }
    return null;
  }

  // ──────── 解析方法 ────────

  List<SearchResult> _parseSearchResult(String html, {String? keyword}) {
    final document = html_parser.parse(html);
    final results = <SearchResult>[];

    // 策略 1: 经典笔趣阁表格布局 (table.grid)
    var rows = document.querySelectorAll('table.grid tr');
    if (rows.isNotEmpty) {
      for (final row in rows) {
        final link = row.querySelector('a');
        if (link == null) continue;
        final title = link.text.trim();
        final href = link.attributes['href'] ?? '';
        if (title.isEmpty || href.isEmpty) continue;

        // 提取作者（第二列）
        final tds = row.querySelectorAll('td');
        String author = '';
        if (tds.length >= 2) {
          author = tds[1].text.trim();
        }

        results.add(SearchResult(
          title: title,
          author: author,
          url: _resolveUrl(href, baseUrl),
        ));
      }
      if (results.isNotEmpty) return results;
    }

    // 策略 2: 搜索结果列表 (.result-list / .novelslistss)
    var items = document.querySelectorAll(
        '.result-list .result-item, .novelslistss li, .novelitem, .search-result-item, .search-result li');
    for (final item in items) {
      final link = item.querySelector('a');
      if (link == null) continue;
      final title = link.text.trim();
      final href = link.attributes['href'] ?? '';
      if (title.isEmpty || href.isEmpty) continue;

      results.add(SearchResult(
        title: title,
        author: '',
        url: _resolveUrl(href, baseUrl),
      ));
    }
    if (results.isNotEmpty) return results;

    // 策略 3: 通用 — 查找所有指向书籍详情页的链接
    // 匹配多种书籍详情页 URL 模式：
    //   /book/123/          (biquge2.net)
    //   /book/123.html      (部分镜像)
    //   /123/456/789.html   (经典笔趣阁)
    final allLinks = document.querySelectorAll('a[href]');
    final seen = <String>{};
    for (final link in allLinks) {
      final href = link.attributes['href'] ?? '';
      final title = link.text.trim();
      if (title.isEmpty || title.length < 2) continue;

      // 匹配书籍详情页 URL 模式（兼容多站点）：
      //   /book/{id}/   /read/{id}/   /chapter/{id}/   /{d}_{d}/   /{d}/{d}/{d}.html
      if (RegExp(
              r'/(?:book|read|chapter)/\d+/?$|/\d+_\d+/?$|/\d+/\d+/\d+\.html$')
          .hasMatch(href)) {
        final url = _resolveUrl(href, baseUrl);
        if (seen.contains(url)) continue;
        seen.add(url);

        results.add(SearchResult(
          title: title,
          author: '',
          url: url,
        ));
      }
    }

    return _filterRelevant(results, keyword);
  }

  /// 过滤出与关键词相关的搜索结果
  ///
  /// 笔趣阁镜像的搜索常返回"最新推荐"列表（与关键词无关），
  /// 真正匹配的书混在其中。这里优先返回书名含关键词的结果；
  /// 若无含关键词的结果，则返回全部（兼容搜索已精确的场景）。
  List<SearchResult> _filterRelevant(
      List<SearchResult> results, String? keyword) {
    if (keyword == null || keyword.trim().isEmpty) return results;
    final kw = keyword.trim();

    // 按书名包含关键词排序：匹配的在前
    final relevant = results.where((r) => r.title.contains(kw)).toList();
    if (relevant.isNotEmpty) return relevant;

    // 宽松匹配：书名含关键词任一字（对长词有效）
    final chars =
        kw.split('').toSet().where((c) => c.trim().isNotEmpty).toList();
    if (chars.length >= 2) {
      final fuzzy = results.where((r) {
        final title = r.title;
        return chars.any((c) => title.contains(c));
      }).toList();
      if (fuzzy.isNotEmpty) return fuzzy;
    }

    return results;
  }

  BookDetail _parseBookDetail(String html, String bookUrl) {
    final document = html_parser.parse(html);

    // 书名（兼容 biquge2.net 的 #info h1、bqgbb.cc 的 .details h2、
    // bxwxorg 等的 .info-main h1 / 通用 h1）
    final titleEl = document.querySelector('#info h1') ??
        document.querySelector('.info h1') ??
        document.querySelector('.info-main h1') ??
        document.querySelector('.details h2') ??
        document.querySelector('.intro .details h2') ??
        document.querySelector('h1:not(.title)') ??
        document.querySelector('h1') ??
        document.querySelector('h2') ??
        document.querySelector('.title');
    var title = titleEl?.text.trim() ?? '';
    // 清洗书名两端可能的《》包裹（bxwxorg 等站点标题含书名号）
    title = title.replaceAll(RegExp(r'^《|》$'), '').trim();

    // 作者（兼容 biquge2.net 和 bqgbb.cc 结构）
    String author = '';
    final authorEl = document.querySelector('#info p a') ??
        document.querySelector('#info p') ??
        document.querySelector('.author a') ??
        document.querySelector('.small span a');
    if (authorEl != null) {
      final raw = authorEl.text.trim();
      // 格式可能是 "作者：张三" 或 "著者:张三"
      author = raw.replaceAll(RegExp(r'^(作者|著者|作\s*者)\s*[:：]\s*'), '').trim();
    }
    if (author.isEmpty) {
      // bqgbb.cc: 作者在 "作者：<a>" 或 ".details p i" 中
      final authorLink =
          document.querySelector('.details p a[href*="/zuozhe/"]') ??
              document.querySelector('.details p a');
      if (authorLink != null) {
        author = authorLink.text.trim();
      }
    }
    if (author.isEmpty) {
      // 从正文中提取 "作者：xxx"
      final bodyText = document.body?.text ?? '';
      final authorMatch = RegExp(r'作者[:：]\s*([^\s，。<]+)').firstMatch(bodyText);
      if (authorMatch != null) {
        author = authorMatch.group(1)!.trim();
      }
    }

    // 简介（兼容 biquge2.net 的 #intro 和 bqgbb.cc 的 .intro .p2）
    final introEl = document.querySelector('#intro') ??
        document.querySelector('.intro .p2') ??
        document.querySelector('.p2') ??
        document.querySelector('.intro') ??
        document.querySelector('#bookintro');
    var intro = introEl?.text.trim() ?? '';

    // 若书名仍为空或误判为站点名，尝试从 og:title meta 提取
    if (title.isEmpty || title == sourceName || title.contains('笔趣阁')) {
      final ogTitle = document
          .querySelector('meta[property="og:novel:book_name"]')
          ?.attributes['content'];
      if (ogTitle != null && ogTitle.isNotEmpty) {
        title = ogTitle.trim();
      }
    }
    if (author.isEmpty) {
      final ogAuthor = document
          .querySelector('meta[property="og:novel:author"]')
          ?.attributes['content'];
      if (ogAuthor != null && ogAuthor.isNotEmpty) {
        author = ogAuthor.trim();
      }
    }

    // 章节列表（兜底：当无目录页时使用详情页本身的章节链接）
    // 注意：详情页可能含最新章节、导航等噪声，这里只保留真正的章节内容页链接
    final chapterLinks = <Element>[];
    chapterLinks.addAll(document.querySelectorAll('#list dd a'));
    if (chapterLinks.isEmpty) {
      chapterLinks.addAll(document.querySelectorAll('.listmain dd a'));
    }
    if (chapterLinks.isEmpty) {
      chapterLinks.addAll(document.querySelectorAll('.catalog a'));
    }
    if (chapterLinks.isEmpty) {
      chapterLinks.addAll(document.querySelectorAll('#mlist a'));
    }
    if (chapterLinks.isEmpty) {
      chapterLinks.addAll(document.querySelectorAll('.chapter-list a'));
    }
    // bqgbb.cc: .yanqing_list li a 结构
    if (chapterLinks.isEmpty) {
      chapterLinks.addAll(document.querySelectorAll('.yanqing_list li a'));
    }
    // 通用兜底：按章节内容页 URL 特征匹配（兼容 /book/ /read/ /chapter/ /{d}_{d}/ 路径），
    // 排除 ml_*.html 目录分页
    if (chapterLinks.isEmpty) {
      for (final a in document.querySelectorAll('a[href]')) {
        final href = a.attributes['href'] ?? '';
        if (href.isEmpty) continue;
        if (!_chapterUrlRe.hasMatch(href)) continue;
        if (RegExp(r'/ml_\d+\.html$').hasMatch(href)) continue;
        chapterLinks.add(a);
      }
    }

    final chapters = <ChapterRef>[];
    final seenIds = <String>{};
    for (final link in chapterLinks) {
      final chapterTitle = link.text.trim();
      final href = link.attributes['href'] ?? '';
      if (chapterTitle.isEmpty || href.isEmpty) continue;
      // 过滤导航/目录类噪声链接
      if (chapterTitle.contains('目录') ||
          chapterTitle.contains('书页') ||
          chapterTitle.contains('开始阅读')) {
        continue;
      }
      // 跳过目录分页链接 ml_*.html
      if (RegExp(r'/ml_\d+\.html$').hasMatch(href)) continue;

      final chapterUrl = _resolveUrl(href, bookUrl);
      final sourceId = _extractChapterId(chapterUrl);
      if (seenIds.contains(sourceId)) continue;
      seenIds.add(sourceId);

      chapters.add(ChapterRef(
        title: chapterTitle,
        url: chapterUrl,
        sourceId: sourceId,
      ));
    }

    // 按章号排序
    chapters.sort((a, b) {
      final na = _chapterNumber(a.title);
      final nb = _chapterNumber(b.title);
      if (na == null && nb == null) return 0;
      if (na == null) return 1;
      if (nb == null) return -1;
      return na.compareTo(nb);
    });

    return BookDetail(
      title: title,
      author: author,
      intro: intro,
      chapters: chapters,
    );
  }

  ChapterContent _parseChapterContent(String html) {
    final document = html_parser.parse(html);

    // 章节标题（兼容 biquge2.net 的 .bookname h1 和 bqgbb.cc 的 .chapter-title）
    String title = '';
    final titleEl = document.querySelector('.bookname h1') ??
        document.querySelector('.chapter-title') ??
        document.querySelector('h1') ??
        document.querySelector('h2') ??
        document.querySelector('.title');
    if (titleEl != null) {
      title = titleEl.text.trim();
    }

    // 正文容器（兼容多站点）：#txt/.txt（bqgbb 真实容器）、.word_read（bxwxorg）
    String rawContent = '';
    final contentEl = document.querySelector('#txt') ??
        document.querySelector('.txt') ??
        document.querySelector('.word_read') ??
        document.querySelector('#content') ??
        document.querySelector('#chaptercontent') ??
        document.querySelector('.content') ??
        document.querySelector('#booktext') ??
        document.querySelector('.showtxt');

    if (contentEl != null) {
      rawContent = contentEl.innerHtml;

      // 处理 base64 加密正文（bqgbb.cc 的 qsbs.bb() / biqumo.com 的 xacywc.omvymw()
      // 等同型加密）：<script>document.writeln(xxx.yy('PHA+...=='));</script>
      // 将多个 base64 片段解码并拼接为 HTML，再交由清洗器处理
      if (_base64CallRe.hasMatch(rawContent)) {
        final decoded = _decodeBase64Content(rawContent);
        if (decoded.isNotEmpty) rawContent = decoded;
      }
    }

    final content = _contentCleaner.clean(rawContent);

    return ChapterContent(
      title: title,
      content: content,
    );
  }

  /// base64 加密正文调用特征：`obj.method('BASE64')`
  ///
  /// 兼容 bqgbb.cc 的 `qsbs.bb('...')` 与 biqumo.com 的 `xacywc.omvymw('...')`
  /// 等同型加密。捕获组为 base64 字符串。
  static final RegExp _base64CallRe =
      RegExp(r"\w+\.\w+\('([A-Za-z0-9+/=]+)'\)");

  /// 章节内容页 URL 特征（用于从详情/目录页链接中识别章节）
  ///
  /// 兼容多站点路径：
  /// - /book/{bid}/{chid}.html        biquge2 / bqgbb
  /// - /read/{bid}/{chid}.html        bqge.cc
  /// - /chapter/{bid}/{chid}.html     bxwxorg
  /// - /{d}_{d}/{chid}.html           biqumo
  /// 末尾可选分页后缀 _{N}.html；ml_*.html 目录页因末段非纯数字而自然不匹配。
  static final RegExp _chapterUrlRe = RegExp(
    r'/(?:book|read|chapter)/\d+/\d+(?:_\d+)?\.html$'
    r'|/\d+_\d+/\d+(?:_\d+)?\.html$',
  );

  /// 解码 base64 加密正文
  ///
  /// 正文格式：`document.writeln(xxx.yy('BASE64'));`
  /// 将多个 base64 片段解码并拼接为 HTML。
  String _decodeBase64Content(String rawHtml) {
    final buffer = StringBuffer();
    for (final match in _base64CallRe.allMatches(rawHtml)) {
      final b64 = match.group(1);
      if (b64 == null) continue;
      try {
        final bytes = base64Decode(b64);
        buffer.write(utf8.decode(bytes, allowMalformed: true));
      } catch (_) {
        // 单个片段失败不影响其他片段
      }
    }
    return buffer.toString();
  }

  /// 将 href 解析为绝对 URL
  ///
  /// 处理三种形式：
  /// - 绝对 URL（https://...）→ 原样返回
  /// - 根相对路径（/12/456.html）→ 拼接 baseUrl
  /// - 页面相对路径（123456.html）→ 基于 pageUrl 解析
  String _resolveUrl(String href, String pageUrl) {
    if (href.startsWith('http://') || href.startsWith('https://')) {
      return href;
    }
    if (href.startsWith('/')) {
      // 根相对路径：从 baseUrl 提取 scheme+host
      final uri = Uri.parse(baseUrl);
      return '${uri.scheme}://${uri.host}$href';
    }
    // 页面相对路径：基于 pageUrl 解析
    final baseUri = Uri.parse(pageUrl);
    return baseUri.resolve(href).toString();
  }

  /// 从书籍链接 href 构造规范的书籍详情页绝对 URL（兼容多站点路径）
  ///
  /// 兼容 /book/{id}/ /read/{id}/ /chapter/{id}/ /{d}_{d}/ /{d}/{d}/{d}.html；
  /// 无法识别返回 null。仅做模式校验，实际 URL 由 [_resolveUrl] 解析为绝对路径。
  String? _canonicalBookUrl(String href) {
    final path = href.split('?')[0].split('#')[0];
    final isBook = RegExp(r'/(?:book|read|chapter)/\d+/?$').hasMatch(path) ||
        RegExp(r'/\d+_\d+/?$').hasMatch(path) ||
        RegExp(r'/\d+/\d+/\d+\.html$').hasMatch(path);
    if (!isBook) return null;
    return _resolveUrl(href, baseUrl);
  }

  /// 从章节 URL 提取唯一 ID（用于去重）
  ///
  /// 例如：https://www.xbiquge.la/123/456/789.html → "789"
  String _extractChapterId(String url) {
    // 去除查询参数和 fragment
    final cleanUrl = url.split('?')[0].split('#')[0];

    // 分页形式 135023_3.html -> 取基础 chapterId "135023"（同章各页共享 ID）
    var match = RegExp(r'/(\d+)_\d+\.html?$').firstMatch(cleanUrl);
    if (match != null) return match.group(1)!;

    // 普通形式 135023.html -> "135023"
    match = RegExp(r'/(\d+)\.html?$').firstMatch(cleanUrl);
    if (match != null) return match.group(1)!;

    // 备用：取最后一段路径
    final segments = cleanUrl.split('/').where((s) => s.isNotEmpty).toList();
    if (segments.isNotEmpty) {
      final last = segments.last;
      return last.replaceAll(RegExp(r'\.html?$'), '');
    }

    return url;
  }
}
