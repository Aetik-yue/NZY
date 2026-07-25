import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// 应用主题配置
class AppTheme {
  AppTheme._();

  /// 亮色主题（本项目默认且唯一主题）
  static ThemeData get light => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: AppColors.bgPrimary,
        fontFamily: AppTextStyles.cjkFontFamily,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.accentRose,
          brightness: Brightness.light,
          surface: AppColors.bgPrimary,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          scrolledUnderElevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarIconBrightness: Brightness.dark,
            statusBarBrightness: Brightness.light,
          ),
        ),
        cardTheme: const CardThemeData(
          color: AppColors.bgCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(AppColors.radiusCard)),
          ),
        ),
        dividerTheme: const DividerThemeData(
          color: AppColors.borderSoft,
          thickness: 1,
          space: 1,
        ),
      );
}
