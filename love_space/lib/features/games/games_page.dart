import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';
import 'breakout/breakout_page.dart';
import 'racing/racing_page.dart';
import 'tetris/tetris_page.dart';

/// 小游戏中心：集中承载可以随时开始的双人休闲游戏。
class GamesPage extends StatelessWidget {
  const GamesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('小游戏', style: AppTextStyles.titleMedium),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: AppColors.heroGradient,
              borderRadius: BorderRadius.circular(AppColors.radiusCard),
              boxShadow: const [
                BoxShadow(color: AppColors.shadowPinkHero, blurRadius: 24),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 64,
                  height: 64,
                  decoration: const BoxDecoration(
                    color: AppColors.bgCard,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.sports_esports_rounded,
                      color: AppColors.accentRose, size: 32),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('今晚玩一局？',
                          style: AppTextStyles.titleLarge
                              .copyWith(color: AppColors.textOnPink)),
                      const SizedBox(height: 6),
                      Text('轻松开局，随时暂停',
                          style: AppTextStyles.onPink
                              .copyWith(color: AppColors.textOnPink)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text('选择游戏', style: AppTextStyles.titleMedium),
          const SizedBox(height: 12),
          _GameCard(
            icon: Icons.sports_baseball_rounded,
            title: '打砖块',
            subtitle: '经典 Breakout · 3 关挑战',
            accent: AppColors.accentRose,
            background: AppColors.bgBlush,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BreakoutPage()),
            ),
          ),
          const SizedBox(height: 12),
          _GameCard(
            icon: Icons.grid_view_rounded,
            title: '俄罗斯方块',
            subtitle: 'SRS 旋转 · Hold · 连续消行',
            accent: AppColors.accentTeal,
            background: AppColors.bgCream,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TetrisPage()),
            ),
          ),
          const SizedBox(height: 12),
          _GameCard(
            icon: Icons.directions_car_filled_rounded,
            title: '公路闪避',
            subtitle: '拖动赛车 · 挑战最长距离',
            accent: AppColors.racingPlayerCar,
            background: AppColors.racingGrass,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RacingPage()),
            ),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  const _GameCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.accent,
    required this.background,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color accent;
  final Color background;
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
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: background,
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                child: Icon(icon, color: accent, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleSmall),
                    const SizedBox(height: 4),
                    Text(subtitle, style: AppTextStyles.caption),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary),
            ],
          ),
        ),
      ),
    );
  }
}
