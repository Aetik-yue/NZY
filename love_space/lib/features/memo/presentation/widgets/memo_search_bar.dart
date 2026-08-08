import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/providers/data_providers.dart';

/// 搜索栏
///
/// 实时过滤待办（按 content 模糊匹配）。
class MemoSearchBar extends ConsumerStatefulWidget {
  const MemoSearchBar({super.key});

  @override
  ConsumerState<MemoSearchBar> createState() => _MemoSearchBarState();
}

class _MemoSearchBarState extends ConsumerState<MemoSearchBar> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // watch 搜索词以驱动清除按钮的显隐（文本变化时 provider 会通知重建）
    final query = ref.watch(memoSearchProvider);
    // 输入框内容与 provider 状态同步（如通过 provider 清除时）
    if (query != _controller.text) {
      _controller.text = query;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppColors.radiusSm),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded,
              size: 18, color: AppColors.textTertiary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: _controller,
              decoration: InputDecoration(
                hintText: '搜索待办...',
                hintStyle: AppTextStyles.body.copyWith(
                  color: AppColors.textTertiary,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                isDense: true,
              ),
              style: AppTextStyles.body,
              onChanged: (v) =>
                  ref.read(memoSearchProvider.notifier).state = v,
            ),
          ),
          if (query.isNotEmpty)
            IconButton(
              icon: const Icon(Icons.close_rounded,
                  size: 18, color: AppColors.textTertiary),
              onPressed: () {
                _controller.clear();
                ref.read(memoSearchProvider.notifier).state = '';
              },
            ),
        ],
      ),
    );
  }
}
