import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/anniversary.dart';
import '../../../data/providers/data_providers.dart';
import '../../../shared/widgets/app_snackbar.dart';
import '../../../shared/widgets/confirm_dialog.dart';
import 'widgets/add_anniversary_sheet.dart';
import 'widgets/anniversary_timeline_item.dart';

/// 纪念日管理页 · 动画时间轴（二级页）
///
/// 进入页面后播放一次入场动画：左侧竖线自上而下延伸，右侧纪念日节点
/// 依次淡入并从右滑入。点击节点弹操作单（编辑/删除），右上角 ＋ 添加。
class AnniversaryPage extends ConsumerStatefulWidget {
  const AnniversaryPage({super.key});

  @override
  ConsumerState<AnniversaryPage> createState() => _AnniversaryPageState();
}

class _AnniversaryPageState extends ConsumerState<AnniversaryPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final ProviderSubscription<AsyncValue<List<Anniversary>>> _dataSub;
  bool _introPlayed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // 首次拿到非空数据后播放一次入场动画。
    // fireImmediately 兼容数据已缓存（如从首页进入）的场景：若已就绪则立即触发。
    _dataSub = ref.listenManual<AsyncValue<List<Anniversary>>>(
      anniversariesProvider,
      (_, next) {
        final items = next.valueOrNull;
        if (!_introPlayed && items != null && items.isNotEmpty) {
          _introPlayed = true;
          // 下一帧再 forward，确保时间轴已布局、首帧以 progress=0 渲染
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _ctrl.forward();
          });
        }
      },
      fireImmediately: true,
    );
  }

  @override
  void dispose() {
    _dataSub.close();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final anniversariesAsync = ref.watch(anniversariesProvider);
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
        title: Text('纪念日', style: AppTextStyles.titleMedium),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_circle_rounded,
                color: AppColors.accentRose, size: 26),
            tooltip: '添加纪念日',
            onPressed: () => AddAnniversarySheet.show(context),
          ),
        ],
      ),
      body: anniversariesAsync.when(
        data: (items) {
          if (items.isEmpty) return const _EmptyState();
          // 时间轴按月日升序（年度循环视角，最早的在顶部）
          final sorted = _sortByMonthDay(items);
          final n = sorted.length;
          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
            child: Column(
              children: [
                for (int i = 0; i < n; i++)
                  AnimatedBuilder(
                    animation: _ctrl,
                    builder: (_, __) => AnniversaryTimelineItem(
                      item: sorted[i],
                      index: i,
                      total: n,
                      progress: _ctrl.value,
                      isLast: i == n - 1,
                      onTap: () => _showActions(context, ref, sorted[i]),
                    ),
                  ),
              ],
            ),
          );
        },
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (_, __) => const Center(child: Text('加载失败')),
      ),
    );
  }

  /// 按月日升序排序（年度循环视角，1月在最上）
  List<Anniversary> _sortByMonthDay(List<Anniversary> items) {
    final copy = List<Anniversary>.of(items);
    copy.sort((a, b) {
      final cmp = a.date.month.compareTo(b.date.month);
      if (cmp != 0) return cmp;
      return a.date.day.compareTo(b.date.day);
    });
    return copy;
  }

  /// 点击节点弹操作单：编辑 / 删除
  Future<void> _showActions(
    BuildContext context,
    WidgetRef ref,
    Anniversary item,
  ) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppColors.radiusSheet)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined,
                  color: AppColors.textSecondary),
              title: const Text('编辑'),
              onTap: () => Navigator.of(ctx).pop('edit'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline,
                  color: AppColors.accentRose),
              title: const Text('删除'),
              onTap: () => Navigator.of(ctx).pop('delete'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!context.mounted) return;
    switch (action) {
      case 'edit':
        await AddAnniversarySheet.show(context, initial: item);
      case 'delete':
        await _delete(context, ref, item);
    }
  }

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    Anniversary item,
  ) async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      content: '确定要删除「${item.title}」吗？',
    );
    if (!confirmed || !context.mounted) return;
    try {
      final repo = ref.read(anniversaryRepositoryProvider);
      await repo.delete(item.id);
      if (!context.mounted) return;
      AppSnackbar.showUndo(context, '已删除', () async {
        try {
          await repo.add(item);
        } catch (e) {
          debugPrint('[AnniversaryPage] 撤销删除失败: $e');
        }
      });
    } catch (e) {
      debugPrint('[AnniversaryPage] 删除失败: $e');
      if (context.mounted) AppSnackbar.show(context, '删除失败，请重试');
    }
  }
}

/// 空状态
class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.favorite_border_rounded,
              size: 64, color: AppColors.accentPinkSoft),
          const SizedBox(height: 16),
          Text('还没有纪念日', style: AppTextStyles.titleSmall),
          const SizedBox(height: 6),
          Text('记录在一起、生日等特别的日子吧',
              style: AppTextStyles.caption),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: () => AddAnniversarySheet.show(context),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppColors.radiusMd),
              ),
            ),
            child: const Text('添加第一个'),
          ),
        ],
      ),
    );
  }
}
