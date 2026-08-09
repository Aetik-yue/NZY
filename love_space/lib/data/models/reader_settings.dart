import 'package:isar/isar.dart';

part 'reader_settings.g.dart';

/// 阅读器设置（单例行，全局唯一）
///
/// bgTheme 映射：0=白 / 1=米黄 / 2=粉 / 3=护眼绿 / 4=夜间。
@collection
class ReaderSettings {
  Id id = Isar.autoIncrement;

  /// 正文字号（16~24）
  late double fontSize;

  /// 行距倍率（1.2~2.0）
  late double lineHeight;

  /// 段间距（8~24，默认 12）
  late double paragraphSpacing;

  /// 翻页模式：0=滚动 / 1=翻页
  late int pageMode;

  /// 背景主题（0~4，详见 AppColors.readerBg）
  late int bgTheme;

  /// 常亮（仅持久化，未接系统唤醒锁）
  late bool keepScreenOn;
}
