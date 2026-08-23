// 笔趣阁爬虫单元测试
//
// 重点覆盖章节分页跟随逻辑：bqgbb.cc 等站点把同章分页按钮文案标成"下一章"，
// 旧实现因依赖链接文案而漏跟，导致只抓第1页、章节字数被截断。
// 这里用 FakeHttpClient 注入多页 HTML，断言按 URL 模式正确拼接全章内容、
// 不误入下一章（不同 chapterId）、不因回链死循环。
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/core/network/app_http_client.dart';
import 'package:love_space/data/crawler/biquge_crawler.dart';
import 'package:love_space/data/crawler/content_cleaner.dart';
import 'package:love_space/data/models/novel_source.dart';

/// 假 HTTP 客户端：按 URL 返回预设 HTML，并记录请求顺序用于断言
class _FakeHttpClient extends AppHttpClient {
  _FakeHttpClient(this._responses);

  final Map<String, String> _responses;

  /// 按顺序记录所有被请求过的 URL（用于断言跟随路径）
  final List<String> requestedUrls = [];

  /// 记录站内搜索 POST（URL + 表单参数）
  final List<({String url, Map<String, String> body})> requestedPosts = [];

  @override
  Future<String> get(String url, {Map<String, String>? headers}) async {
    requestedUrls.add(url);
    final body = _responses[url];
    if (body == null) {
      throw Exception('FakeHttpClient: 未配置响应 $url');
    }
    return body;
  }

  @override
  Future<String> getOnce(
    String url, {
    Map<String, String>? headers,
    Duration? timeoutOverride,
  }) {
    return get(url, headers: headers);
  }

  @override
  Future<String> postOnce(
    String url, {
    Map<String, String>? body,
    Map<String, String>? headers,
    Duration? timeoutOverride,
  }) async {
    requestedPosts.add((url: url, body: body ?? const {}));
    final response = _responses[url];
    if (response == null) {
      throw Exception('FakeHttpClient: 未配置响应 $url');
    }
    return response;
  }
}

/// Bing 立即命中，其他两个引擎保持挂起，用于验证“首个成功即返回”。
class _EngineRaceHttpClient extends AppHttpClient {
  final Completer<String> slowResponses = Completer<String>();
  int requestCount = 0;

  @override
  Future<String> getOnce(
    String url, {
    Map<String, String>? headers,
    Duration? timeoutOverride,
  }) {
    requestCount++;
    if (url.contains('bing.com')) {
      return Future.value('''
<a href="https://www.bqgbb.cc/book/123/">斗破苍穹</a>
''');
    }
    return slowResponses.future;
  }
}

/// 构造 bqgbb 源
NovelSource _bqgbbSource() => NovelSource()
  ..key = 'bqgbb'
  ..name = '笔趣阁'
  ..baseUrl = 'https://www.bqgbb.cc'
  ..selectors = '{}';

NovelSource _source(String key, String baseUrl) => NovelSource()
  ..key = key
  ..name = key
  ..baseUrl = baseUrl
  ..selectors = '{}';

String _searchResultHtml() => '''
<html><body>
<table class="grid">
  <tr><td><a href="/book/123/">斗破苍穹</a></td><td>天蚕土豆</td></tr>
</table>
</body></html>
''';

/// 构造一页章节 HTML
///
/// [body] 放入 #content 正文；[navLinks] 放入 .page-nav 导航区（href -> 文案），
/// 导航区在 #content 之外，不会被内容清洗器误删。
String _chapterPageHtml({
  required String title,
  required String body,
  required Map<String, String> navLinks,
}) {
  final links = navLinks.entries
      .map((e) => '<a href="${e.key}">${e.value}</a>')
      .join('\n    ');
  return '''
<html><head><title>$title</title></head>
<body>
<div class="bookname"><h1>$title</h1></div>
<div id="content"><p>$body</p></div>
<div class="page-nav">
    $links
</div>
</body></html>
''';
}

