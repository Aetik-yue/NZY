import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../app/theme/app_text_styles.dart';

/// 底部导航 Tab 定义
enum NavTab { home, album, wishes, profile }

extension NavTabX on NavTab {
  String get label {
    switch (this) {
      case NavTab.home: return '时光';
      case NavTab.album: return '相册';
      case NavTab.wishes: return '愿望';
      case NavTab.profile: return '我的';
    }
  }

  IconData get icon {
    switch (this) {
      case NavTab.home: return Icons.access_time_filled_rounded;
      case NavTab.album: return Icons.photo_library_rounded;
      case NavTab.wishes: return Icons.star_rounded;
      case NavTab.profile: return Icons.person_rounded;
    }
  }
}

/// 当前激活 Tab 状态
final currentTabProvider = StateProvider<NavTab>((ref) => NavTab.home);

/// 胶囊式底部导航栏
/// 还原设计稿：悬浮胶囊，36px 圆角，激活态粉色渐变
class PillNavBar extends ConsumerWidget {
  const PillNavBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentTabProvider);
    return Container(
      padding: const EdgeInsets.fromLTRB(21, 8, 21, 21),
      child: Container(
        height: 62,
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppColors.radiusTab),
          border: Border.all(color: AppColors.borderSoft),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowPink,
              blurRadius: 32,
              offset: Offset(0, 8),
              spreadRadius: -8,
            ),
          ],
        ),
        child: Row(
          children: NavTab.values
              .map((tab) => _NavItem(
                    tab: tab,
                    isActive: tab == current,
                    onTap: () => ref.read(currentTabProvider.notifier).state = tab,
                  ))
              .toList(),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final NavTab tab;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            gradient: isActive ? AppColors.pinkButtonGradient : null,
            borderRadius: BorderRadius.circular(AppColors.radiusPill),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                tab.icon,
                size: 20,
                color: isActive ? AppColors.textOnPink : AppColors.textTertiary,
              ),
              const SizedBox(height: 4),
              Text(
                tab.label,
                style: AppTextStyles.tabLabel.copyWith(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                  color: isActive ? AppColors.textOnPink : AppColors.textTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
