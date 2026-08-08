import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/providers/data_providers.dart';

/// 待办状态筛选横栏（全部 / 待办 / 已完成）
///
/// 复用作者筛选的胶囊 chip 样式，点击切换 memoDoneFilterProvider。
class TodoFilterChips extends ConsumerWidget {
  const TodoFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(memoDoneFilterProvider);
    final options = <(TodoFilter, String)>[
      (TodoFilter.all, '全部'),
      (TodoFilter.active, '待办'),
      (TodoFilter.done, '已完成'),
    ];
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          for (final (value, label) in options)
            GestureDetector(
              onTap: () =>
                  ref.read(memoDoneFilterProvider.notifier).state = value,
              behavior: HitTestBehavior.opaque,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == value
                      ? AppColors.accentRose
                      : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  border: selected == value
                      ? null
                      : Border.all(color: AppColors.borderSoft),
                ),
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: selected == value
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontWeight:
                        selected == value ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
