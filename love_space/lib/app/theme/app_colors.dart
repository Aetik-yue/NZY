import 'package:flutter/material.dart';

/// 设计令牌 · 严格还原 Ardot 设计稿
/// 配色：暖奶油粉主题，玫瑰粉为主色，珊瑚/樱花粉为辅
class AppColors {
  AppColors._();

  // ──────── 背景 ────────
  /// 主背景 暖奶油粉 #FFF2F7
  static const bgPrimary = Color(0xFFFFF2F7);
  /// 卡片背景 纯白
  static const bgCard = Color(0xFFFFFFFF);
  /// 浅腮红背景 #FFF0F2
  static const bgBlush = Color(0xFFFFF0F2);
  /// 奶油背景 #FFF5F7
  static const bgCream = Color(0xFFFFF5F7);

  // ──────── 强调色 ────────
  /// 主玫瑰粉 #FF6B9D（CTA / 激活态）
  static const accentRose = Color(0xFFFF6B9D);
  /// 柔粉 #FF8FB1
  static const accentPink = Color(0xFFFF8FB1);
  /// 樱花粉（浅）#FFD4E0
  static const accentPinkSoft = Color(0xFFFFD4E0);
  /// 桃色 #FFD1BF
  static const accentPeach = Color(0xFFFFD1BF);
  /// 珊瑚 #FFB5A1
  static const accentCoral = Color(0xFFFFB5A1);
  /// 锦葵紫 #B57DBA
  static const accentMauve = Color(0xFFB57DBA);

  // ──────── 文字 ────────
  /// 主文字 柔深紫 #33263B
  static const textPrimary = Color(0xFF33263B);
  /// 次要文字 #7D7582
  static const textSecondary = Color(0xFF7D7582);
  /// 三级文字 #B0A8B5
  static const textTertiary = Color(0xFFB0A8B5);
  /// 粉色背景上的文字 纯白
  static const textOnPink = Color(0xFFFFFFFF);

  // ──────── 边框 / 分割 ────────
  /// 柔边框 #F7E6F0
  static const borderSoft = Color(0xFFF7E6F0);

  // ──────── 阴影 ────────
  /// 粉色阴影 rgba(255,107,143,0.12)
  static const shadowPink = Color(0x1FFF6B8F);
  /// 卡片阴影 rgba(80,43,57,0.06)
  static const shadowCard = Color(0x0F502B39);

  // ──────── 渐变 ────────
  /// 首页纪念日主卡片渐变（玫瑰粉 → 樱花粉 → 桃色）
  static const heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8FB1), Color(0xFFFFB5CC), Color(0xFFFFD1BF)],
  );

  /// 粉色按钮渐变（柔粉 → 玫瑰粉）
  static const pinkButtonGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8FB1), Color(0xFFFF6B9D)],
  );

  /// 头部渐变（玫瑰粉 → 樱花粉）
  static const headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFF8FB1), Color(0xFFFFB5CC)],
  );

  /// 音乐迷你播放卡渐变（樱花粉 → 柔玫瑰粉）
  static const musicCardGradient = LinearGradient(
    colors: [Color(0xFFFFD4E0), Color(0xFFFFA1C6)],
  );

  /// 音乐封面渐变组（无封面图时按 id 取模占位）
  static const coverGradients = <LinearGradient>[
    LinearGradient(colors: [Color(0xFFFFBFD0), Color(0xFFFF8FB1)]),
    LinearGradient(colors: [Color(0xFFFFD1BF), Color(0xFFFFB5A1)]),
    LinearGradient(colors: [Color(0xFFFFB5CC), Color(0xFFFFD4E0)]),
    LinearGradient(colors: [Color(0xFFFFBFCC), Color(0xFFFFA1B5)]),
    LinearGradient(colors: [Color(0xFFFFE0D4), Color(0xFFFFB5CC)]),
    LinearGradient(colors: [Color(0xFFFF8FB1), Color(0xFFFF6B9D)]),
  ];

  // ──────── 圆角（Primitives）────────
  static const radiusCard = 24.0;
  static const radiusButton = 50.0;
  static const radiusMd = 16.0;
  static const radiusSm = 12.0;
  static const radiusXs = 8.0;
  static const radiusPill = 26.0;
  static const radiusTab = 36.0;

  // ──────── 阅读器背景主题 ────────
  /// 阅读器背景·白 #FFFFFF
  static const readerBgWhite = Color(0xFFFFFFFF);
  /// 阅读器背景·米黄 #F5EFE0
  static const readerBgCream = Color(0xFFF5EFE0);
  /// 阅读器背景·粉 #FCE9EF
  static const readerBgPink = Color(0xFFFCE9EF);
  /// 阅读器背景·护眼绿 #E3EDD9
  static const readerBgGreen = Color(0xFFE3EDD9);
  /// 阅读器背景·夜间 #222226
  static const readerBgDark = Color(0xFF222226);

  /// 阅读器文字·白底 #33263B
  static const readerTextOnWhite = Color(0xFF33263B);
  /// 阅读器文字·米黄底 #5A5142
  static const readerTextOnCream = Color(0xFF5A5142);
  /// 阅读器文字·粉底 #6B4753
  static const readerTextOnPink = Color(0xFF6B4753);
  /// 阅读器文字·护眼绿底 #3F5135
  static const readerTextOnGreen = Color(0xFF3F5135);
  /// 阅读器文字·夜间底 #C8C8CC
  static const readerTextOnDark = Color(0xFFC8C8CC);

  /// 根据背景主题下标返回背景色（0白 1米黄 2粉 3护眼绿 4夜间）
  static Color readerBg(int theme) {
    switch (theme) {
      case 1: return readerBgCream;
      case 2: return readerBgPink;
      case 3: return readerBgGreen;
      case 4: return readerBgDark;
      default: return readerBgWhite;
    }
  }

  /// 根据背景主题下标返回对应文字色
  static Color readerTextOn(int theme) {
    switch (theme) {
      case 1: return readerTextOnCream;
      case 2: return readerTextOnPink;
      case 3: return readerTextOnGreen;
      case 4: return readerTextOnDark;
      default: return readerTextOnWhite;
    }
  }

  // ──────── 间距（Primitives）────────
  static const spacing2xs = 4.0;
  static const spacingXs = 8.0;
  static const spacingSm = 12.0;
  static const spacingMd = 16.0;
  static const spacingLg = 20.0;
  static const spacingXl = 24.0;
  static const spacing2xl = 32.0;
}
