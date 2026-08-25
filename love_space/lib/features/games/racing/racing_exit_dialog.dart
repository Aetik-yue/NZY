import 'package:flutter/material.dart';

import '../../../app/theme/app_text_styles.dart';

/// 确认是否放弃当前公路闪避对局。
Future<bool> showRacingExitDialog(BuildContext context) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text('结束本局？', style: AppTextStyles.titleMedium),
      content: Text('本局里程不会保存为历史纪录。', style: AppTextStyles.body),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('继续游戏'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('结束本局'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
