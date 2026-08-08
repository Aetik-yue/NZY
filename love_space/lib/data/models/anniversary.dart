import 'package:isar/isar.dart';

part 'anniversary.g.dart';

/// 纪念日（多节点：在一起 / 生日 / 自定义纪念日）
@collection
class Anniversary {
  Id id = Isar.autoIncrement;

  /// 纪念日名称（如：我们的纪念日、你的生日）
  late String title;

  /// 纪念日日期（只取月日参与年度循环计算，年份仅作展示）
  late DateTime date;

  /// 备注（可选）
  String note = '';

  /// 标记色（ARGB 整型，取模设计令牌调色板）
  int colorValue = 0xFFFF6B9D;

  /// 是否启用提前提醒
  bool remindEnabled = false;

  /// 提前提醒天数（0 = 当天提醒）
  int remindDays = 3;

  late DateTime createdAt;
}
