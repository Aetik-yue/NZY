import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/sync/sync_providers.dart';
import '../all_features_page.dart';
import '../sync_pairing_page.dart';

/// 双人同步状态入口。
class ProfileSyncEntry extends ConsumerWidget {
  const ProfileSyncEntry({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(syncStatusProvider).valueOrNull;
    final isPaired = status?.isPaired ?? false;
    final isConfigured = status?.isConfigured ?? false;
    final subtitle = !isConfigured
        ? '未启用 · 配置后可异地共享'
        : isPaired
            ? '房间 ${status?.roomCode ?? ''} · 正在自动同步'
            : '创建房间或输入情侣码';

    return _EntryCard(
      icon: isPaired ? Icons.favorite_rounded : Icons.sync_rounded,
      iconColor: isPaired ? AppColors.textOnPink : AppColors.accentRose,
      iconBackground:
          isPaired ? AppColors.accentRose : AppColors.accentPinkSoft,
      title: '双人同步',
      subtitle: subtitle,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const SyncPairingPage()),
      ),
    );
  }
}

/// 低频功能总入口。
class ProfileAllFeaturesEntry extends StatelessWidget {
  const ProfileAllFeaturesEntry({super.key});

  @override
  Widget build(BuildContext context) {
    return _EntryCard(
      icon: Icons.apps_rounded,
      iconColor: AppColors.accentRose,
      iconBackground: AppColors.bgBlush,
      title: '全部功能',
      subtitle: '更多双人小工具',
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AllFeaturesPage()),
      ),
    );
  }
}

class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.icon,
    required this.iconColor,
    required this.iconBackground,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBackground;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(AppColors.radiusCard),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBackground,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleXs),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        style: AppTextStyles.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  size: 20, color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
