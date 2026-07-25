import 'package:isar/isar.dart';

part 'album_photo.g.dart';

/// 照片分类（"全部" 表示不筛选，不在枚举中）
enum PhotoCategory { travel, food, daily }

/// 相册照片元数据
@collection
class AlbumPhoto {
  Id id = Isar.autoIncrement;

  late DateTime date;

  @Enumerated(EnumType.name)
  late PhotoCategory category;

  /// 真实照片本地路径（为空时 UI 用渐变色块占位）
  String? filePath;

  /// 占位渐变色的索引（循环使用预设渐变）
  late int gradientIndex;
}
