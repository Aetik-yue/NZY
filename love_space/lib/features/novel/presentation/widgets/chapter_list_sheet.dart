import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/providers/data_providers.dart';

/// 章节目录底部面板
///
/// 列出当前小说的全部章节，高亮当前章，点击回调 onSelect 关闭并触发跳章。
class ChapterListSheet extends ConsumerStatefulWidget {
  final int novelId;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  const ChapterListSheet({
    super.key,
    required this.novelId,
    required this.currentIndex,
    required this.onSelect,
  });

  /// 弹出目录面板
  static Future<void> show(
    BuildContext context, {
    required int novelId,
    required int currentIndex,
    required ValueChanged<int> onSelect,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => ChapterListSheet(
        novelId: novelId,
        currentIndex: currentIndex,
        onSelect: onSelect,
      ),
    );
  }

  @override
  ConsumerState<ChapterListSheet> createState() => _ChapterListSheetState();
}

class _ChapterListSheetState extends ConsumerState<ChapterListSheet> {
  @override
  Widget build(BuildContext context) {
    final chaptersAsync = ref.watch(chaptersProvider(widget.novelId));

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('目录', style: AppTextStyles.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppColors.borderSoft),
            // 章节列表
            Expanded(
              child: chaptersAsync.when(
                data: (chapters) {
                  if (chapters.isEmpty) {
                    return const Center(child: Text('暂无章节'));
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                    itemCount: chapters.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (_, i) {
                      final chapter = chapters[i];
                      final isCurrent = chapter.chapterIndex == widget.currentIndex;
                      return ListTile(
                        onTap: () {
                          widget.onSelect(chapter.chapterIndex);
                          Navigator.of(context).pop();
                        },
                        leading: Icon(
                          isCurrent
                              ? Icons.menu_book_rounded
                              : Icons.circle_outlined,
                          size: 18,
                          color: isCurrent
                              ? AppColors.accentRose
                              : AppColors.textTertiary,
                        ),
                        title: Text(
                          chapter.title,
                          style: AppTextStyles.body.copyWith(
                            color: isCurrent
                                ? AppColors.accentRose
                                : AppColors.textPrimary,
                            fontWeight: isCurrent
                                ? FontWeight.w700
                                : FontWeight.w400,
                          ),
                        ),
                        tileColor: isCurrent
                            ? AppColors.accentPinkSoft.withOpacity(0.4)
                            : null,
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusSm),
                        ),
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const Center(child: Text('目录加载失败')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
