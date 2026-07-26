import 'package:isar/isar.dart';
import '../models/novel_chapter.dart';

/// 小说章节数据仓库
class NovelChapterRepository {
  NovelChapterRepository(this._isar);
  final Isar _isar;

  /// 监听某本小说的全部章节（按章序号升序）
  Stream<List<NovelChapter>> watchByNovel(int novelId) =>
      _isar.novelChapters
          .where()
          .novelIdEqualTo(novelId)
          .sortByChapterIndex()
          .watch(fireImmediately: true);

  /// 按小说 id + 章序号查询单章
  Future<NovelChapter?> getByNovelAndIndex(
    int novelId,
    int chapterIndex,
  ) =>
      _isar.novelChapters
          .where()
          .novelIdEqualTo(novelId)
          .filter()
          .chapterIndexEqualTo(chapterIndex)
          .findFirst();

  /// 批量新增章节
  Future<void> addAll(List<NovelChapter> chapters) =>
      _isar.writeTxn(() async => _isar.novelChapters.putAll(chapters));

  /// 删除某本小说的全部章节
  Future<void> deleteByNovel(int novelId) =>
      _isar.writeTxn(() async {
        await _isar.novelChapters
            .where()
            .novelIdEqualTo(novelId)
            .deleteAll();
      });
}
