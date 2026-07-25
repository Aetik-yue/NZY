import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// 字体样式系统
/// 设计稿使用 Sarasa Gothic SC（中文）+ Inter（数字）
/// Flutter 中用 Noto Sans SC 替代中文字体，Inter 用于数字/英文
class AppTextStyles {
  AppTextStyles._();

  /// 中文正文字体族（Noto Sans SC 接近 Sarasa Gothic SC 的圆润感）
  static String get cjkFontFamily => GoogleFonts.notoSansSc().fontFamily!;

  /// 数字/英文字体族
  static String get latinFontFamily => GoogleFonts.inter().fontFamily!;

  // ──────── 标题 ────────
  /// 大标题（页面标题）22px Bold
  static TextStyle get titleLarge => GoogleFonts.notoSansSc(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  /// 中标题（模块标题）18px Bold
  static TextStyle get titleMedium => GoogleFonts.notoSansSc(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  /// 小标题（卡片标题）17px Bold
  static TextStyle get titleSmall => GoogleFonts.notoSansSc(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  // ──────── 正文 ────────
  /// 正文 14px Regular
  static TextStyle get body => GoogleFonts.notoSansSc(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  /// 正文小 13px Regular
  static TextStyle get bodySmall => GoogleFonts.notoSansSc(
        fontSize: 13,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  /// 辅助文字 12px Regular
  static TextStyle get caption => GoogleFonts.notoSansSc(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  /// 标签/三级 11px Regular
  static TextStyle get label => GoogleFonts.notoSansSc(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
      );

  // ──────── 特殊 ────────
  /// 粉色背景上的文字 14px Regular 白色
  static TextStyle get onPink => GoogleFonts.notoSansSc(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textOnPink,
      );

  /// 状态栏时间 17px SemiBold
  static TextStyle get statusBarTime => GoogleFonts.inter(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  /// 日期数字 11px Medium（时间轴日期）
  static TextStyle get dateLabel => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.accentRose,
      );

  /// 大数字（纪念日天数）56px Bold
  static TextStyle get heroNumber => GoogleFonts.inter(
        fontSize: 56,
        fontWeight: FontWeight.w700,
        color: AppColors.textOnPink,
        height: 1.0,
      );

  /// 统计数字 20px Bold
  static TextStyle get statNumber => GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      );

  /// Tab 标签 10px
  static TextStyle get tabLabel => GoogleFonts.notoSansSc(
        fontSize: 10,
        fontWeight: FontWeight.w400,
      );
}
