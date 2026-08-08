import 'package:isar/isar.dart';

part 'pomodoro_settings.g.dart';

/// 番茄钟设置（单例，id 固定 0）
@collection
class PomodoroSettings {
  Id id = 0;

  /// 专注分钟，默认 25
  late int focusMin;

  /// 短休息分钟，默认 5
  late int shortBreakMin;

  /// 长休息分钟，默认 15
  late int longBreakMin;

  /// 每 N 个番茄后长休，默认 4
  late int longBreakInterval;

  /// 专注完自动开始休息，默认 true
  late bool autoStartBreak;

  /// 休息完自动开始专注，默认 false
  late bool autoStartFocus;
}
