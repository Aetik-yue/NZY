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
}
