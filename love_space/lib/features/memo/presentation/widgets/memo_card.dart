import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/memo.dart';

/// 备忘录卡片
///
/// 展示单条备忘录：作者标识 + 时间 + 正文（标签高亮）+ 置顶图标。
/// 单击编辑，长按弹出菜单（置顶/编辑/删除）。
class MemoCard extends StatelessWidget {
  final Memo memo;
  final VoidCallback onTap;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const MemoCard({
    super.key,
    required this.memo,
    required this.onTap,
    required this.onTogglePin,
    required this.onDelete,
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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 头部：作者 + 时间 + 置顶图标
              Row(
                children: [
                  // 作者圆点
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
                    style: AppTextStyles.label.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _relativeTime(memo.createdAt),
                    style: AppTextStyles.label,
                  ),
                  const Spacer(),
                  if (memo.isPinned)
                    const Icon(Icons.push_pin_rounded,
                        size: 14, color: AppColors.accentRose),
                  if (memo.updatedAt != null) ...[
                    const SizedBox(width: 4),
                    Text('已编辑', style: AppTextStyles.label),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              // 正文（标签高亮）
              _HighlightText(content: memo.content),
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

  String _relativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${time.month}月${time.day}日';
  }
}

/// 高亮 #标签 的文本组件
class _HighlightText extends StatelessWidget {
  final String content;
  const _HighlightText({required this.content});

  @override
  Widget build(BuildContext context) {
    final spans = <TextSpan>[];
    final regex = RegExp(r'#(\S+)');
    var lastEnd = 0;

    for (final match in regex.allMatches(content)) {
      // 标签前的普通文本
      if (match.start > lastEnd) {
        spans.add(TextSpan(text: content.substring(lastEnd, match.start)));
      }
      // 高亮的标签
      spans.add(TextSpan(
        text: match.group(0),
        style: const TextStyle(
          color: AppColors.accentRose,
          fontWeight: FontWeight.w600,
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
        style: AppTextStyles.body,
        children: spans.isEmpty ? [TextSpan(text: content)] : spans,
      ),
    );
  }
}
