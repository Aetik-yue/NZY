import 'package:isar/isar.dart';

part 'focus_session.g.dart';

/// 专注/休息记录
@collection
class FocusSession {
  Id id = Isar.autoIncrement;

  /// 开始时间（加索引便于按时间查询）
  @Index()
  late DateTime startTime;

  /// 计划时长（分钟）
  late int plannedMin;

  /// 实际时长（完成=planned，放弃=中断时长）
  late int actualMin;

  /// 是否完成
  late bool completed;

  /// 记录类型
  @Enumerated(EnumType.name)
  late FocusType type;

  /// 自定义标签（可选）
  String? tag;
}

/// 记录类型
enum FocusType { focus, shortBreak, longBreak }
