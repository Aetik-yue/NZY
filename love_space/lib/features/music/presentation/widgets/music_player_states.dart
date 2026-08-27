import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// 空状态：设备音乐库中没有符合命名规则的专属录音。
class MusicEmptyState extends StatelessWidget {
  const MusicEmptyState({super.key, this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return _MusicStateCard(
      icon: Icons.music_off_rounded,
      title: '还没有找到我们的歌',
      description: '请将录音文件名改为以 yyzm 开头，\n'
          '例如 yyzm_小幸运.m4a，\n'
          '然后重新打开音乐页面。',
      actionLabel: onRetry == null ? null : '重新识别',
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
      title: '需要音乐和音频权限',
      description: '授权后，App 才能自动识别以 yyzm 开头的专属录音。\n'
          '其他歌曲不会加入“我们的歌”。',
      actionLabel: '允许访问',
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
      title: '识别歌曲失败，请重试',
      description: '暂时无法读取专属录音，请稍后再试',
      actionLabel: '重新识别',
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
