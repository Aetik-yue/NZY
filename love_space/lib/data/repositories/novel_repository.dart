import 'package:isar/isar.dart';
import '../models/novel.dart';

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
}
