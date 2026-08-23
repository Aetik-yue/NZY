import 'package:flutter/material.dart';
import '../../app/theme/app_colors.dart';

/// 显示删除确认对话框
///
/// 返回 true 表示确认删除，false 或 null 表示取消
Future<bool> showConfirmDeleteDialog(
  BuildContext context, {
  String? title,
  String? content,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.warning_amber_rounded,
          color: AppColors.accentRose, size: 32),
      title: Text(title ?? '确认删除'),
      content: Text(content ?? '确定要删除这条记录吗？此操作无法撤销。'),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.accentRose,
          ),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return result ?? false;
}
