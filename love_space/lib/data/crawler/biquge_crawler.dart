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
  })  : _httpClient = httpClient ?? AppHttpClient(),
        _contentCleaner = contentCleaner ?? ContentCleaner();

  final NovelSource source;
  final AppHttpClient _httpClient;
  final ContentCleaner _contentCleaner;

  /// 选择器配置（从 source.selectors JSON 解析，此处使用默认值）
  static const String _defaultSearchPath = '/modules/article/search.php';
  static const String _searchParam = 'searchkey';

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

    // 笔趣阁搜索使用 POST 表单提交，关键词需 GBK 编码
    // 不同镜像站参数名不同，依次尝试
    final searchAttempts = <_SearchAttempt>[
      _SearchAttempt('/search.html', {'s': kw}),
      _SearchAttempt('/search.html', {'searchkey': kw}),
      _SearchAttempt('/modules/article/search.php',
          {'searchkey': kw, 'searchtype': 'novelname'}),
      _SearchAttempt('/modules/article/search.php', {'searchkey': kw}),
    ];

    for (final attempt in searchAttempts) {
      try {
        final url = '$baseUrl${attempt.path}';
        final body = await _httpClient.postGbk(
          url,
          body: attempt.params,
          headers: {'Referer': '$baseUrl/'},
        );

        // 检测搜索间隔限制提示
        if (body.contains('搜索间隔') || body.contains('请于')) {
          debugPrint('[BiqugeCrawler] 命中搜索间隔限制，跳过 $url');
          continue;
        }

        final results = _parseSearchResult(body);
        if (results.isNotEmpty) return results;
      } catch (e) {
        debugPrint('[BiqugeCrawler] 搜索 ${attempt.path} 失败: $e');
      }
    }

    // 站内搜索全部失败，回退到搜索引擎兜底
    return _searchViaEngine(kw);
  }

  /// 搜索引擎兜底：用 Bing + Google site: 搜索找书籍详情页 URL
  ///
  /// 当站点自身搜索不可用（如 biquge2.net 搜索索引损坏）时，
  /// 通过搜索引擎检索 `site:<baseUrl> 书名`，从结果中提取书籍 URL。
  /// 依赖搜索引擎对目标站的索引，效果因站而异。
  Future<List<SearchResult>> _searchViaEngine(String keyword) async {
    final host = Uri.parse(baseUrl).host;
    // 转义 host 中的正则元字符（如 .）
    final hostPattern = RegExp.escape(host);
    final bookRe = RegExp(r'https?://[^/]*$hostPattern/book/(\d+)/?');

    final engines = [
      'https://www.bing.com/search?q=',
      'https://www.google.com/search?q=',
    ];
    final query = Uri.encodeQueryComponent('site:$host $keyword');

    for (final engine in engines) {
      try {
        final body = await _httpClient.get('$engine$query', headers: {
          'User-Agent': UserAgentRotator.random,
          'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
        });

        final document = html_parser.parse(body);
        final results = <SearchResult>[];
        final seen = <String>{};

        for (final link in document.querySelectorAll('a[href]')) {
          final href = link.attributes['href'] ?? '';
          final title = link.text.trim();
          if (title.isEmpty || title.length < 2) continue;

          final match = bookRe.firstMatch(href);
          if (match != null) {
            final url = match.group(0)!;
            if (seen.contains(url)) continue;
            seen.add(url);
            results.add(SearchResult(title: title, author: '', url: url));
            if (results.length >= 10) break;
          }
        }

        if (results.isNotEmpty) {
          debugPrint(
              '[BiqugeCrawler] ${engine.split('/')[2]} 找到 ${results.length} 条');
          return results;
        }
      } catch (e) {
        debugPrint('[BiqugeCrawler] 搜索引擎 $engine 失败: $e');
      }
    }

    return [];
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
    final doc = html_parser.parse(detailHtml);
    // 找目录页链接（ml_N.html），用于补充分页章节
    final tocLink = doc
        .querySelectorAll('a[href]')
        .map((a) => a.attributes['href'] ?? '')
        .firstWhere(
          (href) => RegExp(r'/book/\d+/ml_\d+\.html').hasMatch(href),
          orElse: () => '',
        );

    // 提取 bookId 用于构造后续分页 URL
    final bookIdMatch = RegExp(r'/book/(\d+)/').firstMatch(bookUrl);
    final bookId = bookIdMatch?.group(1);
    if (bookId == null) return [];

    final allChapters = <ChapterRef>[];
    final seenIds = <String>{};

    // 0. 先从详情页本身提取章节链接（biquge2.net 详情页含最近 ~100 章正序链接）
    final detailDoc = html_parser.parse(detailHtml);
    for (final link in detailDoc.querySelectorAll('a[href]')) {
      final href = link.attributes['href'] ?? '';
      final chapterMatch = RegExp(r'/book/\d+/(\d+)\.html$').firstMatch(href);
      if (chapterMatch == null) continue;
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
      final sourceId = chapterMatch.group(1)!;
      if (seenIds.contains(sourceId)) continue;
      seenIds.add(sourceId);

      allChapters.add(ChapterRef(
        title: title,
        url: chapterUrl,
        sourceId: sourceId,
      ));
    }

    // 1. 抓取目录分页（ml_1 ~ ml_5）补充详情页未覆盖的章节
    //    仅当详情页存在 ml 目录链接时才抓分页
    if (tocLink.isNotEmpty && bookId != null) {
      for (var page = 1; page <= 5; page++) {
        final tocUrl = '$baseUrl/book/$bookId/ml_$page.html';
        try {
          final html = await _httpClient.get(tocUrl);
          final pageDoc = html_parser.parse(html);
          final links = pageDoc.querySelectorAll('a[href]');

          var foundOnPage = false;
          for (final link in links) {
            final href = link.attributes['href'] ?? '';
            // 只匹配真正的章节内容页：/book/{id}/{chapterId}.html（排除 ml_*.html 自身）
            final chapterMatch =
                RegExp(r'/book/\d+/(\d+)\.html$').firstMatch(href);
            if (chapterMatch == null) continue;

            final title = link.text.trim();
            if (title.isEmpty || title.contains('目录') || title.contains('书页')) {
              continue;
            }

            final chapterUrl = _resolveUrl(href, tocUrl);
            final sourceId = chapterMatch.group(1)!;
            if (seenIds.contains(sourceId)) continue;
            seenIds.add(sourceId);

            allChapters.add(ChapterRef(
              title: title,
              url: chapterUrl,
              sourceId: sourceId,
            ));
            foundOnPage = true;
          }
          if (!foundOnPage) break; // 该页无章节，后续页也不必抓
        } catch (e) {
          debugPrint('[BiqugeCrawler] 目录页 $tocUrl 抓取失败: $e');
          break;
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
    // 防止恶意循环，最多拼接 20 页
    for (var i = 0; i < 20; i++) {
      final body = await _httpClient.get(currentUrl);
      final parsed = _parseChapterContent(body);
      if (title.isEmpty) title = parsed.title;
      parts.add(parsed.content);

      // 检测同章下一页链接（{chapterId}_{N}.html 模式）
      final nextPageUrl = _nextPageUrl(body, currentUrl);
      if (nextPageUrl == null) break;
      currentUrl = nextPageUrl;
    }
    return ChapterContent(title: title, content: parts.join('\n'));
  }

  /// 从章节页 HTML 提取同章"下一页"URL
  ///
  /// biquge2.net 将长章节分页：第1页 `135023.html`，第2页 `135023_1.html`...
  /// 下一章则是不同的 chapterId（如 `135025.html`）。只返回同章分页链接。
  String? _nextPageUrl(String html, String currentUrl) {
    final doc = html_parser.parse(html);
    // 找文本含"下一页"/"继续阅读"的链接
    for (final a in doc.querySelectorAll('a[href]')) {
      final text = a.text.trim();
      if (text.contains('下一页') || text.contains('继续阅读') || text.contains('下页')) {
        final href = a.attributes['href'] ?? '';
        if (href.isEmpty) continue;
        final resolved = _resolveUrl(href, currentUrl);
        // 仅当是同章分页（当前 chapterId_N.html -> chapterId_(N+1).html）才跟随
        if (_isSameChapterPage(currentUrl, resolved)) {
          return resolved;
        }
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
    if (m != null) return (chapterId: m.group(1)!, page: int.parse(m.group(2)!));
    return null;
  }

  // ──────── 解析方法 ────────

  List<SearchResult> _parseSearchResult(String html) {
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

      // 匹配书籍详情页 URL 模式
      if (RegExp(r'/book/\d+/?$|/\d+/\d+/\d+\.html$').hasMatch(href)) {
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

    return results;
  }

  BookDetail _parseBookDetail(String html, String bookUrl) {
    final document = html_parser.parse(html);

    // 书名
    final titleEl = document.querySelector('#info h1') ??
        document.querySelector('.info h1') ??
        document.querySelector('.title');
    final title = titleEl?.text.trim() ?? '';

    // 作者
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

    // 简介
    final introEl = document.querySelector('#intro') ??
        document.querySelector('.intro') ??
        document.querySelector('#bookintro');
    final intro = introEl?.text.trim() ?? '';

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
    // biquge2.net: 通配章节链接，href 形如 /book/{id}/{chapterId}.html（排除 ml_*.html 目录页自身）
    if (chapterLinks.isEmpty) {
      chapterLinks.addAll(
        document.querySelectorAll('a[href*="/book/"][href\$=".html"]'),
      );
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

    // 章节标题
    String title = '';
    final titleEl = document.querySelector('.bookname h1') ??
        document.querySelector('h1') ??
        document.querySelector('.title');
    if (titleEl != null) {
      title = titleEl.text.trim();
    }

    // 正文
    String rawContent = '';
    final contentEl = document.querySelector('#content') ??
        document.querySelector('.content') ??
        document.querySelector('#booktext') ??
        document.querySelector('.showtxt');
    if (contentEl != null) {
      rawContent = contentEl.innerHtml;
    }

    final content = _contentCleaner.clean(rawContent);

    return ChapterContent(
      title: title,
      content: content,
    );
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
