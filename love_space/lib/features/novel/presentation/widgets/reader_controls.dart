import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// 阅读器顶部工具栏（返回 / 章节标题 / 目录）
class ReaderTopBar extends StatelessWidget {
  final int theme;
  final String title;
  final VoidCallback onBack;
  final VoidCallback onOpenChapterList;

  const ReaderTopBar({
    super.key,
    required this.theme,
    required this.title,
    required this.onBack,
    required this.onOpenChapterList,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.readerTextOn(theme);
    final paddingTop = MediaQuery.of(context).padding.top;
    return Container(
      padding: EdgeInsets.only(
        top: paddingTop + 8,
        bottom: 8,
        left: 8,
        right: 8,
      ),
      color: AppColors.readerBg(theme).withValues(alpha: 0.95),
      child: Row(
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_rounded, color: textColor),
            onPressed: onBack,
          ),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.body.copyWith(color: textColor),
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            icon: Icon(Icons.format_list_bulleted_rounded,
                color: textColor),
            onPressed: onOpenChapterList,
          ),
        ],
      ),
    );
  }
}

/// 阅读器底部工具栏（上一章 / 进度 / 设置 / 下一章）
class ReaderBottomBar extends StatelessWidget {
  final int theme;
  final String progressLabel;
  final VoidCallback? onPrev;
  final VoidCallback onSettings;
  final VoidCallback? onNext;

  const ReaderBottomBar({
    super.key,
    required this.theme,
    required this.progressLabel,
    required this.onPrev,
    required this.onSettings,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = AppColors.readerTextOn(theme);
    final paddingBottom = MediaQuery.of(context).padding.bottom;
    return Container(
      padding: EdgeInsets.only(
        bottom: paddingBottom + 8,
        top: 8,
        left: 12,
        right: 12,
      ),
      color: AppColors.readerBg(theme).withValues(alpha: 0.95),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          ReaderBarButton(
            icon: Icons.chevron_left_rounded,
            label: '上一章',
            color: textColor,
            onTap: onPrev,
          ),
          Text(
            progressLabel,
            style: AppTextStyles.label.copyWith(color: textColor),
          ),
          Row(
            children: [
              ReaderBarButton(
                icon: Icons.settings_rounded,
                label: '设置',
                color: textColor,
                onTap: onSettings,
              ),
              const SizedBox(width: 4),
              ReaderBarButton(
                icon: Icons.chevron_right_rounded,
                label: '下一章',
                color: textColor,
                onTap: onNext,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 阅读器工具栏小按钮（图标 + 文字，不可用时半透明）
class ReaderBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  const ReaderBarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    final effectiveColor =
        active ? color : color.withValues(alpha: 0.4);
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Row(
          children: [
            Icon(icon, color: effectiveColor, size: 18),
            const SizedBox(width: 2),
            Text(
              label,
              style: AppTextStyles.label.copyWith(color: effectiveColor),
            ),
          ],
        ),
      ),
    );
  }
}
