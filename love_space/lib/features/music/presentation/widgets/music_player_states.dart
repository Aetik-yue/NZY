import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// 空状态：设备音乐库中没有可播放歌曲。
class MusicEmptyState extends StatelessWidget {
  const MusicEmptyState({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _MusicStateCard(
      icon: Icons.music_off_rounded,
      title: '没有找到本地音乐',
      description: '请将音乐文件放入设备后重新扫描',
      actionLabel: onRetry == null ? null : '重新扫描',
      onAction: onRetry,
    );
  }
}

/// 权限被拒绝状态。
class MusicPermissionState extends StatelessWidget {
  const MusicPermissionState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _MusicStateCard(
      icon: Icons.lock_outline_rounded,
      title: '需要音乐权限',
      description: '授权后才能扫描设备中的音乐文件',
      actionLabel: '重新授权',
      onAction: onRetry,
    );
  }
}

/// 音乐库加载异常状态。
class MusicLoadErrorState extends StatelessWidget {
  const MusicLoadErrorState({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return _MusicStateCard(
      icon: Icons.sync_problem_rounded,
      title: '音乐库加载失败',
      description: '请检查音乐文件后重试',
      actionLabel: '重新加载',
      onAction: onRetry,
    );
  }
}

class _MusicStateCard extends StatelessWidget {
  const _MusicStateCard({
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(AppColors.spacingXl),
      child: Container(
        padding: const EdgeInsets.all(AppColors.spacing2xl),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowCard,
              blurRadius: 20,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                color: AppColors.bgBlush,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: AppColors.accentRose),
            ),
            const SizedBox(height: AppColors.spacingMd),
            Text(title, style: AppTextStyles.titleMedium),
            const SizedBox(height: AppColors.spacingXs),
            Text(
              description,
              style: AppTextStyles.bodySmall,
              textAlign: TextAlign.center,
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: AppColors.spacingXl),
              FilledButton(
                onPressed: onAction,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.accentRose,
                  foregroundColor: AppColors.textOnPink,
                  minimumSize: const Size(120, 48),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
