import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/memo.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import '../../../../shared/widgets/confirm_dialog.dart';
import 'widgets/todo_fields.dart';
import 'widgets/memo_edit_fields.dart';

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

  // 待办属性：截止日期 / 优先级（新建默认 none + 无截止）
  DateTime? _selectedDueDate;
  TodoPriority _selectedPriority = TodoPriority.none;

  // 加载时的原始内容（用于未保存修改检测）
  String _originalContent = '';
  int _originalAuthor = 1;
  int _originalColor = 0xFFFF8FB1;
  DateTime? _originalDueDate;
  TodoPriority _originalPriority = TodoPriority.none;

  /// 是否存在未保存的修改
  bool get _hasChanges {
    if (!_isEditing) {
      return _controller.text.trim().isNotEmpty;
    }
    return _controller.text != _originalContent ||
        _selectedAuthor != _originalAuthor ||
        _selectedColor != _originalColor ||
        _selectedDueDate != _originalDueDate ||
        _selectedPriority != _originalPriority;
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
      _selectedDueDate = memo.dueDate;
      _selectedPriority = memo.priority;
      _originalContent = memo.content;
      _originalAuthor = memo.author;
      _originalColor = memo.colorValue;
      _originalDueDate = memo.dueDate;
      _originalPriority = memo.priority;
      _loaded = true;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// 防重：保存进行中禁止再次提交
  bool _saving = false;

  Future<void> _save() async {
    final content = _controller.text.trim();
    if (content.isEmpty) {
      AppSnackbar.show(context, '请输入内容');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
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
        memo.dueDate = _selectedDueDate;
        memo.priority = _selectedPriority;
        memo.updatedAt = now;
        await repo.update(memo);
      } else {
        await repo.add(Memo()
          ..content = content
          ..author = _selectedAuthor
          ..isPinned = false
          ..colorValue = _selectedColor
          ..createdAt = now
          ..done = false
          ..dueDate = _selectedDueDate
          ..priority = _selectedPriority);
      }

      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackbar.show(context, _isEditing ? '已保存' : '备忘录已添加 ✨');
    } catch (e) {
      debugPrint('[MemoEditPage] 保存失败: $e');
      if (mounted) AppSnackbar.show(context, '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
    try {
      await repo.delete(memo.id);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackbar.showUndo(context, '已删除', () async {
        try {
          await repo.add(memo);
        } catch (e) {
          debugPrint('[MemoEditPage] 撤销删除失败: $e');
        }
      });
    } catch (e) {
      debugPrint('[MemoEditPage] 删除失败: $e');
      if (mounted) AppSnackbar.show(context, '删除失败，请重试');
    }
  }

  /// 拦截返回：有未保存修改时询问
  Future<void> _handlePopInvoked(bool didPop) async {
    if (didPop || !_hasChanges) return;
    if (await showDiscardChangesDialog(context) && mounted) {
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
                    // 作者选择器（仅新建时）
                    if (!_isEditing) ...[
                      AuthorSelector(
                        value: _selectedAuthor,
                        onChanged: (a) =>
                            setState(() => _selectedAuthor = a),
                      ),
                      const SizedBox(height: 16),
                    ],
                    // 颜色选择
                    ColorSelector(
                      value: _selectedColor,
                      onChanged: (c) =>
                          setState(() => _selectedColor = c),
                    ),
                    const SizedBox(height: 16),
                    // 截止日期选择
                    DueDateField(
                      value: _selectedDueDate,
                      onChanged: (d) =>
                          setState(() => _selectedDueDate = d),
                    ),
                    const SizedBox(height: 16),
                    // 优先级选择
                    PriorityField(
                      value: _selectedPriority,
                      onChanged: (p) =>
                          setState(() => _selectedPriority = p),
                    ),
                    const SizedBox(height: 16),
                    // 输入框
                    ContentTextField(
                      controller: _controller,
                      autofocus: !_isEditing,
                      onChanged: () => setState(() {}),
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
