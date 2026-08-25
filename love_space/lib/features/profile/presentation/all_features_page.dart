import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../anniversary/presentation/anniversary_page.dart';
import '../../couple_fun/presentation/daily_fortune_page.dart';
import '../../couple_fun/presentation/love_quiz_page.dart';
import '../../games/breakout/breakout_page.dart';
import '../../games/tetris/tetris_page.dart';
import '../../home/presentation/checkin_history_page.dart';
import '../../home/presentation/timeline_all_page.dart';
import '../../memo/presentation/memo_page.dart';
import '../../secrets/presentation/secrets_page.dart';
import '../../tools/random_number_page.dart';
import '../../tools/stopwatch_page.dart';
import 'settings_page.dart';

/// 全部功能页（三级入口：低频/长尾功能聚合）
///
/// 分组承载双人工具与互动娱乐；占位条目点击提示「即将上线」，
/// 新功能落地后只需把对应条目换成真实跳转。
class AllFeaturesPage extends ConsumerWidget {
  const AllFeaturesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final groups = [
      _FeatureGroup(
        title: '双人生活',
        items: [
          _FeatureEntry(
            icon: Icons.favorite_rounded,
            title: '纪念日',
            subtitle: '管理特别的日子与倒数',
            color: AppColors.accentRose,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AnniversaryPage()),
            ),
          ),
          _FeatureEntry(
            icon: Icons.sticky_note_2_rounded,
            title: '待办',
            subtitle: '记录要一起完成的事',
            color: AppColors.accentCoral,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MemoPage()),
            ),
          ),
          _FeatureEntry(
            icon: Icons.local_fire_department_rounded,
            title: '打卡记录',
            subtitle: '回看每天说爱你的瞬间',
            color: AppColors.accentRose,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const CheckinHistoryPage()),
            ),
          ),
          _FeatureEntry(
            icon: Icons.timeline_rounded,
            title: '时光记录',
            subtitle: '按年月回看我们的故事',
            color: AppColors.accentPeach,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TimelineAllPage()),
            ),
          ),
          _FeatureEntry(
            icon: Icons.forum_rounded,
            title: '悄悄话',
            subtitle: '只属于你们的私密留言',
            color: AppColors.accentMauve,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SecretsPage()),
            ),
          ),
        ],
      ),
      _FeatureGroup(
        title: '互动娱乐',
        items: [
          _FeatureEntry(
            icon: Icons.sports_baseball_rounded,
            title: '打砖块',
            subtitle: '经典 Breakout · 3 关挑战',
            color: AppColors.accentRose,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const BreakoutPage()),
            ),
          ),
          _FeatureEntry(
            icon: Icons.grid_view_rounded,
            title: '俄罗斯方块',
            subtitle: '经典 Tetris · SRS 旋转 + Hold',
            color: AppColors.accentTeal,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const TetrisPage()),
            ),
          ),
          _FeatureEntry(
            icon: Icons.quiz_rounded,
            title: '恋爱测试',
            subtitle: '轮流答题，交换彼此的偏好',
            color: AppColors.accentMauve,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoveQuizPage()),
            ),
          ),
          _FeatureEntry(
            icon: Icons.auto_awesome_rounded,
            title: '缘分签',
            subtitle: '每天一签，收下一件爱的行动',
            color: AppColors.accentCoral,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DailyFortunePage()),
            ),
          ),
        ],
      ),
      _FeatureGroup(
        title: '实用工具',
        items: [
          _FeatureEntry(
            icon: Icons.casino_rounded,
            title: '随机数',
            subtitle: '自定义范围生成随机数',
            color: AppColors.accentMauve,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RandomNumberPage()),
            ),
          ),
          _FeatureEntry(
            icon: Icons.timer_rounded,
            title: '计时器',
            subtitle: '正计时秒表 · 计圈',
            color: AppColors.accentCoral,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const StopwatchPage()),
            ),
          ),
        ],
      ),
      _FeatureGroup(
        title: '设置',
        items: [
          _FeatureEntry(
            icon: Icons.settings_rounded,
            title: '情侣设置',
            subtitle: '昵称 / 起始日期 / 隐私',
            color: AppColors.textTertiary,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('全部功能', style: AppTextStyles.titleMedium),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          for (final group in groups) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Text(group.title, style: AppTextStyles.titleSmall),
            ),
            Container(
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
              child: Column(
                children: [
                  for (var i = 0; i < group.items.length; i++) ...[
                    if (i > 0)
                      const Divider(
                          height: 1, indent: 60, color: AppColors.borderSoft),
                    _FeatureTile(entry: group.items[i]),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// 功能分组
class _FeatureGroup {
  final String title;
  final List<_FeatureEntry> items;
  const _FeatureGroup({required this.title, required this.items});
}

/// 功能条目（onTap 为 null 表示占位「即将上线」）
class _FeatureEntry {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _FeatureEntry({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    this.onTap,
  });
}

/// 功能条目行
class _FeatureTile extends StatelessWidget {
  final _FeatureEntry entry;

  const _FeatureTile({required this.entry});

  @override
  Widget build(BuildContext context) {
    final isPlaceholder = entry.onTap == null;
    return ListTile(
      onTap: entry.onTap ?? () => AppSnackbar.show(context, '即将上线 ✨'),
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: entry.color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
        child: Icon(entry.icon, color: entry.color, size: 20),
      ),
      title: Text(
        entry.title,
        style: AppTextStyles.body.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(entry.subtitle, style: AppTextStyles.label),
      trailing: isPlaceholder
          ? Text('即将上线',
              style:
                  AppTextStyles.label.copyWith(color: AppColors.textTertiary))
          : const Icon(Icons.chevron_right_rounded,
              size: 20, color: AppColors.textTertiary),
    );
  }
}
