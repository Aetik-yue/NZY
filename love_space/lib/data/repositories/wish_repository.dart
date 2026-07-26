import 'package:isar/isar.dart';
import '../models/wish.dart';

/// 愿望数据仓库
class WishRepository {
  WishRepository(this._isar);
  final Isar _isar;

  /// 查询所有愿望（按创建时间排序）
  Future<List<Wish>> getAll() =>
      _isar.wishs.where().sortByCreatedAt().findAll();

  /// 监听所有愿望的变化（实时流）
  Stream<List<Wish>> watchAll() =>
      _isar.wishs.where().sortByCreatedAt().watch(fireImmediately: true);

  /// 新增愿望
  Future<void> add(Wish wish) =>
      _isar.writeTxn(() async => _isar.wishs.put(wish));

  /// 切换愿望完成状态
  Future<void> toggleDone(Id id) => _isar.writeTxn(() async {
        final w = await _isar.wishs.get(id);
        if (w != null) {
          w.done = !w.done;
          await _isar.wishs.put(w);
        }
      });

  /// 编辑愿望
  Future<void> update(Wish wish) =>
      _isar.writeTxn(() async => _isar.wishs.put(wish));

  /// 删除愿望
  Future<void> delete(Id id) =>
      _isar.writeTxn(() async => _isar.wishs.delete(id));
}
