import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/memo.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../data/sync/sync_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import 'memo_edit_page.dart';
import 'widgets/memo_card.dart';
import 'widgets/memo_search_bar.dart';
import 'widgets/quick_capture_bar.dart';
import 'widgets/todo_filter_chips.dart';
import 'widgets/todo_summary_card.dart';

/// 简化后的待办页：快速添加、待完成和已完成构成唯一主流程。
class MemoPage extends ConsumerStatefulWidget {
  const MemoPage({super.key});

  @override
  ConsumerState<MemoPage> createState() => _MemoPageState();
}

class _MemoPageState extends ConsumerState<MemoPage> {
  bool _showSearch = false;

  @override
  void initState() {
    super.initState();
    ref.read(memoDoneFilterProvider.notifier).state = TodoFilter.active;
    ref.read(memoSearchProvider.notifier).state = '';
    ref.read(memoTagFilterProvider.notifier).state = null;
    ref.read(memoAuthorFilterProvider.notifier).state = null;
  }

  void _toggleSearch() {
    setState(() => _showSearch = !_showSearch);
    if (!_showSearch) ref.read(memoSearchProvider.notifier).state = '';
  }

  void _openCreate() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const MemoEditPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final memosAsync = ref.watch(memosProvider);
    final filtered = ref.watch(filteredMemosProvider);
    final stats = ref.watch(memoStatsProvider);
    final active = stats.total - stats.done;
    final query = ref.watch(memoSearchProvider).trim();

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('待办', style: AppTextStyles.titleMedium),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: _showSearch ? '关闭搜索' : '搜索待办',
            onPressed: _toggleSearch,
            icon: Icon(
              _showSearch ? Icons.close_rounded : Icons.search_rounded,
              color: AppColors.textPrimary,
            ),
          ),
          IconButton(
            tooltip: '新建详细待办',
            onPressed: _openCreate,
            icon: const Icon(Icons.add_rounded, color: AppColors.accentRose),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: TodoSummaryCard(active: active, done: stats.done),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: QuickCaptureBar(),
            ),
            if (_showSearch)
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 10, 16, 0),
                child: MemoSearchBar(),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TodoFilterChips(),
            ),
            Expanded(
              child: memosAsync.when(
                data: (_) => filtered.isEmpty
                    ? _EmptyState(
                        isSearchResult: query.isNotEmpty,
                        showingDone: ref.watch(memoDoneFilterProvider) ==
                            TodoFilter.done,
                        onCreate: _openCreate,
                      )
                    : _MemoList(memos: filtered),
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (_, __) => const Center(child: Text('待办加载失败')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MemoList extends ConsumerWidget {
  const _MemoList({required this.memos});

  final List<Memo> memos;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      itemCount: memos.length,
      itemBuilder: (context, index) {
        final memo = memos[index];
        return MemoCard(
          memo: memo,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => MemoEditPage(memoId: memo.id),
            ),
          ),
          onTogglePin: () => _togglePin(context, ref, memo.id),
          onToggleDone: () => _toggleDone(context, ref, memo),
          onDelete: () => _delete(context, ref, memo),
        );
      },
    );
  }

  Future<void> _togglePin(
    BuildContext context,
    WidgetRef ref,
    int memoId,
  ) async {
    try {
      await ref.read(memoRepositoryProvider).togglePin(memoId);
    } catch (error) {
      debugPrint('[MemoList] 置顶失败: $error');
      if (context.mounted) AppSnackbar.show(context, '操作失败，请重试');
    }
  }

  Future<void> _toggleDone(
    BuildContext context,
    WidgetRef ref,
    Memo memo,
  ) async {
    try {
      await ref.read(memoRepositoryProvider).toggleDone(memo.id);
      if (!context.mounted) return;
      AppSnackbar.showUndo(
        context,
        memo.done ? '已重新加入待办' : '完成了一件事 ✨',
        () => ref.read(memoRepositoryProvider).toggleDone(memo.id),
      );
    } catch (error) {
      debugPrint('[MemoList] 切换完成状态失败: $error');
      if (context.mounted) AppSnackbar.show(context, '操作失败，请重试');
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Memo memo,
  ) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      content: '确定要删除这条待办吗？',
    );
    if (!confirmed || !context.mounted) return;
    try {
      final cloudId = memo.cloudId;
      await ref.read(memoRepositoryProvider).delete(memo.id);
      if (cloudId != null) ref.read(syncEngineProvider).markDeleted(cloudId);
      if (!context.mounted) return;
      AppSnackbar.showUndo(context, '已删除', () async {
        if (cloudId != null) {
          ref.read(syncEngineProvider).restoreDeleted(cloudId);
        }
        await ref.read(memoRepositoryProvider).add(memo);
      });
    } catch (error) {
      debugPrint('[MemoList] 删除失败: $error');
      if (context.mounted) AppSnackbar.show(context, '删除失败，请重试');
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.isSearchResult,
    required this.showingDone,
    required this.onCreate,
  });

  final bool isSearchResult;
  final bool showingDone;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final title = isSearchResult
        ? '没有找到相关待办'
        : showingDone
            ? '还没有已完成的待办'
            : '没有待完成的事情';
    final subtitle = isSearchResult
        ? '换个关键词试试'
        : showingDone
            ? '完成后的待办会收进这里'
            : '享受片刻轻松，或添加一件新事情';
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              showingDone ? Icons.task_alt_rounded : Icons.checklist_rounded,
              size: 56,
              color: AppColors.accentPinkSoft,
            ),
            const SizedBox(height: 14),
            Text(title, style: AppTextStyles.titleSmall),
            const SizedBox(height: 6),
            Text(subtitle,
                textAlign: TextAlign.center, style: AppTextStyles.caption),
            if (!isSearchResult && !showingDone) ...[
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: onCreate,
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('添加详细待办'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
