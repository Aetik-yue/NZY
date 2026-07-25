import 'package:flutter/material.dart';
import '../../data/models/wish.dart';
import '../../data/models/timeline_event.dart';
import '../../data/models/album_photo.dart';
import '../../data/models/check_in.dart';
import '../../data/models/app_settings.dart';
import '../utils/date_utils.dart';

/// 首次启动的种子数据（对应现有 UI 中的硬编码假数据）
class Seed {
  static const partner1Name = '小桃';
  static const partner2Name = '阿树';
  static const daysTogether = 365;
  static const checkinStreak = 128;
  static const photoCount = 128;
  static const wishTotal = 32;
  static const wishDone = 8;
  static const memoCount = 86;

  /// 在一起的起始日期（今天往前推 365 天）
  static DateTime get togetherSince =>
      DateUtilsX.today().subtract(const Duration(days: daysTogether));

  /// 种子设置
  static AppSettings settings() => AppSettings()
    ..partner1Name = partner1Name
    ..partner2Name = partner2Name
    ..togetherSince = togetherSince
    ..memoCount = memoCount;

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

  /// 种子愿望（8 个已完成 + 24 个未完成 = 32 个）
  static List<Wish> wishes() {
    final list = <Wish>[];

    // 8 个已完成的愿望
    final doneWishes = [
      ('一起看日出', '在海边等第一缕阳光', Icons.wb_sunny_rounded),
      ('养一只小猫咪', '给它起个可爱的名字', Icons.pets_rounded),
      ('一起做一顿烛光晚餐', '学一道对方最爱的菜', Icons.cake_rounded),
      ('交换日记本', '写下想对对方说的话', Icons.menu_book_rounded),
      ('一起淋雨', '在雨里奔跑和大笑', Icons.umbrella_rounded),
      ('拍大头贴', '在照相亭里做鬼脸', Icons.photo_camera_rounded),
      ('一起看星星', '找一个晴朗的夜晚', Icons.star_rounded),
      ('为对方写一封信', '把心意写在纸上', Icons.mail_rounded),
    ];
    for (final (title, desc, icon) in doneWishes) {
      list.add(Wish()
        ..title = title
        ..description = desc
        ..iconCodePoint = icon.codePoint
        ..done = true
        ..createdAt = togetherSince.add(Duration(days: list.length * 10)));
    }

    // 24 个未完成的愿望
    final undoneWishes = [
      ('一起去北海道看雪', '冬天的时候，住进温泉旅馆', Icons.flight_rounded),
      ('一起坐摩天轮', '在最高点的时候许愿', Icons.roundabout_right_rounded),
      ('一起看海边的日落', '牵手走在沙滩上', Icons.wb_twilight_rounded),
      ('一起逛夜市', '尝遍所有小吃', Icons.storefront_rounded),
      ('一起养一盆植物', '看着它慢慢长大', Icons.local_florist_rounded),
      ('一起看烟花', '在跨年的夜晚', Icons.celebration_rounded),
      ('一起去游乐园', '坐过山车和旋转木马', Icons.attractions_rounded),
      ('一起做手工', '做一个属于我们的纪念品', Icons.build_rounded),
      ('一起骑自行车', '在傍晚的街道上', Icons.directions_bike_rounded),
      ('一起看演唱会', '为对方应唱一首歌', Icons.music_note_rounded),
      ('一起堆雪人', '在第一个下雪天', Icons.ac_unit_rounded),
      ('一起放风筝', '在春天的草地上', Icons.air_rounded),
      ('一起泡温泉', '在寒冷的冬天', Icons.hot_tub_rounded),
      ('一起看樱花', '在花瓣飘落的季节', Icons.eco_rounded),
      ('一起做蛋糕', '为对方庆生', Icons.cake_rounded),
      ('一起拍婚纱照', '记录最美的时刻', Icons.photo_camera_rounded),
      ('一起养一只狗', '每天一起遛狗', Icons.pets_rounded),
      ('一起去看极光', '在北极的夜空下', Icons.nights_stay_rounded),
      ('一起开一家小店', '卖我们喜欢的东西', Icons.store_rounded),
      ('一起环游世界', '走遍想去的每一个地方', Icons.public_rounded),
      ('一起建一个家', '把它布置成喜欢的风格', Icons.home_rounded),
      ('一起慢慢变老', '牵着的手不松开', Icons.favorite_rounded),
      ('许下一百个愿望', '一个一个去完成', Icons.star_border_rounded),
      ('永远在一起', '不止此生此世', Icons.favorite_border_rounded),
    ];
    for (final (title, desc, icon) in undoneWishes) {
      list.add(Wish()
        ..title = title
        ..description = desc
        ..iconCodePoint = icon.codePoint
        ..done = false
        ..createdAt = togetherSince.add(Duration(days: list.length * 10)));
    }

    return list;
  }

  /// 种子相册照片（128 张，循环分类和渐变索引）
  static List<AlbumPhoto> photos() {
    final categories = PhotoCategory.values;
    final now = DateUtilsX.today();
    return List.generate(photoCount, (i) {
      return AlbumPhoto()
        ..date = now.subtract(Duration(days: i * 2))
        ..category = categories[i % categories.length]
        ..gradientIndex = i % 6
        ..filePath = null; // 暂无真实照片，UI 用渐变色块占位
    });
  }

  /// 种子打卡记录（过去 128 天每天一条，模拟连续打卡）
  static List<CheckIn> checkIns() {
    final now = DateUtilsX.today();
    return List.generate(checkinStreak, (i) {
      return CheckIn()..date = now.subtract(Duration(days: i));
    });
  }
}
