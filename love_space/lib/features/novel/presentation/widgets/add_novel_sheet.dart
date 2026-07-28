import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/crawler/crawler_result.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../data/repositories/crawl_repository.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import 'crawl_progress_sheet.dart';

/// 添加小说底部面板
///
/// 支持搜索小说、展示结果列表、点击「加入书架」触发爬取。
class AddNovelSheet extends ConsumerStatefulWidget {
  const AddNovelSheet({super.key});

  /// 弹出添加小说面板
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddNovelSheet(),
    );
  }

  @override
  ConsumerState<AddNovelSheet> createState() => _AddNovelSheetState();
}

class _AddNovelSheetState extends ConsumerState<AddNovelSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<SearchResult> _results = [];
  bool _isSearching = false;
  String? _errorMessage;
  bool _isAdding = false;

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 执行搜索
  Future<void> _search() async {
    final keyword = _searchController.text.trim();
    if (keyword.isEmpty) return;

    setState(() {
      _isSearching = true;
      _errorMessage = null;
      _results = [];
    });

    try {
      final results = await ref.read(crawlRepositoryProvider).search(keyword);
      if (!mounted) return;
      setState(() {
        _results = results;
        _isSearching = false;
        if (results.isEmpty) {
          _errorMessage = '未找到相关小说，换个关键词试试吧';
        }
      });
    } catch (e) {
      debugPrint('[AddNovelSheet] 搜索失败: $e');
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _errorMessage = '搜索失败，请稍后重试';
      });
    }
  }

  /// 添加小说到书架
  Future<void> _addNovel(SearchResult result) async {
    if (_isAdding) return;

    setState(() => _isAdding = true);

    // 捕获根导航器（在显示任何面板之前），用于后续关闭面板和显示提示
    final navigator = Navigator.of(context);

    // 重置爬取状态
    ref.read(crawlStatusProvider.notifier).state = const CrawlStatus(
      state: 'fetching',
      message: '准备获取...',
    );

    // 弹出进度面板
    CrawlProgressSheet.show(context, title: '正在添加《${result.title}》');

    try {
      // 进度回调（作为参数传入，避免单例可变状态）
      void onProgress(String message, int current, int total) {
        if (!mounted) return;
        ref.read(crawlStatusProvider.notifier).state = CrawlStatus(
          state: 'fetching',
          message: message,
          current: current,
          total: total,
        );
      }

      await ref.read(crawlRepositoryProvider).addNovel(
            result.url,
            onProgress: onProgress,
          );

      if (!mounted) return;

      // 标记成功
      ref.read(crawlStatusProvider.notifier).state = const CrawlStatus(
        state: 'success',
        message: '完成',
      );

      // 关闭进度面板 + 添加面板，然后提示
      navigator.pop(); // 关闭进度面板
      navigator.pop(); // 关闭添加面板
      AppSnackbar.show(navigator.context, '已添加《${result.title}》');
    } on CancelledException {
      // 用户主动取消，不显示错误
    } catch (e) {
      if (!mounted) return;
      ref.read(crawlStatusProvider.notifier).state = CrawlStatus(
        state: 'failed',
        message: '添加失败：$e',
      );
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  /// 从粘贴的 URL 直接添加小说
  Future<void> _addFromUrl() async {
    if (_isAdding) return;

    // 显示输入链接的对话框
    final urlController = TextEditingController();
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('粘贴书籍链接', style: AppTextStyles.titleSmall),
        content: TextField(
          controller: urlController,
          autofocus: true,
          decoration: InputDecoration(
            hintText: 'https://www.biquge2.net/book/xxx/',
            hintStyle: AppTextStyles.body.copyWith(
              color: AppColors.textTertiary,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
            ),
          ),
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(urlController.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRose,
            ),
            child: const Text('添加'),
          ),
        ],
      ),
    );

    if (url == null || url.isEmpty) return;
    if (!mounted) return;

    setState(() => _isAdding = true);
    final navigator = Navigator.of(context);

    ref.read(crawlStatusProvider.notifier).state = const CrawlStatus(
      state: 'fetching',
      message: '准备获取...',
    );

    CrawlProgressSheet.show(context, title: '正在添加小说');

    try {
      void onProgress(String message, int current, int total) {
        if (!mounted) return;
        ref.read(crawlStatusProvider.notifier).state = CrawlStatus(
          state: 'fetching',
          message: message,
          current: current,
          total: total,
        );
      }

      await ref.read(crawlRepositoryProvider).addNovel(
            url,
            onProgress: onProgress,
          );

      if (!mounted) return;

      ref.read(crawlStatusProvider.notifier).state = const CrawlStatus(
        state: 'success',
        message: '完成',
      );

      navigator.pop(); // 关闭进度面板
      navigator.pop(); // 关闭添加面板
      AppSnackbar.show(navigator.context, '已添加小说');
    } on CancelledException {
      // 用户主动取消
    } catch (e) {
      if (!mounted) return;
      ref.read(crawlStatusProvider.notifier).state = CrawlStatus(
        state: 'failed',
        message: '添加失败：$e',
      );
    } finally {
      if (mounted) setState(() => _isAdding = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
          children: [
            // 标题栏
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('添加小说', style: AppTextStyles.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            // 搜索栏
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      focusNode: _focusNode,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(
                        hintText: '输入小说名搜索，或粘贴书籍链接',
                        hintStyle: AppTextStyles.body.copyWith(
                          color: AppColors.textTertiary,
                        ),
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppColors.textTertiary),
                        filled: true,
                        fillColor: AppColors.bgCream,
                        border: OutlineInputBorder(
                          borderRadius:
                              BorderRadius.circular(AppColors.radiusMd),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSearching ? null : _search,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentRose,
                      shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppColors.radiusMd),
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 14,
                      ),
                    ),
                    child: const Text('搜索'),
                  ),
                ],
              ),
            ),

            // 粘贴链接入口
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
              child: GestureDetector(
                onTap: _addFromUrl,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.link_rounded,
                        size: 16, color: AppColors.accentRose),
                    const SizedBox(width: 6),
                    Text('直接粘贴书籍详情页链接',
                        style: AppTextStyles.label
                            .copyWith(color: AppColors.accentRose)),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            const Divider(height: 1, color: AppColors.borderSoft),

            // 结果列表
            Expanded(
              child: _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    if (_isSearching) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accentRose,
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off_rounded,
                  size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text(_errorMessage!, style: AppTextStyles.caption),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.menu_book_rounded,
                  size: 48, color: AppColors.textTertiary),
              const SizedBox(height: 12),
              Text('输入关键词搜索小说', style: AppTextStyles.caption),
              const SizedBox(height: 4),
              Text('数据来源：笔趣阁系列站点',
                  style: AppTextStyles.label),
            ],
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        final result = _results[i];
        return _NovelSearchResultCard(
          result: result,
          onTap: () => _addNovel(result),
        );
      },
    );
  }
}

