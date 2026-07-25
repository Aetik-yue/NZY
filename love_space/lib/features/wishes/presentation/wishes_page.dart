import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../shared/widgets/section_header.dart';

/// 愿望清单页
/// 设计稿未绘制此页，此处提供与整体风格一致的骨架
class WishesPage extends ConsumerWidget {
  const WishesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 顶部
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('愿望清单', style: AppTextStyles.titleLarge),
                  const SizedBox(height: 2),
                  Text('一起完成 8 / 32 个愿望', style: AppTextStyles.label),
                ],
              ),
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  gradient: AppColors.pinkButtonGradient,
                  shape: BoxShape.circle,
                  boxShadow: const [
                    BoxShadow(
                      color: Color(0x59FF6B9D),
                      blurRadius: 16,
                      offset: Offset(0, 6),
                      spreadRadius: -2,
                    ),
                  ],
                ),
                child: const Icon(Icons.add, color: Colors.white, size: 22),
              ),
            ],
          ),
          const SizedBox(height: 20),
          // 进度卡片
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.headerGradient,
              borderRadius: BorderRadius.circular(24),
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
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('愿望完成进度', style: AppTextStyles.onPink.copyWith(fontSize: 13).copyWith(
                  color: Colors.white.withOpacity(0.9),
                )),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text('25%', style: AppTextStyles.heroNumber.copyWith(fontSize: 40)),
                    const SizedBox(width: 6),
                    Text('已完成', style: AppTextStyles.onPink.copyWith(fontSize: 14).copyWith(
                      color: Colors.white.withOpacity(0.85),
                    )),
                  ],
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: 0.25,
                    minHeight: 6,
                    backgroundColor: Colors.white.withOpacity(0.3),
                    valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          const SectionHeader(title: '待实现', actionText: '全部'),
          const SizedBox(height: 14),
          // 愿望列表
          const _WishItem(
            icon: Icons.flight_rounded,
            title: '一起去北海道看雪',
            desc: '冬天的时候，住进温泉旅馆',
          ),
          const SizedBox(height: 12),
          const _WishItem(
            icon: Icons.cake_rounded,
            title: '一起做一顿烛光晚餐',
            desc: '学一道对方最爱的菜',
          ),
          const SizedBox(height: 12),
          const _WishItem(
            icon: Icons.pets_rounded,
            title: '养一只小猫咪',
            desc: '给它起个可爱的名字',
          ),
        ],
      ),
    );
  }
}

class _WishItem extends StatelessWidget {
  final IconData icon;
  final String title;
  final String desc;

  const _WishItem({
    required this.icon,
    required this.title,
    required this.desc,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(20),
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.accentPinkSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.accentRose, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.titleSmall.copyWith(fontSize: 15)),
                const SizedBox(height: 3),
                Text(desc, style: AppTextStyles.caption),
              ],
            ),
          ),
          Icon(Icons.radio_button_unchecked, color: AppColors.textTertiary, size: 22),
        ],
      ),
    );
  }
}
