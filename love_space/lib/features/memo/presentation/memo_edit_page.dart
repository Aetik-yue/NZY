import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/memo.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/confirm_dialog.dart';

/// 备忘录编辑/新建页
///
/// - 新建：memoId = null
/// - 编辑：memoId 传入现有备忘录 id
class MemoEditPage extends ConsumerStatefulWidget {
  final int? memoId;
  const MemoEditPage({super.key, this.memoId});

  @override
  ConsumerState<MemoEditPage> createState() => _MemoEditPageState();
}

class _MemoEditPageState extends ConsumerState<MemoEditPage> {
  late final TextEditingController _controller;
  int _selectedAuthor = 1;
  int _selectedColor = 0xFFFF8FB1;
  bool _isEditing = false;
  bool _loaded = false;

  // 加载时的原始内容（用于未保存修改检测）
  String _originalContent = '';
  int _originalAuthor = 1;
  int _originalColor = 0xFFFF8FB1;

  static const _presetColors = [
    0xFFFF6B9D, // accentRose
    0xFFFF8FB1, // accentPink
    0xFFFFD1BF, // accentPeach
    0xFFB57DBA, // accentMauve
  ];

  /// 是否存在未保存的修改
  bool get _hasChanges {
    if (!_isEditing) {
      return _controller.text.trim().isNotEmpty;
    }
    return _controller.text != _originalContent ||
        _selectedAuthor != _originalAuthor ||
        _selectedColor != _originalColor;
  }

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController();
    _isEditing = widget.memoId != null;
    if (_isEditing) {
      _loadMemo();
    } else {
      _loaded = true;
    }
  }

  Future<void> _loadMemo() async {
    final repo = ref.read(memoRepositoryProvider);
    final memo = await repo.getById(widget.memoId!);
    if (!mounted) return;
    if (memo == null) {
      // 条目已被删除：提示并返回，避免页面永久卡在加载态
      AppSnackbar.show(context, '内容已不存在');
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _controller.text = memo.content;
      _selectedAuthor = memo.author;
      _selectedColor = memo.colorValue;
      _originalContent = memo.content;
      _originalAuthor = memo.author;
      _originalColor = memo.colorValue;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      AppSnackbar.show(context, '请输入内容');
      return;
    }
    final repo = ref.read(memoRepositoryProvider);
    final now = DateTime.now();

    if (_isEditing) {
      final memo = await repo.getById(widget.memoId!);
      if (memo == null) {
        // 条目已被删除：提示并返回，不静默丢弃内容
        if (mounted) {
          AppSnackbar.show(context, '内容已不存在，无法保存');
          Navigator.of(context).pop();
        }
        return;
      }
      memo.content = content;
      memo.colorValue = _selectedColor;
      memo.updatedAt = now;
      await repo.update(memo);
    } else {
      await repo.add(Memo()
        ..content = content
        ..author = _selectedAuthor
        ..isPinned = false
        ..colorValue = _selectedColor
        ..createdAt = now);
    }

    if (mounted) Navigator.of(context).pop();
  }

  /// 删除当前备忘录（确认 + 撤销）
  Future<void> _deleteMemo() async {
    final confirmed = await showConfirmDeleteDialog(
      context,
      content: '确定要删除这条备忘录吗？',
    );
    if (!confirmed || !mounted) return;
    final repo = ref.read(memoRepositoryProvider);
    final memo = await repo.getById(widget.memoId!);
    if (!mounted) return;
    if (memo == null) {
      AppSnackbar.show(context, '内容已不存在');
      Navigator.of(context).pop();
      return;
    }
    await repo.delete(memo.id);
    if (!mounted) return;
    Navigator.of(context).pop();
    AppSnackbar.showUndo(context, '已删除', () async {
      await repo.add(memo);
    });
  }

  /// 拦截返回：有未保存修改时询问
  Future<void> _handlePopInvoked(bool didPop) async {
    if (didPop || !_hasChanges) return;
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('放弃修改？'),
        content: const Text('当前内容尚未保存，确定要离开吗？'),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('继续编辑'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRose,
            ),
            child: const Text('放弃'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // 有未保存修改时拦截返回，弹确认
      canPop: !_hasChanges,
      onPopInvokedWithResult: (didPop, _) => _handlePopInvoked(didPop),
      child: Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.textPrimary),
          // 必须用 maybePop：强制 pop 会绕过 PopScope 的未保存拦截
          onPressed: () => Navigator.of(context).maybePop(),
        ),
        title: Text(_isEditing ? '编辑备忘录' : '新建备忘录',
            style: AppTextStyles.titleMedium),
        centerTitle: true,
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete_outline,
                  color: AppColors.accentRose),
              tooltip: '删除',
              onPressed: _deleteMemo,
            ),
          TextButton(
            onPressed: _save,
            child: Text(
              '保存',
              style: AppTextStyles.body.copyWith(
                color: AppColors.accentRose,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: _loaded
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 作者选择器
                    if (!_isEditing) ...[
                      Text('作者', style: AppTextStyles.label),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var author = 1; author <= 2; author++)
                            Padding(
                              padding: const EdgeInsets.only(right: 12),
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _selectedAuthor = author),
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: _selectedAuthor == author
                                        ? (author == 1
                                            ? AppColors.accentRose
                                            : AppColors.accentPeach)
                                        : AppColors.bgCard,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: _selectedAuthor == author
                                          ? Colors.transparent
                                          : AppColors.borderSoft,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      author == 1 ? '越' : '名',
                                      style: TextStyle(
                                        color: _selectedAuthor == author
                                            ? Colors.white
                                            : AppColors.textSecondary,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],
                    // 颜色选择
                    Text('颜色', style: AppTextStyles.label),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final color in _presetColors)
                          Padding(
                            padding: const EdgeInsets.only(right: 12),
                            child: GestureDetector(
                              onTap: () =>
                                  setState(() => _selectedColor = color),
                              child: Container(
                                width: 32,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: Color(color),
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: _selectedColor == color
                                        ? AppColors.textPrimary
                                        : Colors.transparent,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // 输入框
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: !_isEditing,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
                        // 触发重建以更新 PopScope.canPop（未保存拦截）
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          hintText: '记录你的想法...#标签',
                          hintStyle: AppTextStyles.body.copyWith(
                            color: AppColors.textTertiary,
                          ),
                          border: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusMd),
                            borderSide:
                                const BorderSide(color: AppColors.borderSoft),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusMd),
                            borderSide:
                                const BorderSide(color: AppColors.borderSoft),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius:
                                BorderRadius.circular(AppColors.radiusMd),
                            borderSide: const BorderSide(
                                color: AppColors.accentRose),
                          ),
                          contentPadding: const EdgeInsets.all(14),
                          filled: true,
                          fillColor: AppColors.bgCard,
                        ),
                        style: AppTextStyles.body,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text('提示：使用 #标签名 添加标签，如 #旅行 #计划',
                        style: AppTextStyles.label),
                  ],
                ),
              ),
            )
          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
    );
  }
}
