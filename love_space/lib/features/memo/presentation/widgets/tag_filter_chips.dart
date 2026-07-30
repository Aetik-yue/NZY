import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/providers/data_providers.dart';

/// 标签筛选横栏
///
/// 显示所有可用标签 + "全部"选项，点击切换筛选。
class TagFilterChips extends ConsumerWidget {
  const TagFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tags = ref.watch(allTagsProvider);
    final selected = ref.watch(memoTagFilterProvider);

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: tags.length + 1, // +1 for "全部"
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          if (index == 0) {
            // "全部" chip
            return _Chip(
              label: '全部',
              isSelected: selected == null,
              onTap: () => ref.read(memoTagFilterProvider.notifier).state = null,
            );
          }
          final tag = tags[index - 1];
          return _Chip(
            label: '#$tag',
            isSelected: selected == tag,
            onTap: () => ref.read(memoTagFilterProvider.notifier).state = tag,
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _Chip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accentRose : AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          border: isSelected
              ? null
              : Border.all(color: AppColors.borderSoft),
        ),
        child: Text(
          label,
          style: AppTextStyles.caption.copyWith(
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ),
    );
  }
}
