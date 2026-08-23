import 'package:flutter/material.dart';

/// 愿望预置图标（常量列表，供添加表单与列表展示共用）
///
/// 图标按 codePoint 存储到数据库；展示时必须解析回**常量** IconData，
/// 否则 release 构建的图标 tree-shaking 会因非常量 IconData 失败。
const List<IconData> kPresetWishIcons = [
  Icons.flight_rounded,
  Icons.cake_rounded,
  Icons.pets_rounded,
  Icons.star_rounded,
  Icons.favorite_rounded,
  Icons.home_rounded,
  Icons.wb_sunny_rounded,
  Icons.music_note_rounded,
  Icons.menu_book_rounded,
  Icons.photo_camera_rounded,
  Icons.directions_bike_rounded,
  Icons.celebration_rounded,
];

/// 按 codePoint 还原预置图标（未命中回退星星图标）
IconData wishIconFor(int codePoint) => kPresetWishIcons.firstWhere(
      (icon) => icon.codePoint == codePoint,
      orElse: () => Icons.star_rounded,
    );