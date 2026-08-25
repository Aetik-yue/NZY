import 'package:shared_preferences/shared_preferences.dart';

/// 公路闪避最高距离的本机持久化仓库。
class RacingScoreRepository {
  const RacingScoreRepository();

  static const String storageKey = 'racing_best_distance_v1';

  /// 读取历史最佳距离；没有纪录时返回 0。
  Future<int> getBestDistance() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getInt(storageKey) ?? 0;
  }

  /// 仅在 [distance] 严格更高时保存，并返回是否创造新纪录。
  Future<bool> saveIfHigher(int distance) async {
    final preferences = await SharedPreferences.getInstance();
    final current = preferences.getInt(storageKey) ?? 0;
    if (distance <= current) return false;
    final saved = await preferences.setInt(storageKey, distance);
    return saved;
  }
}
