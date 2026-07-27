import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/providers/data_providers.dart';
import '../../../data/models/novel.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import '../../../shared/widgets/app_snackbar.dart';
import 'widgets/chapter_list_sheet.dart';
import 'novel_reader_page.dart';

/// 小说详情页
///
/// 展示封面、标题、作者、简介、标签、章节数，并提供「开始阅读」与「目录」入口。
class NovelDetailPage extends ConsumerWidget {
  final int novelId;

  const NovelDetailPage({super.key, required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final novelsAsync = ref.watch(novelsProvider);

    return novelsAsync.when(
      data: (novels) {
        final novel = novels.where((n) => n.id == novelId).firstOrNull;
        if (novel == null) {
          return _buildScaffold(
            context,
            body: const Center(child: Text('未找到该小说')),
          );
        }

        final chaptersAsync = ref.watch(chaptersProvider(novelId));
        return chaptersAsync.when(
          data: (chapters) {
            final resumeIndex = novel.lastChapterIndex < 0 || chapters.isEmpty
                ? 0
                : novel.lastChapterIndex.clamp(0, chapters.length - 1);
            return _buildScaffold(
              context,
              body:
                  _buildBody(context, ref, novel, chapters.length, resumeIndex),
            );
          },
          loading: () => _buildScaffold(
            context,
            body:
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, __) => _buildScaffold(
            context,
            body: const Center(child: Text('章节加载失败')),
          ),
        );
      },
      loading: () => _buildScaffold(
        context,
        body: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (_, __) => _buildScaffold(
        context,
        body: const Center(child: Text('加载失败')),
      ),
    );
  }

  Widget _buildScaffold(BuildContext context, {required Widget body}) {
    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded,
              color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('小说详情', style: AppTextStyles.titleSmall),
        centerTitle: true,
      ),
      body: body,
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    Novel novel,
    int chapterCount,
    int resumeIndex,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 封面 + 基本信息
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 110,
                height: 150,
                decoration: BoxDecoration(
                  color: Color(novel.coverColorValue),
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                  boxShadow: const [
                    BoxShadow(
                      color: AppColors.shadowCard,
                      blurRadius: 16,
                      offset: Offset(0, 6),
                      spreadRadius: -4,
                    ),
                  ],
                ),
                child: const Center(
                  child: Icon(
                    Icons.menu_book_rounded,
                    color: AppColors.textOnPink,
                    size: 44,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 6),
                    Text(novel.title, style: AppTextStyles.titleMedium),
                    const SizedBox(height: 6),
                    Text(novel.author, style: AppTextStyles.caption),
                    const SizedBox(height: 10),
                    Text('共 $chapterCount 章', style: AppTextStyles.label),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),

          // 标签
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in novel.tags)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.accentPinkSoft,
                    borderRadius: BorderRadius.circular(AppColors.radiusXs),
                  ),
                  child: Text(tag,
                      style: AppTextStyles.label
                          .copyWith(color: AppColors.accentRose)),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // 简介
          Text('简介', style: AppTextStyles.titleSmall),
          const SizedBox(height: 8),
          Text(novel.intro, style: AppTextStyles.body),

          const SizedBox(height: 28),

          // 开始阅读
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
                style: const TextStyle(fontSize: 16),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 目录
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
              child: Text(
                '目录',
                style: AppTextStyles.body.copyWith(color: AppColors.accentRose),
              ),
            ),
          ),
          const SizedBox(height: 12),

          // 删除小说
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
                if (!confirmed) return;
                if (!context.mounted) return;
                await ref
                    .read(novelChapterRepositoryProvider)
                    .deleteByNovel(novel.id);
                await ref.read(novelRepositoryProvider).delete(novel.id);
                if (!context.mounted) return;
                AppSnackbar.show(context, '已删除《${novel.title}》');
                Navigator.of(context).pop();
              },
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.accentRose),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppColors.radiusMd),
                ),
              ),
              child: Text(
                '删除小说',
                style: AppTextStyles.body.copyWith(color: AppColors.accentRose),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
