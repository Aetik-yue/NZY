import 'crawler_result.dart';

/// 小说爬虫抽象接口
///
/// 每个支持的小说站点需实现该接口，提供搜索、分类浏览、详情抓取、章节正文抓取能力。
abstract class BaseCrawler {
  /// 源站唯一标识（对应 NovelSource.key）
  String get sourceKey;

  /// 源站显示名
  String get sourceName;

  /// 源站根 URL
  String get baseUrl;

  /// 搜索小说
  ///
  /// 返回匹配关键词的搜索结果列表。
  Future<List<SearchResult>> search(String keyword);

  /// 按分类浏览小说
  ///
  /// [categoryId] 为分类 ID（1=玄幻 2=修真 3=都市...），
  /// [page] 为页码（从 1 开始）。
  /// 返回该分类下的书籍列表。
  Future<List<CategoryBook>> browseCategory(int categoryId, {int page = 1});

  /// 抓取书籍详情（含章节列表）
  ///
  /// [url] 为书籍详情页 URL。
  Future<BookDetail> fetchBookDetail(String url);

  /// 抓取章节正文
  ///
  /// [url] 为章节内容页 URL。返回的 [ChapterContent.content] 已完成内容清洗。
  Future<ChapterContent> fetchChapterContent(String url);
}
