import '../../data/models/timeline_event.dart';
import '../../data/models/check_in.dart';
import '../../data/models/app_settings.dart';
import '../utils/date_utils.dart';

/// 首次启动的种子数据
class Seed {
  static const partner1Name = '严浩睿';
  static const partner2Name = '倪子越';
  static const checkinStreak = 128;

  /// 在一起的起始日期（硬编码 2025-10-16）
  static DateTime get togetherSince => DateTime(2025, 10, 16);

  /// 种子设置
  static AppSettings settings() => AppSettings()
    ..partner1Name = partner1Name
    ..partner2Name = partner2Name
    ..togetherSince = togetherSince;

  /// 种子时间轴事件
  static List<TimelineEvent> timelineEvents() => [
        TimelineEvent()
          ..date = DateTime(2024, 5, 20)
          ..title = '表白纪念日'
          ..description = '那天下着小雨，你说了"我愿意"'
          ..dotColorValue = 0xFFFF6B9D,
        TimelineEvent()
          ..date = DateTime(2024, 8, 8)
          ..title = '第一次旅行'
          ..description = '去了海边，一起看了日落与星空'
          ..dotColorValue = 0xFFFF8FB1,
      ];

  /// 种子打卡记录（过去 128 天每天一条，模拟连续打卡）
  static List<CheckIn> checkIns() {
    final now = DateUtilsX.today();
    return List.generate(checkinStreak, (i) {
      return CheckIn()..date = now.subtract(Duration(days: i));
    });
  }
}
