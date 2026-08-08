import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../core/utils/tag_utils.dart';
import '../../../../data/models/memo.dart';
import 'todo_fields.dart';

/// 备忘录卡片
///
/// 展示单条备忘录：勾选框（完成态切换）+ 优先级色点 + 作者标识 + 时间 +
/// 正文（标签高亮，完成时置灰加删除线）+ 截止日期标签（逾期高亮）。
/// 单击编辑，长按弹出菜单（置顶/编辑/删除）。
class MemoCard extends StatelessWidget {
  final Memo memo;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;
  final VoidCallback onToggleDone;

  const MemoCard({
    super.key,
    required this.memo,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: onTap,
        onLongPress: () => _showContextMenu(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Color(memo.colorValue).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
            border: Border.all(
              color: Color(memo.colorValue).withValues(alpha: 0.3),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 左侧：勾选框 + 优先级色点
              _Leading(memo: memo, onToggleDone: onToggleDone),
              const SizedBox(width: 10),
              // 右侧：头部 + 正文 + 截止日期
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(memo: memo),
                    const SizedBox(height: 8),
                    _HighlightText(content: memo.content, done: memo.done),
                    if (memo.dueDate != null) ...[
                      const SizedBox(height: 8),
                      DueDateLabel(dueDate: memo.dueDate!, done: memo.done),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 长按菜单
  void _showContextMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(
                memo.isPinned
                    ? Icons.push_pin_outlined
                    : Icons.push_pin_rounded,
                color: AppColors.accentRose,
              ),
              title: Text(memo.isPinned ? '取消置顶' : '置顶'),
              onTap: () {
                Navigator.of(context).pop();
                onTogglePin();
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_rounded,
                  color: AppColors.textSecondary),
              title: const Text('编辑'),
              onTap: () {
                Navigator.of(context).pop();
                onTap();
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: AppColors.accentRose),
              title: const Text('删除'),
              onTap: () {
                Navigator.of(context).pop();
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

/// 左侧勾选区：完成态切换图标 + 优先级色点
///
/// 嵌套 GestureDetector 仅注册 onTap，与外层卡片的 onTap/onLongPress 不冲突：
/// 点勾选框只触发切换，长按仍冒泡到外层菜单。
class _Leading extends StatelessWidget {
  final Memo memo;
  final VoidCallback onToggleDone;
  const _Leading({required this.memo, required this.onToggleDone});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        GestureDetector(
          onTap: onToggleDone,
          behavior: HitTestBehavior.opaque,
          child: Icon(
            memo.done
                ? Icons.check_circle
                : Icons.radio_button_unchecked,
            size: 22,
            color: memo.done ? AppColors.accentRose : AppColors.textTertiary,
          ),
        ),
        if (memo.priority != TodoPriority.none) ...[
          const SizedBox(height: 6),
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: priorityColor(memo.priority),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ],
    );
  }
}

/// 头部：作者圆点 + 姓名 + 时间 + 置顶图标 + 已编辑标记
class _Header extends StatelessWidget {
  final Memo memo;
  const _Header({required this.memo});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: memo.author == 1
                ? AppColors.accentRose
                : AppColors.accentPeach,
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Text(
              memo.author == 1 ? '越' : '名',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          memo.author == 1 ? '以越' : '之名',
          style: AppTextStyles.label.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(width: 8),
        Text(_relativeTime(memo.createdAt), style: AppTextStyles.label),
        const Spacer(),
        if (memo.isPinned)
          const Icon(Icons.push_pin_rounded,
              size: 14, color: AppColors.accentRose),
        if (memo.updatedAt != null) ...[
          const SizedBox(width: 4),
          Text('已编辑', style: AppTextStyles.label),
        ],
      ],
    );
  }

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${time.month}月${time.day}日';
  }
}

/// 高亮 #标签 的文本组件；done 时整体置灰加删除线
class _HighlightText extends StatelessWidget {
  final String content;
  final bool done;
  const _HighlightText({required this.content, required this.done});

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final regex = memoTagRegex; // 与筛选/提取共用同一正则
    var lastEnd = 0;
    // 完成时：正文与标签统一置灰（textTertiary）+ 删除线，作为已完成视觉降级
    final baseColor = done ? AppColors.textTertiary : AppColors.textPrimary;
    final tagColor = done ? AppColors.textTertiary : AppColors.accentRose;
    final decoration =
        done ? TextDecoration.lineThrough : TextDecoration.none;

    for (final match in regex.allMatches(content)) {
      // 标签前的普通文本（继承父级 color/decoration）
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      // 高亮的标签
      spans.add(TextSpan(
        text: match.group(0),
        style: TextStyle(
          color: tagColor,
          fontWeight: FontWeight.w600,
          decoration: decoration,
        ),
      ));
      lastEnd = match.end;
    }
    // 剩余文本
    if (lastEnd < content.length) {
      spans.add(TextSpan(text: content.substring(lastEnd)));
    }

    return RichText(
      text: TextSpan(
        style: AppTextStyles.body.copyWith(
          color: baseColor,
          decoration: decoration,
          decorationColor: baseColor,
        ),
        children: spans.isEmpty ? [TextSpan(text: content)] : spans,
      ),
    );
  }
}
