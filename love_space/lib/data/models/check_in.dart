import 'package:isar/isar.dart';

part 'check_in.g.dart';

/// 每日打卡记录
@collection
class CheckIn {
  Id id = Isar.autoIncrement;

  /// 打卡日期（归一化为当天 00:00，加索引便于查询）
  @Index()
  late DateTime date;

  /// 打卡留言（可选）
  String? note;

  /// 云端文档 ID（双人同步；null = 未同步）
  String? cloudId;

  /// 最后修改时间（双人同步 LWW 冲突解决用；写操作时更新）
  DateTime? updatedAt;

  /// 创建者标识（云端用户 ID；本机创建为 null，上传时补充）
  String? ownerId;
}