void main() {
  group('BiqugeCrawler 发现请求快速路径', () {
    test('bqgbb 搜索只请求该源已知端点一次', () async {
      final http = _FakeHttpClient({
        'https://www.bqgbb.cc/search.php': _searchResultHtml(),
      });
      final crawler = BiqugeCrawler(
        source: _bqgbbSource(),
        httpClient: http,
        enableSearchEngineFallback: false,
      );

      final results = await crawler.search('斗破苍穹');

      expect(results, hasLength(1));
      expect(results.single.title, '斗破苍穹');
      expect(http.requestedPosts, hasLength(1));
      expect(http.requestedPosts.single.url, 'https://www.bqgbb.cc/search.php');
      expect(http.requestedPosts.single.body, {'searchkey': '斗破苍穹'});
      expect(http.requestedUrls, isEmpty);
    });

    test('biquge 搜索使用 /search.html 的 s 参数且不再盲试其他参数', () async {
      final http = _FakeHttpClient({
        'https://www.biquge2.net/search.html': _searchResultHtml(),
      });
      final crawler = BiqugeCrawler(
        source: _source('biquge', 'https://www.biquge2.net'),
        httpClient: http,
        enableSearchEngineFallback: false,
      );

      final results = await crawler.search('斗破苍穹');

      expect(results, hasLength(1));
      expect(http.requestedPosts, hasLength(1));
      expect(http.requestedPosts.single.body, {'s': '斗破苍穹'});
    });

    test('跨源模式下站内搜索失败不会由每个源重复访问搜索引擎', () async {
      final http = _FakeHttpClient({});
      final crawler = BiqugeCrawler(
        source: _source('bqgecc', 'https://www.bqge.cc'),
        httpClient: http,
        enableSearchEngineFallback: false,
      );

      final results = await crawler.search('不存在的小说');

      expect(results, isEmpty);
      expect(http.requestedPosts, hasLength(1));
      expect(http.requestedUrls, isEmpty);
    });

    test('搜索引擎兜底在首个引擎命中后立即返回，不等待其他慢引擎', () async {
      final http = _EngineRaceHttpClient();
      final crawler = BiqugeCrawler(
        source: _bqgbbSource(),
        httpClient: http,
      );

      final results = await crawler.searchViaEngine('斗破苍穹');

      expect(results, hasLength(1));
      expect(results.single.url, 'https://www.bqgbb.cc/book/123/');
      expect(http.requestCount, 3);

      // 释放仍在后台等待的两个测试 Future，避免把异步任务遗留到下一用例。
      http.slowResponses.complete('<html></html>');
      await Future<void>.delayed(Duration.zero);
    });

    test('biquge 分类浏览直接命中已知 URL，不再轮询四种路径', () async {
      const categoryUrl =
          'https://www.biquge2.net/fenlei/lastupdate_1_0_0_1.html';
      final http = _FakeHttpClient({
        categoryUrl: '''
<div class="item">
  <a href="/book/88/" title="测试小说">测试小说</a>
  <dd>测试简介</dd>
  <div class="btm">测试作者 <em>100万字</em><em>今天</em></div>
</div>
''',
      });
      final crawler = BiqugeCrawler(
        source: _source('biquge', 'https://www.biquge2.net'),
        httpClient: http,
      );

      final books = await crawler.browseCategory(1);

      expect(books, hasLength(1));
      expect(books.single.title, '测试小说');
      expect(http.requestedUrls, [categoryUrl]);
    });

    test('长篇目录按批请求并保持章节页顺序', () async {
      const detailUrl = 'https://www.biquge2.net/book/123/';
      final http = _FakeHttpClient({
        detailUrl: '''
<div id="info"><h1>测试长篇</h1><p>作者：测试作者</p></div>
<a href="/book/123/ml_1.html">完整目录</a>
''',
        'https://www.biquge2.net/book/123/ml_1.html':
            '<a href="/book/123/11.html">第1章 开始</a>',
        'https://www.biquge2.net/book/123/ml_2.html':
            '<a href="/book/123/12.html">第2章 继续</a>',
        'https://www.biquge2.net/book/123/ml_3.html': '<html></html>',
        'https://www.biquge2.net/book/123/ml_4.html': '<html></html>',
        'https://www.biquge2.net/book/123/ml_5.html': '<html></html>',
      });
      final crawler = BiqugeCrawler(
        source: _source('biquge', 'https://www.biquge2.net'),
        httpClient: http,
      );

      final detail = await crawler.fetchBookDetail(detailUrl);

      expect(detail.chapters.map((chapter) => chapter.title), [
        '第1章 开始',
        '第2章 继续',
      ]);
      expect(http.requestedUrls, [
        detailUrl,
        'https://www.biquge2.net/book/123/ml_1.html',
        'https://www.biquge2.net/book/123/ml_2.html',
        'https://www.biquge2.net/book/123/ml_3.html',
        'https://www.biquge2.net/book/123/ml_4.html',
        'https://www.biquge2.net/book/123/ml_5.html',
      ]);
    });
  });

  group('BiqugeCrawler.fetchChapterContent 分页跟随', () {
    test('bqgbb 同章分页按钮文案标为"下一章"时仍正确跟随并拼接全章', () async {
      final http = _FakeHttpClient({
        'https://www.bqgbb.cc/book/123/456.html': _chapterPageHtml(
          title: '第1章 测试章节',
          body: '这是第一页的正文内容，讲述了一段动人的故事。',
          // bqgbb 把同章下一页按钮文案标成"下一章"（旧实现会漏跟）
          navLinks: {
            '456_1.html': '下一章',
          },
        ),
        'https://www.bqgbb.cc/book/123/456_1.html': _chapterPageHtml(
          title: '第1章 测试章节',
          body: '这是第二页的正文内容，故事继续向前发展着。',
          navLinks: {
            // 上一页回链（同章 page 0），page+1 逻辑不应跟随
            '456.html': '上一页',
            // 真正的下一章（不同 chapterId），不应跟随
            '457.html': '下一章',
          },
        ),
      });

      final crawler = BiqugeCrawler(
        source: _bqgbbSource(),
        httpClient: http,
        contentCleaner: ContentCleaner(),
      );

      final result = await crawler.fetchChapterContent(
        'https://www.bqgbb.cc/book/123/456.html',
      );

      // 标题取自第一页
      expect(result.title, '第1章 测试章节');
      // 两页正文都被拼接（修复前只有第一页）
      expect(result.content, contains('第一页'));
      expect(result.content, contains('第二页'));
      // 只请求了两页：第1页 + 同章第2页
      expect(http.requestedUrls, [
        'https://www.bqgbb.cc/book/123/456.html',
        'https://www.bqgbb.cc/book/123/456_1.html',
      ]);
      // 未误入下一章
      expect(http.requestedUrls.any((u) => u.contains('457.html')), isFalse);
    });

    test('多页章节按 page+1 严格递进抓取至末页，不误入下一章', () async {
      final http = _FakeHttpClient({
        'https://www.bqgbb.cc/book/123/789.html': _chapterPageHtml(
          title: '第2章 多页章节',
          body: '首页内容第一段落展开。',
          navLinks: {'789_1.html': '下一页'},
        ),
        'https://www.bqgbb.cc/book/123/789_1.html': _chapterPageHtml(
          title: '第2章 多页章节',
          body: '第二页内容继续展开推进。',
          navLinks: {'789_2.html': '下一页'},
        ),
        'https://www.bqgbb.cc/book/123/789_2.html': _chapterPageHtml(
          title: '第2章 多页章节',
          body: '第三页内容迎来最终结局。',
          // 末页指向下一章（不同 chapterId），不应跟随
          navLinks: {'790.html': '下一章'},
        ),
      });

      final crawler = BiqugeCrawler(
        source: _bqgbbSource(),
        httpClient: http,
        contentCleaner: ContentCleaner(),
      );

      final result = await crawler.fetchChapterContent(
        'https://www.bqgbb.cc/book/123/789.html',
      );

      expect(result.content, contains('首页内容'));
      expect(result.content, contains('第二页内容'));
      expect(result.content, contains('第三页内容'));
      expect(http.requestedUrls, [
        'https://www.bqgbb.cc/book/123/789.html',
        'https://www.bqgbb.cc/book/123/789_1.html',
        'https://www.bqgbb.cc/book/123/789_2.html',
      ]);
      // 未误入下一章 790.html
      expect(http.requestedUrls.any((u) => u.contains('790.html')), isFalse);
    });

    test('单页章节（直接指向下一章）只抓一页', () async {
      final http = _FakeHttpClient({
        'https://www.bqgbb.cc/book/123/100.html': _chapterPageHtml(
          title: '第3章 单页',
          body: '这是一页就结束的短章节内容。',
          // 直接指向下一章，无同章分页，不应跟随
          navLinks: {'101.html': '下一章'},
        ),
      });

      final crawler = BiqugeCrawler(
        source: _bqgbbSource(),
        httpClient: http,
        contentCleaner: ContentCleaner(),
      );

      final result = await crawler.fetchChapterContent(
        'https://www.bqgbb.cc/book/123/100.html',
      );

      expect(result.content, contains('一页就结束'));
      expect(http.requestedUrls, [
        'https://www.bqgbb.cc/book/123/100.html',
      ]);
    });

    test('回链不导致死循环：page1 链回 page0 时立即终止', () async {
      // page1 的"下一页"指向 page0（回链），page+1 递进逻辑应忽略它；
      // seen 集合作为兜底确保即便跟随也不会重复抓取。
      final http = _FakeHttpClient({
        'https://www.bqgbb.cc/book/123/200.html': _chapterPageHtml(
          title: '第4章 回链测试',
          body: '首页内容开始展开。',
          navLinks: {'200_1.html': '下一页'},
        ),
        'https://www.bqgbb.cc/book/123/200_1.html': _chapterPageHtml(
          title: '第4章 回链测试',
          body: '第二页内容继续。',
          // 回链到首页（page 0），page+1 逻辑不应跟随
          navLinks: {'200.html': '下一页'},
        ),
      });

      final crawler = BiqugeCrawler(
        source: _bqgbbSource(),
        httpClient: http,
        contentCleaner: ContentCleaner(),
      );

      final result = await crawler.fetchChapterContent(
        'https://www.bqgbb.cc/book/123/200.html',
      );

      expect(result.content, contains('首页内容'));
      expect(result.content, contains('第二页内容'));
      // 不会重复抓取任何一页
      expect(http.requestedUrls.length, 2);
      expect(
        http.requestedUrls.where((u) => u.endsWith('/200.html')).length,
        1,
      );
      expect(
        http.requestedUrls.where((u) => u.endsWith('/200_1.html')).length,
        1,
      );
    });
  });
}
