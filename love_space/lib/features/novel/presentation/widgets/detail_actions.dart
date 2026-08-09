import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/novel.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../data/repositories/crawl_repository.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import '../novel_reader_page.dart';
import 'chapter_list_sheet.dart';
import 'crawl_progress_sheet.dart';

/// 小说详情页操作按钮：开始/继续阅读 + 目录 + 更新章节 + 删除
class DetailActions extends ConsumerWidget {
  final Novel novel;
  final int resumeIndex;
  final VoidCallback onDeleted;

  const DetailActions({
    super.key,
    required this.novel,
    required this.resumeIndex,
    required this.onDeleted,
  });

  Future<void> _updateChapters(BuildContext context, WidgetRef ref) async {
    ref.read(crawlStatusProvider.notifier).state = const CrawlStatus(
      state: 'fetching',
      message: '准备更新...',
    );
    CrawlProgressSheet.show(context, title: '正在更新《${novel.title}》');
    try {
      void onProgress(String message, int current, int total) {
        if (!context.mounted) return;
        ref.read(crawlStatusProvider.notifier).state = CrawlStatus(
          state: 'fetching',
          message: message,
          current: current,
          total: total,
        );
      }
      final newCount = await ref
          .read(crawlRepositoryProvider)
          .updateNovel(novel.id, onProgress: onProgress);
      if (!context.mounted) return;
      ref.read(crawlStatusProvider.notifier).state =
          const CrawlStatus(state: 'success', message: '完成');
      if (newCount == 0) {
        AppSnackbar.show(context, '暂无新章节');
      } else {
        AppSnackbar.show(context, '新增 $newCount 章');
      }
    } on CancelledException {
      // 用户主动取消，不显示错误
    } catch (e) {
      if (!context.mounted) return;
      ref.read(crawlStatusProvider.notifier).state = CrawlStatus(
        state: 'failed',
        message: '更新失败：$e',
      );
      AppSnackbar.show(context, '更新失败，请稍后重试');
    }
  }

  String _formatCrawlTime(DateTime time) {
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inHours < 1) return '${diff.inMinutes} 分钟前';
    if (diff.inDays < 1) return '${diff.inHours} 小时前';
    if (diff.inDays < 7) return '${diff.inDays} 天前';
    return '${time.month}月${time.day}日 ${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: double.infinity,
          height: 50,
          child: FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NovelReaderPage(
                  novelId: novel.id,
                  initialChapterIndex: resumeIndex,
                ),
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
            ),
            child: Text(
              novel.lastChapterIndex < 0 ? '开始阅读' : '继续阅读',
              style: AppTextStyles.onPink.copyWith(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () => ChapterListSheet.show(
              context,
              novelId: novel.id,
              currentIndex: resumeIndex,
              onSelect: (index) {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => NovelReaderPage(
                      novelId: novel.id,
                      initialChapterIndex: index,
                    ),
                  ),
                );
              },
            ),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.accentRose),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
            ),
            child: Text('目录',
                style: AppTextStyles.body.copyWith(color: AppColors.accentRose)),
          ),
        ),
        const SizedBox(height: 12),
        if (novel.sourceUrl != null && novel.sourceKey != null) ...[
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              onPressed: novel.crawlStatus == 'crawling'
                  ? null
                  : () => _updateChapters(context, ref),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('更新章节'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.accentRose),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
                foregroundColor: AppColors.accentRose,
              ),
            ),
          ),
          if (novel.lastCrawlAt != null) ...[
            const SizedBox(height: 6),
            Text('最后更新时间：${_formatCrawlTime(novel.lastCrawlAt!)}',
                style: AppTextStyles.label),
          ],
          const SizedBox(height: 12),
        ],
        SizedBox(
          width: double.infinity,
          height: 48,
          child: OutlinedButton(
            onPressed: () async {
              final confirmed = await showConfirmDeleteDialog(
                context,
                title: '删除小说',
                content: '确定要删除《${novel.title}》吗？所有章节也会被一并删除，此操作无法撤销。',
              );
              if (!confirmed || !context.mounted) return;
              try {
                await ref
                    .read(novelChapterRepositoryProvider)
                    .deleteByNovel(novel.id);
                await ref.read(novelRepositoryProvider).delete(novel.id);
                if (!context.mounted) return;
                AppSnackbar.show(context, '已删除《${novel.title}》');
                onDeleted();
              } catch (e) {
                debugPrint('[NovelDetailPage] 删除失败: $e');
                if (context.mounted) {
                  AppSnackbar.show(context, '删除失败，请重试');
                }
              }
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.accentRose),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
            ),
            child: Text('删除小说',
                style: AppTextStyles.body.copyWith(color: AppColors.accentRose)),
          ),
        ),
      ],
    );
  }
}
