import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/providers/data_providers.dart';

/// 我的页
/// 还原设计稿：渐变头部 → 统计行 → 音乐卡 → 功能卡（小说/备忘录/设置）
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      child: Column(
        children: const [
          _ProfileHeader(),
          SizedBox(height: 16),
          _StatsRow(),
          SizedBox(height: 16),
          _MusicCard(),
          SizedBox(height: 12),
          _FunctionCards(),
        ],
      ),
    );
  }
}

/// 渐变粉头部（情侣头像 + 名称）
class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsAsync = ref.watch(appSettingsProvider);
    final days = ref.watch(daysTogetherProvider);
    return settingsAsync.when(
      data: (settings) {
        final names = settings != null
            ? '${settings.partner1Name} & ${settings.partner2Name}'
            : '小桃 & 阿树';
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33FF6B8F),
                blurRadius: 24,
                offset: Offset(0, 8),
                spreadRadius: -4,
              ),
            ],
          ),
          child: Column(
            children: [
              // 情侣头像 + 心形
              SizedBox(
                width: 130,
                height: 64,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 女友头像（左）
                    Positioned(
                      left: 0,
                      child: _Avatar(const LinearGradient(
                        colors: [Color(0xFFFFB5CC), Color(0xFFFF8FB1)],
                      )),
                    ),
                    // 我的头像（右）
                    Positioned(
                      left: 56,
                      child: _Avatar(const LinearGradient(
                        colors: [Color(0xFFFFD1BF), Color(0xFFFFA1A1)],
                      )),
                    ),
                    // 中间心形
                    Positioned(
                      left: 45,
                      top: 21,
                      child: Icon(Icons.favorite, color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(names, style: AppTextStyles.titleLarge.copyWith(
                color: AppColors.textOnPink, fontSize: 20,
              )),
              const SizedBox(height: 4),
              Text('在一起 $days 天 · 这是我们的空间',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white.withOpacity(0.85),
                )),
            ],
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Text('加载失败'),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final Gradient gradient;
  const _Avatar(this.gradient);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        gradient: gradient,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 3),
      ),
    );
  }
}

/// 统计行（相伴天数 / 相册 / 愿望 / 备忘录）
class _StatsRow extends ConsumerWidget {
  const _StatsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final days = ref.watch(daysTogetherProvider);
    final photoCount = ref.watch(photoCountProvider);
    final wishStats = ref.watch(wishStatsProvider);
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final memoCount = settings?.memoCount ?? 0;

    final stats = [
      ('$days', '相伴天数', AppColors.textPrimary),
      ('$photoCount', '相册照片', AppColors.accentRose),
      ('${wishStats.total}', '愿望', AppColors.accentRose),
      ('$memoCount', '备忘录', AppColors.accentRose),
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 16,
            offset: Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: stats
            .map((s) => Expanded(
                  child: Column(
                    children: [
                      Text(s.$1, style: AppTextStyles.statNumber.copyWith(color: s.$3)),
                      const SizedBox(height: 4),
                      Text(s.$2, style: AppTextStyles.label),
                    ],
                  ),
                ))
            .toList(),
      ),
    );
  }
}

/// 音乐迷你播放卡
class _MusicCard extends StatelessWidget {
  const _MusicCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFD4E0), Color(0xFFFFA1C6)],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 16,
            offset: Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AppColors.pinkButtonGradient,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.music_note, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('我们的歌单', style: AppTextStyles.titleSmall.copyWith(fontSize: 14)),
                const SizedBox(height: 4),
                Text('32 首 · 正在播放"小幸运"', style: AppTextStyles.label),
              ],
            ),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.play_arrow, color: AppColors.accentRose, size: 20),
          ),
        ],
      ),
    );
  }
}

/// 功能卡行（小说 / 备忘录 / 设置）
class _FunctionCards extends StatelessWidget {
  const _FunctionCards();

  @override
  Widget build(BuildContext context) {
    final cards = [
      _FuncCard(icon: Icons.menu_book_rounded, title: '小说', sub: '共读 12 本', bg: AppColors.accentPinkSoft, iconColor: AppColors.accentRose),
      _FuncCard(icon: Icons.sticky_note_2_rounded, title: '备忘录', sub: '86 条记录', bg: AppColors.accentPeach, iconColor: AppColors.accentCoral),
      _FuncCard(icon: Icons.settings_rounded, title: '设置', sub: '纪念日 & 隐私', bg: AppColors.bgBlush, iconColor: AppColors.textTertiary),
    ];
    return Row(
      children: cards
          .map((c) => Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: c == cards.last ? 0 : 12),
                  child: c,
                ),
              ))
          .toList(),
    );
  }
}

class _FuncCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final Color bg;
  final Color iconColor;

  const _FuncCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.bg,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 14,
            offset: Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(height: 8),
          Text(title, style: AppTextStyles.titleSmall.copyWith(fontSize: 13)),
          const SizedBox(height: 2),
          Text(sub, style: AppTextStyles.label),
        ],
      ),
    );
  }
}
