import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/constants/seed_data.dart';
import '../../../../data/models/app_settings.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../shared/utils/image_picker_helper.dart';
import '../../../../shared/widgets/app_snackbar.dart';

enum _CoverAction { gallery, reset }

/// 可自定义合照背景的情侣头部卡片。
class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final days = ref.watch(daysTogetherProvider);
    return settingsAsync.when(
      data: (settings) => _HeaderCard(
        settings: settings,
        days: days,
        onEdit: () => _editCover(context, ref, settings),
      ),
      loading: () => const SizedBox(
        height: 220,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => const SizedBox(
        height: 220,
        child: Center(child: Text('情侣信息加载失败')),
      ),
    );
  }

  Future<void> _editCover(
    BuildContext context,
    WidgetRef ref,
    AppSettings? settings,
  ) async {
    final action = await showModalBottomSheet<_CoverAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppColors.radiusSheet),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderSoft,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.photo_library_rounded,
                    color: AppColors.accentRose),
                title: Text('从手机相册选择', style: AppTextStyles.body),
                subtitle: Text('选择一张你们喜欢的合照', style: AppTextStyles.caption),
                onTap: () =>
                    Navigator.of(sheetContext).pop(_CoverAction.gallery),
              ),
              if (settings?.profileCoverPath != null)
                ListTile(
                  leading: const Icon(Icons.restart_alt_rounded,
                      color: AppColors.textSecondary),
                  title: Text('恢复默认背景', style: AppTextStyles.body),
                  onTap: () =>
                      Navigator.of(sheetContext).pop(_CoverAction.reset),
                ),
            ],
          ),
        ),
      ),
    );
    if (action == null || !context.mounted) return;

    String? path;
    if (action == _CoverAction.gallery) {
      path = await ImagePickerHelper.pickFromGallery();
      if (path == null || !context.mounted) return;
    }

    try {
      final repository = ref.read(settingsRepositoryProvider);
      final current = await repository.get() ?? Seed.settings();
      current.profileCoverPath = path;
      await repository.save(current);
      if (!context.mounted) return;
      AppSnackbar.show(context, path == null ? '已恢复默认背景' : '合照背景已更新');
    } catch (error) {
      debugPrint('[ProfileHeader] 更新封面失败: $error');
      if (context.mounted) AppSnackbar.show(context, '背景更新失败，请重试');
    }
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({
    required this.settings,
    required this.days,
    required this.onEdit,
  });

  final AppSettings? settings;
  final int days;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final path = settings?.profileCoverPath;
    final hasPhoto = path != null && File(path).existsSync();
    final firstName = settings?.partner1Name ?? '小桃';
    final secondName = settings?.partner2Name ?? '阿树';
    final hideDays = settings?.hideDaysTogether ?? false;

    return Container(
      width: double.infinity,
      height: 226,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowPinkMedium,
            blurRadius: 24,
            offset: Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (hasPhoto)
            Image.file(
              File(path),
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const DecoratedBox(
                  decoration: BoxDecoration(
                gradient: AppColors.headerGradient,
              )),
            )
          else
            const DecoratedBox(
              decoration: BoxDecoration(gradient: AppColors.headerGradient),
            ),
          if (hasPhoto)
            const DecoratedBox(
              decoration:
                  BoxDecoration(gradient: AppColors.profileCoverOverlay),
            ),
          Positioned(
            top: 12,
            right: 12,
            child: Semantics(
              button: true,
              label: '更换情侣卡背景',
              child: IconButton.filledTonal(
                tooltip: '更换背景',
                onPressed: onEdit,
                icon: const Icon(Icons.photo_camera_rounded, size: 19),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.bgCard.withValues(alpha: 0.88),
                  foregroundColor: AppColors.accentRose,
                ),
              ),
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 26),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const _CoupleMark(),
                  const SizedBox(height: 14),
                  Text(
                    '$firstName & $secondName',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleLarge
                        .copyWith(color: AppColors.textOnPink),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    hideDays ? '这是我们的空间 💕' : '在一起 $days 天 · 这是我们的空间',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textOnPink.withValues(alpha: 0.9),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CoupleMark extends StatelessWidget {
  const _CoupleMark();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 124,
      height: 58,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(left: 4, child: _Avatar(AppColors.avatarGradients[0])),
          Positioned(right: 4, child: _Avatar(AppColors.avatarGradients[1])),
          const Icon(Icons.favorite_rounded,
              color: AppColors.textOnPink, size: 24),
        ],
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar(this.gradient);

  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: gradient,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.textOnPink, width: 3),
      ),
    );
  }
}
