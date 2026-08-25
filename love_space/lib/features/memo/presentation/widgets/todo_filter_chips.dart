import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/providers/data_providers.dart';

/// 待完成/已完成双状态切换；隐藏“全部”以减少同屏信息噪音。
class TodoFilterChips extends ConsumerWidget {
  const TodoFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(memoDoneFilterProvider);
    final stats = ref.watch(memoStatsProvider);
    final active = stats.total - stats.done;
    final options = <(TodoFilter, String, int)>[
      (TodoFilter.active, '待完成', active),
      (TodoFilter.done, '已完成', stats.done),
    ];

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.bgBlush,
        borderRadius: BorderRadius.circular(AppColors.radiusPill),
      ),
      child: Row(
        children: [
          for (final (value, label, count) in options)
            Expanded(
              child: GestureDetector(
                onTap: () =>
                    ref.read(memoDoneFilterProvider.notifier).state = value,
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  decoration: BoxDecoration(
                    color: selected == value
                        ? AppColors.bgCard
                        : AppColors.bgBlush,
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    boxShadow: selected == value
                        ? const [
                            BoxShadow(
                              color: AppColors.shadowCard,
                              blurRadius: 10,
                            ),
                          ]
                        : null,
                  ),
                  child: Text(
                    '$label $count',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: selected == value
                          ? AppColors.accentRose
                          : AppColors.textSecondary,
                      fontWeight:
                          selected == value ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
