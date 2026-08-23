import 'package:isar/isar.dart';
import '../models/secret_message.dart';

/// 悄悄话数据仓库
class SecretMessageRepository {
  SecretMessageRepository(this._isar);
  final Isar _isar;

  /// 查询全部（按时间倒序，最新在前）
  Future<List<SecretMessage>> getAll() =>
      _isar.secretMessages.where().sortByCreatedAtDesc().findAll();

  /// 监听全部（实时流）
  Stream<List<SecretMessage>> watchAll() => _isar.secretMessages
      .where()
      .sortByCreatedAtDesc()
      .watch(fireImmediately: true);

  /// 新增留言
  Future<void> add(SecretMessage message) => _isar.writeTxn(() async {
        message.updatedAt = DateTime.now();
        // 本机发送的消息不应计入自己的未读角标。
        message.read = true;
        await _isar.secretMessages.put(message);
      });

  /// 标记为已读
  Future<void> markRead(Id id) => _isar.writeTxn(() async {
        final m = await _isar.secretMessages.get(id);
        if (m != null && !m.read) {
          m.read = true;
          await _isar.secretMessages.put(m);
        }
      });

  /// 全部标记已读
  Future<void> markAllRead() => _isar.writeTxn(() async {
        final items = await _isar.secretMessages.where().findAll();
        for (final m in items) {
          if (!m.read) {
            m.read = true;
            await _isar.secretMessages.put(m);
          }
        }
      });

  /// 删除留言
  Future<void> delete(Id id) =>
      _isar.writeTxn(() async => _isar.secretMessages.delete(id));
}
