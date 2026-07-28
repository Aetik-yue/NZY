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

    // 使用 Uri 构建搜索 URL，自动处理路径拼接和编码
    final searchUrl = Uri.parse('$baseUrl$_defaultSearchPath')
        .replace(queryParameters: {_searchParam: keyword.trim()})
        .toString();

    final body = await _httpClient.get(searchUrl);
    return _parseSearchResult(body);
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

    // 笔趣阁搜索结果通常在表格 .grid 或 .result-list 中
    // 尝试多种选择器以兼容不同镜像
    var rows = document.querySelectorAll('table.grid tr');
    if (rows.isEmpty) {
      rows = document.querySelectorAll('.result-list .result-item');
    }
    if (rows.isEmpty) {
      rows = document.querySelectorAll('.novelslistss li');
    }

    for (final row in rows) {
      // 跳过表头
      final link = row.querySelector('a');
      if (link == null) continue;

      final title = link.text.trim();
      final href = link.attributes['href'] ?? '';
      if (title.isEmpty || href.isEmpty) continue;

      // 提取作者（通常在第二列或 .result-game-pic 后）
      String author = '';
      final authorEl = row.querySelector('.odd:last-child') ??
          row.querySelector('.result-item-author');
      if (authorEl != null) {
        author = authorEl.text.trim();
      }

      final url = _resolveUrl(href, baseUrl);

      results.add(SearchResult(
        title: title,
        author: author,
        url: url,
      ));
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

    // 章节列表
    final chapters = <ChapterRef>[];
    final chapterLinks = document.querySelectorAll('#list dd a');
    if (chapterLinks.isEmpty) {
      // 备用选择器
      chapterLinks.addAll(document.querySelectorAll('.listmain dd a'));
    }
    if (chapterLinks.isEmpty) {
      chapterLinks.addAll(document.querySelectorAll('.catalog a'));
    }

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
