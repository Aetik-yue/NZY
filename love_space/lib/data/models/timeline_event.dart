import 'package:isar/isar.dart';

part 'timeline_event.g.dart';

/// 恋爱时间轴事件
@collection
class TimelineEvent {
  Id id = Isar.autoIncrement;

  late DateTime date;

  late String title;

  late String description;

  /// 时间轴圆点的颜色值（Color.value）
  late int dotColorValue;

  /// 云端文档 ID（双人同步；null = 未同步）
  String? cloudId;

  /// 最后修改时间（双人同步 LWW 冲突解决用；写操作时更新）
  DateTime? updatedAt;

  /// 创建者标识（云端用户 ID；本机创建为 null，上传时补充）
  String? ownerId;
}
