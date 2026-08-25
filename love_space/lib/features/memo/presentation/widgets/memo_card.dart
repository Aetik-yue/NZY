import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/tag_utils.dart';
import '../../../../data/models/memo.dart';
import 'todo_fields.dart';

/// 简洁待办卡：完成状态、正文和必要元数据始终可见，其余操作收进菜单。
class MemoCard extends StatelessWidget {
  const MemoCard({
    super.key,
    required this.memo,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
    required this.onToggleDone,
  });

  final Memo memo;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final VoidCallback onToggleDone;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: InkWell(
          onTap: onTap,
          onLongPress: () => _showMenu(context),
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 6, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconButton(
                  tooltip: memo.done ? '恢复为待完成' : '标记为已完成',
                  onPressed: onToggleDone,
                  icon: Icon(
                    memo.done
                        ? Icons.check_circle_rounded
                        : Icons.radio_button_unchecked_rounded,
                    color: memo.done
                        ? AppColors.accentRose
                        : AppColors.textTertiary,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: _TodoText(
                                  content: memo.content, done: memo.done),
                            ),
                            if (memo.isPinned)
                              const Padding(
                                padding: EdgeInsets.only(left: 6),
                                child: Icon(Icons.push_pin_rounded,
                                    size: 14, color: AppColors.accentRose),
                              ),
                          ],
                        ),
                        if (_hasMetadata) ...[
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 10,
                            runSpacing: 6,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              if (memo.dueDate != null)
                                DueDateLabel(
                                    dueDate: memo.dueDate!, done: memo.done),
                              if (memo.priority != TodoPriority.none)
                                _PriorityLabel(priority: memo.priority),
                              _AuthorLabel(author: memo.author),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                IconButton(
                  tooltip: '更多操作',
                  onPressed: () => _showMenu(context),
                  icon: const Icon(Icons.more_horiz_rounded,
                      color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  bool get _hasMetadata =>
      memo.dueDate != null ||
      memo.priority != TodoPriority.none ||
      memo.author == 2;

  void _showMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppColors.radiusSheet),
        ),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_rounded,
                  color: AppColors.textSecondary),
              title: Text('编辑详情', style: AppTextStyles.body),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onTap();
              },
            ),
            ListTile(
              leading: Icon(
                memo.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                color: AppColors.accentRose,
              ),
              title: Text(memo.isPinned ? '取消置顶' : '置顶',
                  style: AppTextStyles.body),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onTogglePin();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded,
                  color: AppColors.accentRose),
              title: Text('删除', style: AppTextStyles.body),
              onTap: () {
                Navigator.of(sheetContext).pop();
                onDelete();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}

class _TodoText extends StatelessWidget {
  const _TodoText({required this.content, required this.done});

  final String content;
  final bool done;

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    int lastEnd = 0;
    for (final match in memoTagRegex.allMatches(content)) {
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          color: done ? AppColors.textTertiary : AppColors.accentRose,
          fontWeight: FontWeight.w600,
        ),
      ));
      lastEnd = match.end;
    }
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }
    final color = done ? AppColors.textTertiary : AppColors.textPrimary;
    return RichText(
      text: TextSpan(
        style: AppTextStyles.body.copyWith(
          color: color,
          decoration: done ? TextDecoration.lineThrough : TextDecoration.none,
          decorationColor: color,
        ),
        children: spans.isEmpty ? [TextSpan(text: content)] : spans,
      ),
    );
  }
}

class _PriorityLabel extends StatelessWidget {
  const _PriorityLabel({required this.priority});

  final TodoPriority priority;

  @override
  Widget build(BuildContext context) {
    final label = switch (priority) {
      TodoPriority.high => '高优先级',
      TodoPriority.medium => '中优先级',
      TodoPriority.low => '低优先级',
      TodoPriority.none => '',
    };
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 7,
          height: 7,
          decoration: BoxDecoration(
            color: priorityColor(priority),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 4),
        Text(label, style: AppTextStyles.label),
      ],
    );
  }
}

class _AuthorLabel extends StatelessWidget {
  const _AuthorLabel({required this.author});

  final int author;

  @override
  Widget build(BuildContext context) {
    return Text(author == 1 ? '越添加' : '名添加', style: AppTextStyles.label);
  }
}
