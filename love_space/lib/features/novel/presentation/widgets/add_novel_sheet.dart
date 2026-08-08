import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/crawler/crawler_result.dart';
import '../../../../data/models/novel.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../data/repositories/crawl_repository.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../novel_detail_page.dart';
import 'category_book_card.dart';
import 'crawl_progress_sheet.dart';
import 'novel_search_result_card.dart';

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
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppColors.radiusCard)),
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

  /// 去重命中：已在书架的小说（添加成功后跳转详情）
  Novel? _duplicateNovel;

  // ──── 分类浏览状态 ────
  int _tabIndex = 0; // 0=搜索 1=分类浏览
  int _selectedCategory = 1;
  int _categoryPage = 1;
  List<CategoryBook> _categoryBooks = [];
  bool _isBrowsing = false;
  bool _hasMore = true;

  /// 分类定义（biquge2.net 的分类 ID 和名称）
  static const _categories = [
    (1, '玄幻'),
    (2, '修真'),
    (3, '都市'),
    (4, '历史'),
    (5, '网游'),
    (6, '科幻'),
    (7, '恐怖'),
    (8, '其他'),
  ];

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  /// 浏览分类小说
  Future<void> _browseCategory({bool loadMore = false}) async {
    if (_isBrowsing) return;
    if (loadMore && !_hasMore) return;

    setState(() {
      _isBrowsing = true;
      if (!loadMore) {
        _categoryBooks = [];
        _categoryPage = 1;
      }
    });

    try {
      final books = await ref.read(crawlRepositoryProvider).browseCategory(
            _selectedCategory,
            page: _categoryPage,
          );
      if (!mounted) return;
      setState(() {
        _categoryBooks = [..._categoryBooks, ...books];
        _isBrowsing = false;
        _hasMore = books.isNotEmpty && books.length >= 10;
        if (loadMore) _categoryPage++;
      });
    } catch (e) {
      debugPrint('[AddNovelSheet] 分类浏览失败: $e');
      if (!mounted) return;
      setState(() => _isBrowsing = false);
      AppSnackbar.show(context, '分类加载失败，请重试');
    }
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

  /// 统一的添加流程（搜索 / 分类浏览 / 粘贴链接共用）：
  /// 弹进度面板 → 爬取 → 成功关闭面板 / 重复跳详情 / 失败/取消静默返回。
  Future<void> _startAdd({
    required String url,
    required String title,
  }) async {
    if (_isAdding) return;

    setState(() => _isAdding = true);

    // 捕获根导航器（用于后续关闭添加面板 + 显示提示）
    final navigator = Navigator.of(context);

    ref.read(crawlStatusProvider.notifier).state = const CrawlStatus(
      state: 'fetching',
      message: '准备获取...',
    );

    // 弹出进度面板：成功/失败/取消时面板会自动关闭，
    // 其返回值 true=成功、false=失败/取消，据此再关闭添加面板（只 pop 一次）。
    final sheetFuture = CrawlProgressSheet.show(
      context,
      title: '正在添加《$title》',
    );

    try {
      await ref.read(crawlRepositoryProvider).addNovel(
            url,
            onProgress: (message, current, total) {
              if (!mounted) return;
              ref.read(crawlStatusProvider.notifier).state = CrawlStatus(
                state: 'fetching',
                message: message,
                current: current,
                total: total,
              );
            },
          );

      if (!mounted) return;
      ref.read(crawlStatusProvider.notifier).state = const CrawlStatus(
        state: 'success',
        message: '完成',
      );
    } on NovelAlreadyExistsException catch (e) {
      // 已在书架：记录命中，关闭面板后提示并跳转详情
      _onDuplicate(e);
    } on CancelledException {
      // 用户主动取消
    } catch (e) {
      debugPrint('[AddNovelSheet] 添加失败: $e');
      if (!mounted) return;
      ref.read(crawlStatusProvider.notifier).state = const CrawlStatus(
        state: 'failed',
        message: '添加失败',
      );
    }

    // 等待进度面板自动关闭
    final ok = await sheetFuture;
    if (!mounted) return;

    if (_duplicateNovel != null) {
      _handleDuplicate(_duplicateNovel!, navigator);
    } else if (ok == true) {
      navigator.pop(); // 关闭添加面板（进度面板已自动关闭）
      AppSnackbar.show(navigator.context, '已添加《$title》');
    }
    if (mounted) setState(() => _isAdding = false);
  }

  /// 添加分类浏览到的书到书架
  Future<void> _addCategoryBook(CategoryBook book) =>
      _startAdd(url: book.url, title: book.title);

  /// 去重命中：记录命中的书，并让进度面板以「已在书架中」状态关闭
  void _onDuplicate(NovelAlreadyExistsException e) {
    _duplicateNovel = e.novel;
    if (mounted) {
      ref.read(crawlStatusProvider.notifier).state = const CrawlStatus(
        state: 'failed',
        message: '已在书架中',
      );
    }
  }

  /// 已在书架：关闭添加面板、提示并跳转详情
  void _handleDuplicate(Novel dup, NavigatorState navigator) {
    navigator.pop(); // 关闭添加面板（进度面板已自动关闭）
    AppSnackbar.show(navigator.context, '《${dup.title}》已在书架中');
    navigator.push(
      MaterialPageRoute(builder: (_) => NovelDetailPage(novelId: dup.id)),
    );
  }

  /// 添加搜索到的小说到书架
  Future<void> _addNovel(SearchResult result) =>
      _startAdd(url: result.url, title: result.title);

  /// 从粘贴的 URL 直接添加小说
  Future<void> _addFromUrl() async {
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
          borderRadius: BorderRadius.circular(AppColors.radiusSheet),
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
    await _startAdd(url: url, title: '小说');
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

            // 模式切换 Tab
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Container(
                height: 36,
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.bgBlush,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
                child: Row(
                  children: [
                    _buildModeTab(0, Icons.search_rounded, '搜索'),
                    _buildModeTab(1, Icons.category_rounded, '分类浏览'),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),

            // 搜索模式内容
            if (_tabIndex == 0) ...[
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
                          hintText: '输入小说名搜索',
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
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
            ] else ...[
              // 分类浏览内容
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _categories.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      final (id, label) = _categories[i];
                      final isActive = _selectedCategory == id;
                      return GestureDetector(
                        onTap: () {
                          setState(() => _selectedCategory = id);
                          _browseCategory();
                        },
                        child: Container(
                          padding:
                              const EdgeInsets.symmetric(horizontal: 14),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: isActive
                                ? AppColors.accentRose
                                : AppColors.bgCard,
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusPill),
                            border: isActive
                                ? null
                                : Border.all(color: AppColors.borderSoft),
                          ),
                          child: Text(
                            label,
                            style: AppTextStyles.caption.copyWith(
                              color: isActive
                                  ? Colors.white
                                  : AppColors.textSecondary,
                              fontWeight: isActive
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Divider(height: 1, color: AppColors.borderSoft),
            ],

            // 内容区域（搜索或分类浏览）
            Expanded(
              child: _tabIndex == 0 ? _buildContent() : _buildCategoryContent(),
            ),
          ],
        ),
      ),
    );
  }

  /// 模式切换 Tab 按钮
  Widget _buildModeTab(int index, IconData icon, String label) {
    final isActive = _tabIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _tabIndex = index;
            if (index == 1) {
              // 切到分类浏览时自动加载
              if (_categoryBooks.isEmpty) _browseCategory();
            }
          });
        },
        behavior: HitTestBehavior.opaque,
        child: Container(
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isActive ? AppColors.bgCard : Colors.transparent,
            borderRadius: BorderRadius.circular(AppColors.radiusPill),
            boxShadow: isActive
                ? const [
                    BoxShadow(
                      color: AppColors.shadowCard,
                      blurRadius: 6,
                      offset: Offset(0, 2),
                      spreadRadius: -2,
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon,
                  size: 16,
                  color: isActive
                      ? AppColors.accentRose
                      : AppColors.textTertiary),
              const SizedBox(width: 4),
              Text(
                label,
                style: AppTextStyles.caption.copyWith(
                  color: isActive
                      ? AppColors.accentRose
                      : AppColors.textTertiary,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 分类浏览内容区域
  Widget _buildCategoryContent() {
    if (_isBrowsing && _categoryBooks.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.accentRose),
      );
    }

    if (_categoryBooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.menu_book_rounded,
                size: 48, color: AppColors.textTertiary),
            const SizedBox(height: 12),
            Text('选择上方分类浏览小说', style: AppTextStyles.caption),
            const SizedBox(height: 4),
            Text('搜索不可用？分类浏览也能找书', style: AppTextStyles.label),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: _categoryBooks.length + 1, // +1 用于加载更多按钮
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, i) {
        if (i == _categoryBooks.length) {
          // 加载更多按钮
          if (_isBrowsing) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppColors.accentRose),
              ),
            );
          }
          if (_hasMore) {
            return Center(
              child: TextButton(
                onPressed: () => _browseCategory(loadMore: true),
                child: Text('加载更多',
                    style: AppTextStyles.caption
                        .copyWith(color: AppColors.accentRose)),
              ),
            );
          }
          return const SizedBox(height: 4);
        }

        final book = _categoryBooks[i];
        return CategoryBookCard(
          book: book,
          onTap: () => _addCategoryBook(book),
        );
      },
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
        return NovelSearchResultCard(
          result: result,
          onTap: () => _addNovel(result),
        );
      },
    );
  }
}
