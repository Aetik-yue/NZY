import 'package:flutter/foundation.dart';
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html_parser;

import '../../core/network/app_http_client.dart';
import '../models/novel_source.dart';
import 'base_crawler.dart';
import 'content_cleaner.dart';
import 'crawler_result.dart';

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
    if (keyword.trim().isEmpty) return [];

    // 笔趣阁搜索使用 POST 表单提交
    // 注意：多数镜像站有反爬机制，搜索可能不稳定
    final searchParams = [
      {'s': keyword.trim()},                       // biquge2.net 等
      {'searchkey': keyword.trim()},               // 经典笔趣阁
      {'searchkey': keyword.trim(), 'searchtype': 'novelname'},  // 带类型
      {'q': keyword.trim()},                       // 部分站点
    ];

    for (final params in searchParams) {
      try {
        final body = await _httpClient.post(
          '$baseUrl/search.html',
          body: params,
          headers: {'Referer': '$baseUrl/'},
        );
        final results = _parseSearchResult(body);
        if (results.isNotEmpty) return results;
      } catch (e) {
        debugPrint('[BiqugeCrawler] 搜索参数 $params 失败: $e');
      }
    }

    // 尝试 /search.php 端点
    try {
      final body = await _httpClient.post(
        '$baseUrl/modules/article/search.php',
        body: {'searchkey': keyword.trim(), 'searchtype': 'novelname'},
        headers: {'Referer': '$baseUrl/'},
      );
      final results = _parseSearchResult(body);
      if (results.isNotEmpty) return results;
    } catch (e) {
      debugPrint('[BiqugeCrawler] search.php 失败: $e');
    }

    return [];
  }

  @override
  Future<BookDetail> fetchBookDetail(String url) async {
    final body = await _httpClient.get(url);
    return _parseBookDetail(body, url);
  }

  @override
  Future<ChapterContent> fetchChapterContent(String url) async {
    final body = await _httpClient.get(url);
    return _parseChapterContent(body);
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
    var items = document.querySelectorAll('.result-list .result-item, .novelslistss li, .novelitem, .search-result-item, .search-result li');
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

    // 章节列表 — 尝试多种选择器以兼容不同镜像
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
    // biquge2.net: 章节链接在列表中，href 格式为 /book/123/456.html
    if (chapterLinks.isEmpty) {
      chapterLinks.addAll(document.querySelectorAll('a[href*="/book/"][href\$=".html"]'));
    }

    final chapters = <ChapterRef>[];
    for (final link in chapterLinks) {
      final chapterTitle = link.text.trim();
      final href = link.attributes['href'] ?? '';
      if (chapterTitle.isEmpty || href.isEmpty) continue;

      final chapterUrl = _resolveUrl(href, bookUrl);
      final sourceId = _extractChapterId(chapterUrl);

      chapters.add(ChapterRef(
        title: chapterTitle,
        url: chapterUrl,
        sourceId: sourceId,
      ));
    }

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

    final match = RegExp(r'(\d+)\.html?$').firstMatch(cleanUrl);
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
