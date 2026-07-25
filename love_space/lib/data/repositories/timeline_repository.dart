import 'package:isar/isar.dart';
import '../models/timeline_event.dart';

/// 时间轴数据仓库
class TimelineRepository {
  TimelineRepository(this._isar);
  final Isar _isar;

  /// 查询所有时间轴事件（按日期倒序）
  Future<List<TimelineEvent>> getAll() =>
      _isar.timelineEvents.where().sortByDateDesc().findAll();

  /// 监听所有事件的变化（实时流）
  Stream<List<TimelineEvent>> watchAll() => _isar.timelineEvents
      .where()
      .sortByDateDesc()
      .watch(fireImmediately: true);

  /// 新增事件
  Future<void> add(TimelineEvent event) =>
      _isar.writeTxn(() async => _isar.timelineEvents.put(event));

  /// 删除事件
  Future<void> delete(Id id) =>
      _isar.writeTxn(() async => _isar.timelineEvents.delete(id));
}
