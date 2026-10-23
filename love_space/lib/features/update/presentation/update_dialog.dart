import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../application/app_update_controller.dart';
import '../domain/app_release.dart';

Future<void> showAppUpdateDialog(
  BuildContext context,
  AppRelease release,
) {
  return showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AppUpdateDialog(initialRelease: release),
  );
}

class _AppUpdateDialog extends ConsumerWidget {
  const _AppUpdateDialog({required this.initialRelease});

  final AppRelease initialRelease;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appUpdateControllerProvider);
    final release = state.release ?? initialRelease;
    final isDownloading = state.status == AppUpdateStatus.downloading;
    final isInstalling = state.status == AppUpdateStatus.installing;
    final failed = state.status == AppUpdateStatus.failed;
    final busy = isDownloading || isInstalling;
    final controller = ref.read(appUpdateControllerProvider.notifier);

    return PopScope(
      canPop: !busy,
      child: AlertDialog(
        backgroundColor: AppColors.bgCard,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
        ),
        titlePadding: const EdgeInsets.fromLTRB(22, 22, 22, 0),
        contentPadding: const EdgeInsets.fromLTRB(22, 16, 22, 0),
        actionsPadding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
        title: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                color: AppColors.bgBlush,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.system_update_alt_rounded,
                color: AppColors.accentRose,
                size: 23,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('发现新版本', style: AppTextStyles.titleSmall),
                  const SizedBox(height: 3),
                  Text(
                    'v${release.versionName}',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.accentRose,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前版本 v${state.installedVersion ?? '—'}  ·  '
                  '安装包 ${_formatBytes(release.apkSize)}',
                  style: AppTextStyles.label,
                ),
                if (release.displayNotes.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  Text('更新内容', style: AppTextStyles.titleXs),
                  const SizedBox(height: 8),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.bgCream,
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                    child: SelectableText(
                      release.displayNotes,
                      style: AppTextStyles.caption.copyWith(height: 1.55),
                    ),
                  ),
                ],
                if (busy) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppColors.radiusXs),
                    child: LinearProgressIndicator(
                      value: isInstalling ? 1 : state.progress,
                      minHeight: 7,
                      color: AppColors.accentRose,
                      backgroundColor: AppColors.accentPinkSoft,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
                if (state.message != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    state.message!,
                    style: AppTextStyles.caption.copyWith(
                      color: failed
                          ? Theme.of(context).colorScheme.error
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
                if (!busy) ...[
                  const SizedBox(height: 10),
                  Text(
                    '下载完成后会打开系统安装页，首次使用可能需要允许「以越之名」安装未知来源应用。',
                    style: AppTextStyles.label.copyWith(height: 1.5),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          if (isDownloading)
            TextButton(
              onPressed: controller.cancelDownload,
              child: const Text('取消下载'),
            )
          else
            TextButton(
              onPressed: busy ? null : () => Navigator.of(context).pop(),
              child: const Text('稍后'),
            ),
          FilledButton.icon(
            onPressed: busy ? null : controller.downloadAndInstall,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: AppColors.textOnPink,
              shape: const StadiumBorder(),
            ),
            icon: isDownloading
                ? const SizedBox.square(
                    dimension: 15,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnPink,
                    ),
                  )
                : const Icon(Icons.download_rounded, size: 18),
            label: Text(
              isDownloading
                  ? '${(state.progress * 100).round()}%'
                  : isInstalling
                      ? '正在打开安装页'
                      : controller.hasDownloadedApk
                          ? '重试安装'
                          : failed
                              ? '重新下载'
                              : '下载并安装',
            ),
          ),
        ],
      ),
    );
  }
}

String _formatBytes(int bytes) {
  if (bytes <= 0) return '大小未知';
  final megabytes = bytes / (1024 * 1024);
  return '${megabytes.toStringAsFixed(megabytes >= 10 ? 1 : 2)} MB';
}
