import 'package:isar/isar.dart';
import '../models/novel.dart';
import '../models/novel_chapter.dart';

/// 小说书架数据仓库
class NovelRepository {
  NovelRepository(this._isar);
  final Isar _isar;

  /// 查询所有小说（按创建时间升序）
  Future<List<Novel>> getAll() =>
      _isar.novels.where().sortByCreatedAt().findAll();

  /// 监听所有小说的变化（实时流）
  Stream<List<Novel>> watchAll() =>
      _isar.novels.where().sortByCreatedAt().watch(fireImmediately: true);

  /// 按 id 查询小说
  Future<Novel?> getById(Id id) => _isar.novels.get(id);

  /// 按源站详情页 URL 查询（添加小说时去重）
  Future<Novel?> findBySourceUrl(String sourceUrl) => _isar.novels
      .filter()
      .sourceUrlEqualTo(sourceUrl)
      .findFirst();

  /// 新增小说
  Future<void> add(Novel novel) =>
      _isar.writeTxn(() async => _isar.novels.put(novel));

  /// 编辑小说
  Future<void> update(Novel novel) =>
      _isar.writeTxn(() async => _isar.novels.put(novel));

  /// 删除小说
  Future<void> delete(Id id) =>
      _isar.writeTxn(() async => _isar.novels.delete(id));

  /// 更新阅读进度（章节下标 + 比例 0..1）
  Future<void> updateProgress(
    Id id,
    int chapterIndex,
    double position,
  ) =>
      _isar.writeTxn(() async {
        final novel = await _isar.novels.get(id);
        if (novel == null) return;
        novel.lastChapterIndex = chapterIndex;
        novel.lastPosition = position.clamp(0.0, 1.0);
        novel.lastReadAt = DateTime.now();
        await _isar.novels.put(novel);
      });

  /// 启动时恢复异常中断的爬取状态
  ///
  /// 进程被杀后 crawlStatus 可能永久卡在 'crawling'（详情页「更新章节」按钮
  /// 永久禁用）；addNovel 中途被杀也可能残留 0 章节的半成品。此方法：
  /// - crawling → success（恢复正常可更新）
  /// - 非内置且无实际章节的小说删除（半成品残骸）
  Future<void> recoverInterruptedCrawls() =>
      _isar.writeTxn(() async {
        final all = await _isar.novels.where().findAll();
        for (final novel in all) {
          final chapterCount = await _isar.novelChapters
              .where()
              .novelIdEqualTo(novel.id)
              .count();
          if (chapterCount == 0 && !novel.isBuiltin) {
            await _isar.novels.delete(novel.id);
            continue;
          }
          if (novel.crawlStatus == 'crawling') {
            novel.crawlStatus = 'success';
            await _isar.novels.put(novel);
          }
        }
      });
}
