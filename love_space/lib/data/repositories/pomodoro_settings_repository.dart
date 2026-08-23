import 'package:isar/isar.dart';
import '../models/pomodoro_settings.dart';

/// 番茄钟设置仓库（单例，id 固定 0）
///
/// 全局只有一份设置，固定占用 id=0；watchObject 在行不存在时发 null，
/// 由 [watch] 以默认值兜底，保证 UI 始终拿到非空设置。
class PomodoroSettingsRepository {
  PomodoroSettingsRepository(this._isar);
  final Isar _isar;

  /// 构造一份默认设置（不落库）
  PomodoroSettings _defaults() => PomodoroSettings()
    ..focusMin = 25
    ..shortBreakMin = 5
    ..longBreakMin = 15
    ..longBreakInterval = 4
    ..autoStartBreak = true
    ..autoStartFocus = false;

  /// 获取单例设置（不存在则创建默认并落库）
  Future<PomodoroSettings> getOrCreate() async {
    final existing = await _isar.pomodoroSettings.get(0);
    if (existing != null) return existing;
    final settings = _defaults();
    await _isar.writeTxn(() async => _isar.pomodoroSettings.put(settings));
    return settings;
  }

  /// 监听单例设置变化（实时流，行不存在时以默认值兜底）
  Stream<PomodoroSettings> watch() => _isar.pomodoroSettings
      .watchObject(0, fireImmediately: true)
      .map((s) => s ?? _defaults());

  /// 保存设置（强制 id=0，保证幂等写入单例行）
  Future<void> save(PomodoroSettings settings) async {
    settings.id = 0;
    await _isar.writeTxn(() async => _isar.pomodoroSettings.put(settings));
  }
}
