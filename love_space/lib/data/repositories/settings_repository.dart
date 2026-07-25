import 'package:isar/isar.dart';
import '../models/app_settings.dart';

/// 设置数据仓库
class SettingsRepository {
  SettingsRepository(this._isar);
  final Isar _isar;

  /// 读取设置记录（第一条）
  Future<AppSettings?> get() => _isar.appSettings.where().findFirst();

  /// 监听设置变化（实时流）
  Stream<AppSettings?> watch() => _isar.appSettings
      .where()
      .watch(fireImmediately: true)
      .map((list) => list.isEmpty ? null : list.first);

  /// 保存设置
  Future<void> save(AppSettings settings) =>
      _isar.writeTxn(() async => _isar.appSettings.put(settings));
}
