import 'package:isar/isar.dart';

part 'app_settings.g.dart';

/// 应用/情侣设置（单例集合，只读第一条记录）
@collection
class AppSettings {
  Id id = Isar.autoIncrement;

  late String partner1Name;

  late String partner2Name;

  /// 在一起的起始日期（归一化为当天 00:00）
  late DateTime togetherSince;

  /// 备忘录数量（暂无 Memo 模型，先以字段暂存）
  int memoCount = 86;
}
