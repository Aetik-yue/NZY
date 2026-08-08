import 'package:isar/isar.dart';

part 'memo.g.dart';

/// 待办优先级
enum TodoPriority { none, high, medium, low }

/// 备忘录条目
///
/// 承载情侣双方的日常记录：情话、计划、回忆、待办等。
/// 标签以内嵌 `#标签名` 语法存储在 content 中，UI 层解析展示。
@collection
class Memo {
  Id id = Isar.autoIncrement;

  /// 正文内容（支持 #tag 语法内嵌标签）
  late String content;

  /// 作者标识：1 = partner1，2 = partner2
  late int author;

  /// 是否置顶（置顶项排在列表最前）
  late bool isPinned;

  /// 卡片背景色（Color.value），暖粉系预设
  late int colorValue;

  /// 创建时间（用于排序和日期分组）
  late DateTime createdAt;

  /// 最后修改时间（null = 未修改过）
  DateTime? updatedAt;

  /// 完成状态（待办场景使用，默认 false）
  late bool done;

  /// 截止日期（可选，待办场景使用；null = 无截止）
  DateTime? dueDate;

  /// 优先级（待办场景使用，默认 none）
  @Enumerated(EnumType.name)
  late TodoPriority priority;
}
