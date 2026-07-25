import 'package:isar/isar.dart';

part 'wish.g.dart';

/// 愿望清单条目
@collection
class Wish {
  Id id = Isar.autoIncrement;

  late String title;

  late String description;

  /// 图标的 codePoint（MaterialIcons），UI 层用 IconData(iconCodePoint) 还原
  late int iconCodePoint;

  late bool done;

  late DateTime createdAt;
}
