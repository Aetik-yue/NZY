import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/memo.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import 'widgets/quick_capture_bar.dart';
import 'widgets/memo_search_bar.dart';
import 'widgets/tag_filter_chips.dart';
import 'widgets/date_group_header.dart';
import 'widgets/memo_card.dart';
import 'memo_edit_page.dart';

/// 备忘录主页面（二级页）
///
/// 从「我的」页功能卡点击进入，展示按时间分组的备忘录列表，
/// 支持快速输入、搜索、标签筛选、置顶、编辑、删除。
class MemoPage extends ConsumerWidget {
  const MemoPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final memos = ref.watch(filteredMemosProvider);
    final allTags = ref.watch(allTagsProvider);
    final searchQuery = ref.watch(memoSearchProvider);
    final tagFilter = ref.watch(memoTagFilterProvider);
    final isSearchResult =
        searchQuery.isNotEmpty || tagFilter != null;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('备忘录', style: AppTextStyles.titleMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 顶部快速输入栏
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: QuickCaptureBar(),
            ),
            // 搜索栏
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: MemoSearchBar(),
            ),
            // 标签筛选栏（有标签时显示）
            if (allTags.isNotEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: TagFilterChips(),
              ),
            // 列表区域
            Expanded(
              child: memos.isEmpty
                  ? _EmptyState(isSearchResult: isSearchResult)
                  : _MemoList(memos: memos),
            ),
          ],
        ),
      ),
    );
  }
}

/// 备忘录列表（按日期分组，置顶在前）
class _MemoList extends StatelessWidget {
  final List<Memo> memos;
  const _MemoList({required this.memos});

  @override
  Widget build(BuildContext context) {
    // 分离置顶和非置顶
    final pinned = memos.where((m) => m.isPinned).toList();
    final unpinned = memos.where((m) => !m.isPinned).toList();

    // 按日期分组非置顶 memo
    final groups = _groupByDate(unpinned);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        // 置顶区域
        if (pinned.isNotEmpty) ...[
          const DateGroupHeader(label: '📌 置顶'),
          const SizedBox(height: 8),
          for (final m in pinned)
            MemoCard(
              memo: m,
              onTap: () => _openEdit(context, m.id),
              onTogglePin: () => _togglePin(context, m.id),
              onDelete: () => _delete(context, m),
            ),
          const SizedBox(height: 16),
        ],
        // 时间线区域
        for (final group in groups) ...[
          DateGroupHeader(label: group.label),
          const SizedBox(height: 8),
          for (final m in group.memos)
            MemoCard(
              memo: m,
              onTap: () => _openEdit(context, m.id),
              onTogglePin: () => _togglePin(context, m.id),
              onDelete: () => _delete(context, m),
            ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }

  /// 按日期分组（今天 / 昨天 / 年月）
  List<_DateGroup> _groupByDate(List<Memo> memos) {
    if (memos.isEmpty) return [];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<Memo>> map = {};
    for (final m in memos) {
      final d = m.createdAt;
      final key = DateTime(d.year, d.month, d.day);
      String label;
      if (key == today) {
        label = '今天';
      } else if (key == yesterday) {
        label = '昨天';
      } else {
        label = '${d.year}年${d.month}月';
      }
      map.putIfAbsent(label, () => []).add(m);
    }

    // 保持时间序（今天 → 昨天 → 更早）
    return map.entries
        .map((e) => _DateGroup(label: e.key, memos: e.value))
        .toList();
  }

  void _openEdit(BuildContext context, int memoId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MemoEditPage(memoId: memoId),
      ),
    );
  }

  void _togglePin(BuildContext context, int memoId) {
    _container(context).read(memoRepositoryProvider).togglePin(memoId);
  }

  Future<void> _delete(BuildContext context, Memo memo) async {
    final container = _container(context);
    await container.read(memoRepositoryProvider).delete(memo.id);
    if (context.mounted) {
      AppSnackbar.showUndo(context, '已删除', () {
        container.read(memoRepositoryProvider).add(memo);
      });
    }
  }

  ProviderContainer _container(BuildContext context) {
    return ProviderScope.containerOf(context);
  }
}

/// 日期分组数据
class _DateGroup {
  final String label;
  final List<Memo> memos;
  const _DateGroup({required this.label, required this.memos});
}

/// 空状态（区分：无备忘录 / 搜索无结果 / 标签无结果）
class _EmptyState extends StatelessWidget {
  final bool isSearchResult;
  const _EmptyState({this.isSearchResult = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isSearchResult ? Icons.search_off_rounded : Icons.sticky_note_2_outlined,
            size: 64,
            color: AppColors.accentPinkSoft,
          ),
          const SizedBox(height: 16),
          Text(
            isSearchResult ? '没有找到相关备忘录' : '还没有备忘录',
            style: AppTextStyles.titleSmall,
          ),
          const SizedBox(height: 6),
          Text(
            isSearchResult ? '试试其他关键词吧' : '记录第一条吧 ✨',
            style: AppTextStyles.caption,
          ),
        ],
      ),
    );
  }
}
