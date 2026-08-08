import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/providers/data_providers.dart';
import '../../../shared/widgets/pill_nav_bar.dart';
import '../../memo/presentation/memo_page.dart';
import '../../music/presentation/music_player_page.dart';
import '../../music/providers/music_player_provider.dart';
import 'all_features_page.dart';
import 'settings_page.dart';

/// 我的页
/// 还原设计稿：渐变头部 → 统计行 → 音乐卡 → 功能卡（小说/备忘录/设置）
class ProfilePage extends ConsumerWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 4, 20, 100),
      child: Column(
        children: [
          _ProfileHeader(),
          SizedBox(height: 16),
          _StatsRow(),
          SizedBox(height: 16),
          _MusicCard(),
          SizedBox(height: 12),
          _FunctionCards(),
          SizedBox(height: 12),
          _AllFeaturesEntry(),
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
        // 隐私开关：隐藏在一起天数
        final hideDays = settings?.hideDaysTogether ?? false;
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.headerGradient,
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
                      child: _Avatar(AppColors.avatarGradients[0]),
                    ),
                    // 我的头像（右）
                    Positioned(
                      left: 56,
                      child: _Avatar(AppColors.avatarGradients[1]),
                    ),
                    // 中间心形
                    const Positioned(
                      left: 45,
                      top: 21,
                      child: Icon(Icons.favorite,
                          color: Colors.white, size: 24),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(names,
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.textOnPink,
                    fontSize: 20,
                  )),
              const SizedBox(height: 4),
              Text(hideDays ? '这是我们的空间 💕' : '在一起 $days 天 · 这是我们的空间',
                  style: AppTextStyles.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
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
    final memoCount = ref.watch(memoCountProvider);

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
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
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
                      Text(s.$1,
                          style:
                              AppTextStyles.statNumber.copyWith(color: s.$3)),
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
class _MusicCard extends ConsumerWidget {
  const _MusicCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 只读播放器状态；不 watch musicLibraryProvider，
    // 避免打开「我的」tab 触发权限请求与扫描
    final playerState = ref.watch(musicPlayerProvider);
    final count = playerState.playlist.length;
    final current = playerState.currentSong;
    final sub = count == 0
        ? '还没有音乐 · 点击播放'
        : (current != null
            ? '$count 首 · 正在播放「${current.title}」'
            : '$count 首 · 点击播放');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppColors.musicCardGradient,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
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
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
            child: const Icon(Icons.music_note,
                color: AppColors.textOnPink, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('我们的歌单', style: AppTextStyles.titleXs),
                const SizedBox(height: 4),
                Text(sub, style: AppTextStyles.label),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => MusicPlayerPage.show(context),
            child: Container(
              width: 40,
              height: 40,
              decoration: const BoxDecoration(
                color: AppColors.bgCard,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.play_arrow,
                  color: AppColors.accentRose, size: 20),
            ),
          ),
        ],
      ),
    );
  }
}

/// 功能卡行（小说 / 备忘录 / 设置）
class _FunctionCards extends ConsumerWidget {
  const _FunctionCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memoCount = ref.watch(memoCountProvider);
    final novelCount = ref.watch(novelsProvider).valueOrNull?.length ?? 0;
    final cards = [
      _FuncCard(
        icon: Icons.menu_book_rounded,
        title: '小说',
        sub: novelCount > 0 ? '共读 $novelCount 本' : '一起读书吧',
        bg: AppColors.accentPinkSoft,
        iconColor: AppColors.accentRose,
        // 小说已是底部 Tab，直接切换
        onTap: () => ref.read(currentTabProvider.notifier).state = NavTab.novel,
      ),
      _FuncCard(
        icon: Icons.sticky_note_2_rounded,
        title: '备忘录',
        sub: '$memoCount 条记录',
        bg: AppColors.accentPeach,
        iconColor: AppColors.accentCoral,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const MemoPage()),
        ),
      ),
      _FuncCard(
        icon: Icons.settings_rounded,
        title: '设置',
        sub: '纪念日 & 隐私',
        bg: AppColors.bgBlush,
        iconColor: AppColors.textTertiary,
        // 设置页：昵称 / 起始日期 / 隐私开关
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const SettingsPage()),
        ),
      ),
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

/// 全部功能入口行（三级入口：低频/长尾功能聚合）
class _AllFeaturesEntry extends StatelessWidget {
  const _AllFeaturesEntry();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const AllFeaturesPage()),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppColors.radiusCard),
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
            const Icon(Icons.apps_rounded, color: AppColors.accentRose, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Text('全部功能', style: AppTextStyles.titleXs),
            ),
            Text('更多双人小工具',
                style: AppTextStyles.label),
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right_rounded,
                size: 20, color: AppColors.textTertiary),
          ],
        ),
      ),
    );
  }
}

class _FuncCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String sub;
  final Color bg;
  final Color iconColor;
  final VoidCallback? onTap;

  const _FuncCard({
    required this.icon,
    required this.title,
    required this.sub,
    required this.bg,
    required this.iconColor,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppColors.radiusSheet),
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
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(height: 8),
            Text(title, style: AppTextStyles.titleSmall.copyWith(fontSize: 13)),
            const SizedBox(height: 2),
            Text(sub, style: AppTextStyles.label),
          ],
        ),
      ),
    );
  }
}
