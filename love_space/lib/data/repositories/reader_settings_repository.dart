import 'package:isar/isar.dart';
import '../models/reader_settings.dart';

/// 阅读设置数据仓库（单例行）
class ReaderSettingsRepository {
  ReaderSettingsRepository(this._isar);
  final Isar _isar;

  /// 读取设置（首条为空则写入默认值）
  Future<ReaderSettings> getOrCreate() async {
    final existing = await _isar.readerSettings.where().findFirst();
    if (existing != null) return existing;
    final defaults = ReaderSettings()
      ..fontSize = 18
      ..lineHeight = 1.6
      ..pageMode = 0
      ..bgTheme = 0
      ..keepScreenOn = true;
    await _isar.writeTxn(() async => _isar.readerSettings.put(defaults));
    return defaults;
  }

  /// 监听设置变化（实时流）
  Stream<ReaderSettings?> watch() => _isar.readerSettings
      .where()
      .watch(fireImmediately: true)
      .map((list) => list.isEmpty ? null : list.first);

  /// 保存设置
  Future<void> save(ReaderSettings settings) =>
      _isar.writeTxn(() async => _isar.readerSettings.put(settings));
}
