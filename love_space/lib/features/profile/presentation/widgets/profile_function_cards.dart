import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../games/games_page.dart';
import '../../../memo/presentation/memo_page.dart';
import '../settings_page.dart';

/// 「小游戏 / 待办 / 设置」三个高频功能入口。
class ProfileFunctionCards extends ConsumerWidget {
  const ProfileFunctionCards({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoStats = ref.watch(memoStatsProvider);
    final active = memoStats.total - memoStats.done;
    final cards = <_FunctionCard>[
      _FunctionCard(
        icon: Icons.sports_esports_rounded,
        title: '小游戏',
        subtitle: '一起玩一局',
        background: AppColors.accentPinkSoft,
        iconColor: AppColors.accentRose,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const GamesPage()),
        ),
      ),
      _FunctionCard(
        icon: Icons.checklist_rounded,
        title: '待办',
        subtitle: active == 0 ? '都完成啦' : '$active 件待完成',
        background: AppColors.accentPeach,
        iconColor: AppColors.accentCoral,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MemoPage()),
        ),
      ),
      _FunctionCard(
        icon: Icons.tune_rounded,
        title: '设置',
        subtitle: '昵称 · 日期',
        background: AppColors.bgBlush,
        iconColor: AppColors.textSecondary,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        ),
      ),
    ];

    return Row(
      children: [
        for (int index = 0; index < cards.length; index++) ...[
          Expanded(child: cards[index]),
          if (index < cards.length - 1) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _FunctionCard extends StatelessWidget {
  const _FunctionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.background,
    required this.iconColor,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color background;
  final Color iconColor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.bgCard,
      borderRadius: BorderRadius.circular(AppColors.radiusSheet),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusSheet),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(AppColors.radiusSm),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: 10),
              Text(title, style: AppTextStyles.titleXs),
              const SizedBox(height: 3),
              Text(subtitle,
                  style: AppTextStyles.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ),
    );
  }
}
