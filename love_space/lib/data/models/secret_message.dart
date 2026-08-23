import 'package:isar/isar.dart';

part 'secret_message.g.dart';

/// 悄悄话（双人私密留言）
@collection
class SecretMessage {
  Id id = Isar.autoIncrement;

  /// 留言内容
  late String content;

  /// 发送时间（消息不可变，兼作 LWW 时间戳）
  late DateTime createdAt;

  /// 是否已读（仅本地标记对方发来的消息）
  bool read = false;

  /// 云端文档 ID（双人同步；null = 未同步）
  String? cloudId;

  /// 发送者用户 ID（云端用户标识；本地发送为 null，上传时补充）
  String? ownerId;

  /// 同步时间戳（= createdAt）
  DateTime? updatedAt;
}