/// 搜索结果卡片
class _NovelSearchResultCard extends StatelessWidget {
  final SearchResult result;
  final VoidCallback onTap;

  const _NovelSearchResultCard({
    required this.result,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppColors.radiusMd),
          border: Border.all(color: AppColors.borderSoft),
        ),
        child: Row(
          children: [
            // 封面占位
            Container(
              width: 56,
              height: 76,
              decoration: BoxDecoration(
                color: AppColors.accentPinkSoft,
                borderRadius: BorderRadius.circular(AppColors.radiusSm),
              ),
              child: const Center(
                child: Icon(
                  Icons.menu_book_rounded,
                  color: AppColors.accentRose,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(width: 12),

            // 信息
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.title,
                    style: AppTextStyles.titleSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    result.author.isNotEmpty ? '作者：${result.author}' : '作者未知',
                    style: AppTextStyles.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (result.intro.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      result.intro,
                      style: AppTextStyles.label,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  if (result.latestChapter.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      '最新：${result.latestChapter}',
                      style: AppTextStyles.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // 添加按钮
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.accentPinkSoft,
                borderRadius: BorderRadius.circular(AppColors.radiusPill),
              ),
              child: Text(
                '加入书架',
                style: AppTextStyles.label.copyWith(
                  color: AppColors.accentRose,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
