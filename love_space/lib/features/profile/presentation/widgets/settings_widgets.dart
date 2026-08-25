import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// 设置页顶部说明卡。
class SettingsIntroCard extends StatelessWidget {
  const SettingsIntroCard({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppColors.heroGradient,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.favorite_outline_rounded,
                color: AppColors.accentRose),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('我们的空间，由你们定义',
                    style: AppTextStyles.titleSmall
                        .copyWith(color: AppColors.textOnPink)),
                const SizedBox(height: 4),
                Text('昵称、日期和主页显示都可以随时调整',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.textOnPink)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 带标题说明的设置分组卡。
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.children,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowCard, blurRadius: 16),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.bgBlush,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Icon(icon, color: AppColors.accentRose, size: 19),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleXs),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.label),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...children,
        ],
      ),
    );
  }
}

/// 设置页昵称输入框。
class SettingsNameField extends StatelessWidget {
  const SettingsNameField({
    super.key,
    required this.controller,
    required this.label,
    required this.hint,
  });

  final TextEditingController controller;
  final String label;
  final String hint;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: AppTextStyles.caption,
        hintStyle: AppTextStyles.body.copyWith(color: AppColors.textTertiary),
        filled: true,
        fillColor: AppColors.bgCream,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: const BorderSide(color: AppColors.accentRose),
        ),
      ),
      style: AppTextStyles.body,
    );
  }
}

/// 可点击的设置值行。
class SettingsValueRow extends StatelessWidget {
  const SettingsValueRow({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCream,
      borderRadius: BorderRadius.circular(AppColors.radiusSm),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon, size: 19, color: AppColors.accentRose),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.body),
                    const SizedBox(height: 2),
                    Text(subtitle, style: AppTextStyles.label),
                  ],
                ),
              ),
              Text(value,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.accentRose,
                    fontWeight: FontWeight.w600,
                  )),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

/// 主页合照设置行。
class SettingsCoverRow extends StatelessWidget {
  const SettingsCoverRow({
    super.key,
    required this.path,
    required this.onPick,
    required this.onReset,
  });

  final String? path;
  final VoidCallback onPick;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final hasPhoto = path != null && File(path!).existsSync();
    return Row(
      children: [
        Container(
          width: 52,
          height: 52,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            gradient: hasPhoto ? null : AppColors.headerGradient,
            borderRadius: BorderRadius.circular(AppColors.radiusSm),
          ),
          child: hasPhoto
              ? Image.file(
                  File(path!),
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.broken_image_outlined,
                    color: AppColors.textTertiary,
                  ),
                )
              : const Icon(Icons.photo_rounded, color: AppColors.textOnPink),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('主页合照背景', style: AppTextStyles.body),
              const SizedBox(height: 3),
              Text(hasPhoto ? '已选择合照' : '当前使用默认渐变', style: AppTextStyles.label),
            ],
          ),
        ),
        TextButton(onPressed: onPick, child: const Text('更换')),
        if (hasPhoto)
          IconButton(
            tooltip: '恢复默认背景',
            onPressed: onReset,
            icon: const Icon(Icons.restart_alt_rounded,
                color: AppColors.textTertiary),
          ),
      ],
    );
  }
}
