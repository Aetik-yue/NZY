import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/memo.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';

/// 一行完成待办录入：输入内容，按回车或点击加号保存。
class QuickCaptureBar extends ConsumerStatefulWidget {
  const QuickCaptureBar({super.key});

  @override
  ConsumerState<QuickCaptureBar> createState() => _QuickCaptureBarState();
}

class _QuickCaptureBarState extends ConsumerState<QuickCaptureBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  bool _submitting = false;

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _submitting) return;
    setState(() => _submitting = true);
    try {
      await ref.read(memoRepositoryProvider).add(Memo()
        ..content = content
        ..author = 1
        ..isPinned = false
        ..colorValue = AppColors.accentPink.toARGB32()
        ..createdAt = DateTime.now()
        ..done = false
        ..priority = TodoPriority.none);
      if (!mounted) return;
      _controller.clear();
      _focusNode.requestFocus();
      ref.read(memoDoneFilterProvider.notifier).state = TodoFilter.active;
    } catch (error) {
      debugPrint('[QuickCaptureBar] 保存失败: $error');
      if (mounted) AppSnackbar.show(context, '添加失败，请重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.borderSoft),
        boxShadow: const [
          BoxShadow(color: AppColors.shadowCard, blurRadius: 14),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.radio_button_unchecked_rounded,
              color: AppColors.accentPinkSoft, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              key: const Key('quick_todo_input'),
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '写下要做的事…',
                hintStyle:
                    AppTextStyles.body.copyWith(color: AppColors.textTertiary),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              style: AppTextStyles.body,
            ),
          ),
          IconButton.filled(
            key: const Key('quick_todo_add'),
            tooltip: '添加待办',
            onPressed: _submitting ? null : _submit,
            icon: _submitting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppColors.textOnPink,
                    ),
                  )
                : const Icon(Icons.add_rounded, size: 22),
            style: IconButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: AppColors.textOnPink,
            ),
          ),
        ],
      ),
    );
  }
}
