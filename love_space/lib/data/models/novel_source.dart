import 'package:isar/isar.dart';

part 'novel_source.g.dart';

/// 小说爬取源配置
///
/// 描述一个可爬取的小说站点（如笔趣阁），包含站点标识、根地址与选择器配置。
@collection
class NovelSource {
  Id id = Isar.autoIncrement;

  /// 唯一标识（如 "biquge"），用于代码中检索
  @Index(unique: true)
  late String key;

  /// 显示名（如 "笔趣阁"）
  late String name;

  /// 站点根 URL（如 "https://www.xbiquge.la"）
  late String baseUrl;

  /// 是否启用（默认 true）
  late bool enabled = true;

  /// 创建时间
  late DateTime createdAt = DateTime.now();

  /// 选择器配置 JSON 字符串
  ///
  /// 结构：
  /// ```json
  /// {
  ///   "searchUrl": "/search.html?searchtype=novelname&searchkey={keyword}",
  ///   "bookLinkSelector": ".result-list .result-item a",
  ///   "titleSelector": "#info h1",
  ///   "authorSelector": "#info p a",
  ///   "introSelector": "#intro",
  ///   "chapterListSelector": "#list dd a",
  ///   "chapterTitleSelector": ".bookname h1",
  ///   "chapterContentSelector": "#content"
  /// }
  /// ```
  late String selectors;
}
