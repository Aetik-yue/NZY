import 'package:flutter/material.dart';
import 'app_colors.dart';

/// 字体样式系统
/// 设计稿使用 Sarasa Gothic SC（中文）+ Inter（数字）
/// 注：google_fonts 因兼容性问题暂时移除，使用系统默认字体
class AppTextStyles {
  AppTextStyles._();

  /// 中文正文字体族
  static const String cjkFontFamily = 'PingFang SC';

  /// 数字/英文字体族
  static const String latinFontFamily = 'Inter';

  // ──────── 标题 ────────
  /// 大标题（页面标题）22px Bold
  static TextStyle get titleLarge => const TextStyle(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        fontFamily: cjkFontFamily,
      );

  /// 中标题（模块标题）18px Bold
  static TextStyle get titleMedium => const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        fontFamily: cjkFontFamily,
      );

  /// 小标题（卡片标题）17px Bold
  static TextStyle get titleSmall => const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        fontFamily: cjkFontFamily,
      );

  // ──────── 正文 ────────
  /// 正文 14px Regular
  static TextStyle get body => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
        fontFamily: cjkFontFamily,
      );

  /// 正文小 13px Regular
  static TextStyle get bodySmall => const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        fontFamily: cjkFontFamily,
      );

  /// 辅助文字 12px Regular
  static TextStyle get caption => const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
        fontFamily: cjkFontFamily,
      );

  /// 标签/三级 11px Regular
  static TextStyle get label => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
        fontFamily: cjkFontFamily,
      );

  // ──────── 特殊 ────────
  /// 粉色背景上的文字 14px Regular 白色
  static TextStyle get onPink => const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textOnPink,
        fontFamily: cjkFontFamily,
      );

  /// 状态栏时间 17px SemiBold
  static TextStyle get statusBarTime => const TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
        fontFamily: latinFontFamily,
      );

  /// 日期数字 11px Medium（时间轴日期）
  static TextStyle get dateLabel => const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.accentRose,
        fontFamily: latinFontFamily,
      );

  /// 大数字（纪念日天数）56px Bold
  static TextStyle get heroNumber => const TextStyle(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        color: AppColors.textOnPink,
        height: 1.0,
        fontFamily: latinFontFamily,
      );

  /// 统计数字 20px Bold
  static TextStyle get statNumber => const TextStyle(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        fontFamily: latinFontFamily,
      );

  /// Tab 标签 10px
  static TextStyle get tabLabel => const TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        fontFamily: cjkFontFamily,
      );
}
