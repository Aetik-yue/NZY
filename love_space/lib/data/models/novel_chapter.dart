import 'package:isar/isar.dart';

part 'novel_chapter.g.dart';

/// 小说章节（单章正文）
@collection
class NovelChapter {
  Id id = Isar.autoIncrement;

  /// 所属小说 id（关联索引，便于按小说查询）
  @Index()
  late int novelId;

  /// 章序号（从 0 递增，用于排序）
  late int chapterIndex;

  /// 章节标题
  late String title;

  /// 章节正文（短文本）
  late String content;
}
