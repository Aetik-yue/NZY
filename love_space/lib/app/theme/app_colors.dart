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

  // ──────── 圆角（Primitives）────────
  static const radiusCard = 24.0;
  static const radiusButton = 50.0;
  static const radiusMd = 16.0;
  static const radiusSm = 12.0;
  static const radiusXs = 8.0;
  static const radiusPill = 26.0;
  static const radiusTab = 36.0;

  // ──────── 间距（Primitives）────────
  static const spacing2xs = 4.0;
  static const spacingXs = 8.0;
  static const spacingSm = 12.0;
  static const spacingMd = 16.0;
  static const spacingLg = 20.0;
  static const spacingXl = 24.0;
  static const spacing2xl = 32.0;
}
