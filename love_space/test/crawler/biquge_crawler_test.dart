// 笔趣阁爬虫单元测试
//
// 重点覆盖章节分页跟随逻辑：bqgbb.cc 等站点把同章分页按钮文案标成"下一章"，
// 旧实现因依赖链接文案而漏跟，导致只抓第1页、章节字数被截断。
// 这里用 FakeHttpClient 注入多页 HTML，断言按 URL 模式正确拼接全章内容、
// 不误入下一章（不同 chapterId）、不因回链死循环。
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

  @override
  Future<String> get(String url, {Map<String, String>? headers}) async {
    requestedUrls.add(url);
    final body = _responses[url];
    if (body == null) {
      throw Exception('FakeHttpClient: 未配置响应 $url');
    }
    return body;
  }
}

/// 构造 bqgbb 源
NovelSource _bqgbbSource() => NovelSource()
  ..key = 'bqgbb'
  ..name = '笔趣阁'
  ..baseUrl = 'https://www.bqgbb.cc'
  ..selectors = '{}';

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
        http.requestedUrls
            .where((u) => u.endsWith('/200.html'))
            .length,
        1,
      );
      expect(
        http.requestedUrls
            .where((u) => u.endsWith('/200_1.html'))
            .length,
        1,
      );
    });
  });
}
