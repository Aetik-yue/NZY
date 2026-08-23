import 'package:isar/isar.dart';
import '../models/focus_session.dart';

/// 专注记录仓库
class FocusSessionRepository {
  FocusSessionRepository(this._isar);
  final Isar _isar;

  /// 查询所有记录（按开始时间降序）
  Future<List<FocusSession>> getAll() =>
      _isar.focusSessions.where().sortByStartTimeDesc().findAll();

  /// 监听所有记录的变化（实时流，按开始时间降序）
  Stream<List<FocusSession>> watchAll() => _isar.focusSessions
      .where()
      .sortByStartTimeDesc()
      .watch(fireImmediately: true);

  /// 监听今日（含今天 0 点起）的 focus 类型记录
  ///
  /// 用 startTime 索引做 where 条件限定时间下界，再 filter 过滤专注类型。
  /// startOfDay 在流创建时捕获，跨午夜后需重建流才会刷新「今日」范围。
  Stream<List<FocusSession>> watchToday() {
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    return _isar.focusSessions
        .where()
        .startTimeGreaterThan(startOfDay, include: true)
        .filter()
        .typeEqualTo(FocusType.focus)
        .sortByStartTimeDesc()
        .watch(fireImmediately: true);
  }

  /// 新增记录
  Future<void> add(FocusSession session) =>
      _isar.writeTxn(() async => _isar.focusSessions.put(session));

  /// 编辑记录
  Future<void> update(FocusSession session) =>
      _isar.writeTxn(() async => _isar.focusSessions.put(session));

  /// 删除记录
  Future<void> delete(Id id) =>
      _isar.writeTxn(() async => _isar.focusSessions.delete(id));
}
