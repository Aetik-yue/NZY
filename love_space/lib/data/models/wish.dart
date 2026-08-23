import 'package:isar/isar.dart';

part 'wish.g.dart';

/// 愿望清单条目
@collection
class Wish {
  Id id = Isar.autoIncrement;

  late String title;

  late String description;

  /// 图标 codePoint（MaterialIcons），UI 层用 IconData(iconCodePoint) 还原
  late int iconCodePoint;

  late bool done;

  late DateTime createdAt;

  /// 云端文档 ID（双人同步；null = 未同步）
  String? cloudId;

  /// 最后修改时间（双人同步 LWW 冲突解决用；写操作时更新）
  DateTime? updatedAt;

  /// 创建者标识（云端用户 ID；本机创建为 null，上传时补充）
  String? ownerId;
}
