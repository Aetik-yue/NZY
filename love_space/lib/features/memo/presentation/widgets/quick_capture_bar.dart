import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/memo.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';

/// 顶部快速输入栏
///
/// 输入文字后按回车或点击发送按钮直接保存，无需手动保存。
/// 支持切换当前作者（1 或 2）。
class QuickCaptureBar extends ConsumerStatefulWidget {
  const QuickCaptureBar({super.key});

  @override
  ConsumerState<QuickCaptureBar> createState() => _QuickCaptureBarState();
}

class _QuickCaptureBarState extends ConsumerState<QuickCaptureBar> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  int _author = 1;

  /// 防重：提交进行中禁止再次提交（快速连按回车）
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
      final repo = ref.read(memoRepositoryProvider);
      await repo.add(Memo()
        ..content = content
        ..author = _author
        ..isPinned = false
        ..colorValue = _author == 1 ? 0xFFFF8FB1 : 0xFFFFD1BF
        ..createdAt = DateTime.now());

      if (!mounted) return;
      _controller.clear();
      // 保持焦点，方便连续输入
      _focusNode.requestFocus();
    } catch (e) {
      debugPrint('[QuickCaptureBar] 保存失败: $e');
      if (mounted) AppSnackbar.show(context, '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        border: Border.all(color: AppColors.borderSoft),
      ),
      child: Row(
        children: [
          // 作者头像（可点击切换）
          GestureDetector(
            onTap: () => setState(() => _author = _author == 1 ? 2 : 1),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: _author == 1 ? AppColors.accentRose : AppColors.accentPeach,
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  _author == 1 ? '越' : '名',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          // 输入框
          Expanded(
            child: TextField(
              controller: _controller,
              focusNode: _focusNode,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                hintText: '记录点什么...',
                hintStyle: AppTextStyles.body.copyWith(
                  color: AppColors.textTertiary,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
              style: AppTextStyles.body,
            ),
          ),
          // 发送按钮
          IconButton(
            icon: const Icon(Icons.send_rounded, size: 20),
            color: AppColors.accentRose,
            onPressed: _submit,
          ),
        ],
      ),
    );
  }
}
