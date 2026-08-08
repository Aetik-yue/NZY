import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/app_colors.dart';
import '../../data/providers/data_providers.dart';
import '../../features/home/presentation/home_page.dart';
import '../../features/album/presentation/album_page.dart';
import '../../features/wishes/presentation/wishes_page.dart';
import '../../features/novel/presentation/novel_page.dart';
import '../../features/music/presentation/widgets/mini_player_bar.dart';
import '../../features/profile/presentation/profile_page.dart';
import '../widgets/pill_nav_bar.dart';

/// 主壳层：承载 4 个 Tab 页面 + 底部胶囊导航
/// 使用 IndexedStack 保持各页面状态
class MainShell extends ConsumerWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTab = ref.watch(currentTabProvider);
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      body: SafeArea(
        top: true,
        bottom: false,
        child: IndexedStack(
          index: currentTab.index,
          children: const [
            HomePage(),
            AlbumPage(),
            WishesPage(),
            NovelPage(),
            ProfilePage(),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          MiniPlayerBar(),
          PillNavBar(),
        ],
      ),
    );
  }
}
