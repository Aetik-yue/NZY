import 'package:isar/isar.dart';
import '../models/anniversary.dart';

/// 纪念日数据仓库
class AnniversaryRepository {
  AnniversaryRepository(this._isar);
  final Isar _isar;

  /// 查询全部（按日期升序）
  Future<List<Anniversary>> getAll() =>
      _isar.anniversarys.where().sortByDate().findAll();

  /// 监听全部（实时流，按日期升序）
  Stream<List<Anniversary>> watchAll() =>
      _isar.anniversarys.where().sortByDate().watch(fireImmediately: true);

  /// 按 ID 查询
  Future<Anniversary?> getById(Id id) => _isar.anniversarys.get(id);

  /// 新增
  Future<void> add(Anniversary item) => _isar.writeTxn(() async {
        item.updatedAt = DateTime.now();
        await _isar.anniversarys.put(item);
      });

  /// 编辑
  Future<void> update(Anniversary item) => _isar.writeTxn(() async {
        item.updatedAt = DateTime.now();
        await _isar.anniversarys.put(item);
      });

  /// 删除
  Future<void> delete(Id id) =>
      _isar.writeTxn(() async => _isar.anniversarys.delete(id));
}
