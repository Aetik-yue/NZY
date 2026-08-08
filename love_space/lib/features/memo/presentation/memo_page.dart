import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/memo.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
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
    final authorFilter = ref.watch(memoAuthorFilterProvider);
    final isSearchResult = searchQuery.isNotEmpty ||
        tagFilter != null ||
        authorFilter != null;

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
            // 作者筛选栏（全部 / 越 / 名）
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: _AuthorFilterChips(),
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
class _MemoList extends ConsumerWidget {
  final List<Memo> memos;
  const _MemoList({required this.memos});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
              onTogglePin: () => _togglePin(context, ref, m.id),
              onDelete: () => _delete(context, ref, m),
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
              onTogglePin: () => _togglePin(context, ref, m.id),
              onDelete: () => _delete(context, ref, m),
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

  Future<void> _togglePin(
      BuildContext context, WidgetRef ref, int memoId) async {
    try {
      await ref.read(memoRepositoryProvider).togglePin(memoId);
    } catch (e) {
      debugPrint('[MemoList] 置顶失败: $e');
      if (context.mounted) AppSnackbar.show(context, '操作失败，请重试');
    }
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Memo memo) async {
    // 删除前确认（与其他模块保持一致）
    final confirmed = await showConfirmDeleteDialog(
      context,
      content: '确定要删除这条备忘录吗？',
    );
    if (!confirmed || !context.mounted) return;
    try {
      await ref.read(memoRepositoryProvider).delete(memo.id);
      if (!context.mounted) return;
      AppSnackbar.showUndo(context, '已删除', () async {
        await ref.read(memoRepositoryProvider).add(memo);
      });
    } catch (e) {
      debugPrint('[MemoList] 删除失败: $e');
      if (context.mounted) AppSnackbar.show(context, '删除失败，请重试');
    }
  }
}

/// 作者筛选胶囊（全部 / 越 / 名）
class _AuthorFilterChips extends ConsumerWidget {
  const _AuthorFilterChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(memoAuthorFilterProvider);
    final options = <(int?, String)>[
      (null, '全部'),
      (1, '越'),
      (2, '名'),
    ];
    return SizedBox(
      height: 34,
      child: Row(
        children: [
          for (final (value, label) in options)
            GestureDetector(
              onTap: () =>
                  ref.read(memoAuthorFilterProvider.notifier).state = value,
              child: Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected == value
                      ? AppColors.accentRose
                      : AppColors.bgCard,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  border: selected == value
                      ? null
                      : Border.all(color: AppColors.borderSoft),
                ),
                child: Text(
                  label,
                  style: AppTextStyles.caption.copyWith(
                    color: selected == value
                        ? Colors.white
                        : AppColors.textSecondary,
                    fontWeight:
                        selected == value ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
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
