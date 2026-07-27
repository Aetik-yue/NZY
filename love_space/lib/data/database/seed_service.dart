import 'package:isar/isar.dart';
import '../../core/constants/seed_data.dart';
import '../../data/models/timeline_event.dart';
import '../../data/models/check_in.dart';
import '../../data/models/app_settings.dart';

/// 首次启动种子数据服务
class SeedService {
  SeedService(this._isar);
  final Isar _isar;

  /// 若数据库为空则写入种子数据（幂等，可安全地在每次启动时调用）
  static Future<void> seedIfEmpty(Isar isar) async {
    final existing = await isar.appSettings.where().findFirst();
    if (existing != null) return; // 已初始化过

    final service = SeedService(isar);
    await service._seed();
  }

  Future<void> _seed() async {
    await _isar.writeTxn(() async {
      // 设置
      await _isar.appSettings.put(Seed.settings());

      // 时间轴
      await _isar.timelineEvents.putAll(Seed.timelineEvents());

      // 打卡
      await _isar.checkIns.putAll(Seed.checkIns());
    });
  }
}
