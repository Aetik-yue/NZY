import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/providers/data_providers.dart';

/// 作者筛选胶囊（全部 / 越 / 名）
///
/// 点击切换 memoAuthorFilterProvider，与 TodoFilterChips 共用胶囊样式。
class AuthorFilterChips extends ConsumerWidget {
  const AuthorFilterChips({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(memoAuthorFilterProvider);
    final options = <(int?, String)>[
      (null, '全部'),
      (1, '越'),
      (2, '名'),
    ];
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          for (final (value, label) in options)
            GestureDetector(
              onTap: () =>
                  ref.read(memoAuthorFilterProvider.notifier).state = value,
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
