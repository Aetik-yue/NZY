import 'package:isar/isar.dart';

part 'check_in.g.dart';

/// 每日打卡记录
@collection
class CheckIn {
  Id id = Isar.autoIncrement;

  /// 打卡日期（归一化为当天 00:00，加索引便于查询）
  @Index()
  late DateTime date;

  /// 打卡留言（可选）
  String? note;
}
