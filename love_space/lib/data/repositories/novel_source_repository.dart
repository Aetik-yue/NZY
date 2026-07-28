import 'package:isar/isar.dart';
import '../models/novel_source.dart';

/// 小说爬取源数据仓库
class NovelSourceRepository {
  NovelSourceRepository(this._isar);
  final Isar _isar;

  /// 查询所有爬取源
  Future<List<NovelSource>> getAll() =>
      _isar.novelSources.where().findAll();

  /// 监听所有爬取源的变化（实时流）
  Stream<List<NovelSource>> watchAll() =>
      _isar.novelSources.where().watch(fireImmediately: true);

  /// 按 key 查询爬取源
  Future<NovelSource?> getByKey(String key) =>
      _isar.novelSources.where().keyEqualTo(key).findFirst();

  /// 查询所有启用的爬取源
  Future<List<NovelSource>> getEnabled() =>
      _isar.novelSources.where().filter().enabledEqualTo(true).findAll();

  /// 新增爬取源
  Future<void> add(NovelSource source) =>
      _isar.writeTxn(() async => _isar.novelSources.put(source));

  /// 编辑爬取源
  Future<void> update(NovelSource source) =>
      _isar.writeTxn(() async => _isar.novelSources.put(source));

  /// 删除爬取源
  Future<void> delete(Id id) =>
      _isar.writeTxn(() async => _isar.novelSources.delete(id));
}
