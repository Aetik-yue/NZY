import 'package:isar/isar.dart';
import '../models/album_photo.dart';

/// 相册数据仓库
class AlbumRepository {
  AlbumRepository(this._isar);
  final Isar _isar;

  /// 照片总数
  Future<int> count() => _isar.albumPhotos.count();

  /// 查询最近的照片
  Future<List<AlbumPhoto>> getRecent(int limit) =>
      _isar.albumPhotos.where().sortByDateDesc().limit(limit).findAll();

  /// 监听最近的照片（实时流）
  Stream<List<AlbumPhoto>> watchRecent(int limit) => _isar.albumPhotos
      .where()
      .sortByDateDesc()
      .limit(limit)
      .watch(fireImmediately: true);

  /// 监听所有照片（实时流，按时间倒序，用于统计数量）
  Stream<List<AlbumPhoto>> watchAll() =>
      _isar.albumPhotos.where().sortByDateDesc().watch(fireImmediately: true);

  /// 按分类监听照片（按时间倒序）
  Stream<List<AlbumPhoto>> watchByCategory(PhotoCategory category) =>
      _isar.albumPhotos
          .where()
          .filter()
          .categoryEqualTo(category)
          .sortByDateDesc()
          .watch(fireImmediately: true);

  /// 编辑照片
  Future<void> update(AlbumPhoto photo) => _isar.writeTxn(() async {
        photo.updatedAt = DateTime.now();
        await _isar.albumPhotos.put(photo);
      });

  /// 新增照片
  Future<void> add(AlbumPhoto photo) => _isar.writeTxn(() async {
        photo.updatedAt = DateTime.now();
        await _isar.albumPhotos.put(photo);
      });

  /// 删除照片
  Future<void> delete(Id id) =>
      _isar.writeTxn(() async => _isar.albumPhotos.delete(id));
}
