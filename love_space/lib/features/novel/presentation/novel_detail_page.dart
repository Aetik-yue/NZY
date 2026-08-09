import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/providers/data_providers.dart';
import 'widgets/detail_actions.dart';
import 'widgets/detail_header.dart';

/// 小说详情页
///
/// 展示封面、标题、作者、简介、标签、章节数，并提供「开始阅读」与「目录」入口。
/// 头部渲染与操作按钮拆分至 DetailHeader / DetailActions 子 Widget。
class NovelDetailPage extends ConsumerWidget {
  final int novelId;

  const NovelDetailPage({super.key, required this.novelId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final novelsAsync = ref.watch(novelsProvider);
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
      body: novelsAsync.when(
        data: (novels) {
          final novel = novels.where((n) => n.id == novelId).firstOrNull;
          if (novel == null) {
            return const Center(child: Text('未找到该小说'));
          }
          final chaptersAsync = ref.watch(chaptersProvider(novelId));
          return chaptersAsync.when(
            data: (chapters) {
              final resumeIndex = novel.lastChapterIndex < 0 || chapters.isEmpty
                  ? 0
                  : novel.lastChapterIndex.clamp(0, chapters.length - 1);
              return SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 100),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DetailHeader(
                      novel: novel,
                      chapterCount: chapters.length,
                    ),
                    const SizedBox(height: 28),
                    DetailActions(
                      novel: novel,
                      resumeIndex: resumeIndex,
                      onDeleted: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              );
            },
            loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2)),
            error: (_, __) => const Center(child: Text('章节加载失败')),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, __) => const Center(child: Text('加载失败')),
      ),
    );
  }
}
