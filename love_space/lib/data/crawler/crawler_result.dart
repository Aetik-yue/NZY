/// 爬虫结果 DTO（数据传递对象）
///
/// 这些类仅用于爬虫层内部数据传递，不持久化到数据库。
library;

/// 搜索结果
class SearchResult {
  final String title;
  final String author;
  final String url;
  final String intro;
  final String latestChapter;

  const SearchResult({
    required this.title,
    required this.author,
    required this.url,
    this.intro = '',
    this.latestChapter = '',
  });

  @override
  String toString() => 'SearchResult($title / $author)';
}

/// 章节引用（目录中的一章，不含正文）
class ChapterRef {
  final String title;
  final String url;

  /// 源站章节 ID（用于去重，通常从 URL 提取）
  final String sourceId;

  const ChapterRef({
    required this.title,
    required this.url,
    required this.sourceId,
  });

  @override
  String toString() => 'ChapterRef($title)';
}

/// 书籍详情
class BookDetail {
  final String title;
  final String author;
  final String intro;
  final List<ChapterRef> chapters;

  const BookDetail({
    required this.title,
    required this.author,
    required this.intro,
    required this.chapters,
  });

  @override
  String toString() => 'BookDetail($title / $author, ${chapters.length}章)';
}

/// 章节正文
class ChapterContent {
  final String title;
  final String content;

  const ChapterContent({
    required this.title,
    required this.content,
  });

  @override
  String toString() => 'ChapterContent($title, ${content.length}字)';
}

/// 分类浏览结果（比 SearchResult 多字数和更新时间）
class CategoryBook {
  final String title;
  final String author;
  final String url;
  final String intro;
  final String wordCount;
  final String updateTime;

  const CategoryBook({
    required this.title,
    required this.author,
    required this.url,
    this.intro = '',
    this.wordCount = '',
    this.updateTime = '',
  });

  @override
  String toString() => 'CategoryBook($title / $author)';
}
