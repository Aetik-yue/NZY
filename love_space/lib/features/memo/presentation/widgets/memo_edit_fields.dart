import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

/// 作者选择器（仅新建时使用）：越 / 名 两个圆形按钮
class AuthorSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const AuthorSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('作者', style: AppTextStyles.label),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var author = 1; author <= 2; author++)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => onChanged(author),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: value == author
                          ? (author == 1
                              ? AppColors.accentRose
                              : AppColors.accentPeach)
                          : AppColors.bgCard,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: value == author
                            ? Colors.transparent
                            : AppColors.borderSoft,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        author == 1 ? '越' : '名',
                        style: AppTextStyles.body.copyWith(
                          color: value == author
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// 颜色选择器：暖粉系预设色板
class ColorSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  /// 存库需要 int 值（Color.value 已弃用，用 toARGB32 转换）
  static final presetColors = [
    AppColors.accentRose.toARGB32(), // 玫瑰粉
    AppColors.accentPink.toARGB32(), // 柔粉
    AppColors.accentPeach.toARGB32(), // 桃色
    AppColors.accentMauve.toARGB32(), // 锦葵紫
  ];

  const ColorSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('颜色', style: AppTextStyles.label),
        const SizedBox(height: 8),
        Row(
          children: [
            for (final color in presetColors)
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: GestureDetector(
                  onTap: () => onChanged(color),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Color(color),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: value == color
                            ? AppColors.textPrimary
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// 正文输入框（占满剩余高度，#标签 提示）
///
/// onChanged 触发外层重建以更新 PopScope.canPop（未保存拦截）。
class ContentTextField extends StatelessWidget {
  final TextEditingController controller;
  final bool autofocus;
  final VoidCallback onChanged;

  const ContentTextField({
    super.key,
    required this.controller,
    required this.autofocus,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: TextField(
        controller: controller,
        autofocus: autofocus,
        maxLines: null,
        expands: true,
        textAlignVertical: TextAlignVertical.top,
        onChanged: (_) => onChanged(),
        decoration: InputDecoration(
          hintText: '记录你的想法...#标签',
          hintStyle: AppTextStyles.body.copyWith(
            color: AppColors.textTertiary,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            borderSide: const BorderSide(color: AppColors.borderSoft),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            borderSide: const BorderSide(color: AppColors.borderSoft),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            borderSide: const BorderSide(color: AppColors.accentRose),
          ),
          contentPadding: const EdgeInsets.all(14),
          filled: true,
          fillColor: AppColors.bgCard,
        ),
        style: AppTextStyles.body,
      ),
    );
  }
}

/// 未保存修改离开确认对话框，返回 true 表示用户选择放弃
Future<bool> showDiscardChangesDialog(BuildContext context) async {
  final leave = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('放弃修改？'),
      content: const Text('当前内容尚未保存，确定要离开吗？'),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('继续编辑'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentRose,
          ),
          child: const Text('放弃'),
        ),
      ],
    ),
  );
  return leave == true;
}
