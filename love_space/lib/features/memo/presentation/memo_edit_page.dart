import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/memo.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';

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

  static const _presetColors = [
    0xFFFF6B9D, // accentRose
    0xFFFF8FB1, // accentPink
    0xFFFFD1BF, // accentPeach
    0xFFB57DBA, // accentMauve
  ];

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
    if (memo != null && mounted) {
      setState(() {
        _controller.text = memo.content;
        _selectedAuthor = memo.author;
        _selectedColor = memo.colorValue;
        _loaded = true;
      });
    }
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
      if (memo != null) {
        memo.content = content;
        memo.colorValue = _selectedColor;
        memo.updatedAt = now;
        await repo.update(memo);
      }
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

  @override
  Widget build(BuildContext context) {
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
        title: Text(_isEditing ? '编辑备忘录' : '新建备忘录',
            style: AppTextStyles.titleMedium),
        centerTitle: true,
        actions: [
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
    // 输入框
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        autofocus: !_isEditing,
                        maxLines: null,
                        expands: true,
                        textAlignVertical: TextAlignVertical.top,
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
    );
  }
}
