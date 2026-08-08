import 'package:isar/isar.dart';
import '../models/memo.dart';

/// 备忘录数据仓库
class MemoRepository {
  MemoRepository(this._isar);
  final Isar _isar;

  /// 查询所有备忘录（按创建时间降序）
  Future<List<Memo>> getAll() =>
      _isar.memos.where().sortByCreatedAtDesc().findAll();

  /// 监听所有备忘录的变化（实时流）
  Stream<List<Memo>> watchAll() =>
      _isar.memos.where().sortByCreatedAtDesc().watch(fireImmediately: true);

  /// 按 id 查询单条
  Future<Memo?> getById(Id id) => _isar.memos.get(id);

  /// 新增备忘录
  Future<void> add(Memo memo) =>
      _isar.writeTxn(() async => _isar.memos.put(memo));

  /// 编辑备忘录
  Future<void> update(Memo memo) =>
      _isar.writeTxn(() async => _isar.memos.put(memo));

  /// 删除备忘录
  Future<void> delete(Id id) =>
      _isar.writeTxn(() async => _isar.memos.delete(id));

  /// 切换置顶状态
  Future<void> togglePin(Id id) => _isar.writeTxn(() async {
        final m = await _isar.memos.get(id);
        if (m == null) return;
        m.isPinned = !m.isPinned;
        await _isar.memos.put(m);
      });

  /// 切换完成状态（读出取反写回）
  Future<void> toggleDone(Id id) => _isar.writeTxn(() async {
        final m = await _isar.memos.get(id);
        if (m == null) return;
        m.done = !m.done;
        await _isar.memos.put(m);
      });
}
