import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/wish.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';
import 'wish_icons.dart';

/// 预定义图标列表（与 wish_icons 共享常量）
const _presetIcons = kPresetWishIcons;

/// 添加/编辑愿望的底部弹出表单
///
/// [initial] 传入时进入编辑模式（回填并走 update 保存）。
class AddWishSheet extends ConsumerStatefulWidget {
  final Wish? initial;
  const AddWishSheet({super.key, this.initial});

  /// 弹出表单的便捷方法
  static Future<void> show(BuildContext context, {Wish? initial}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppColors.radiusCard)),
      ),
      builder: (_) => AddWishSheet(initial: initial),
    );
  }

  @override
  ConsumerState<AddWishSheet> createState() => _AddWishSheetState();
}

class _AddWishSheetState extends ConsumerState<AddWishSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  int _selectedIconIndex = 0;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _titleController.text = initial.title;
      _descController.text = initial.description;
      // 匹配预设图标（未命中则用第 0 个）
      _selectedIconIndex = _presetIcons.indexWhere(
        (icon) => icon.codePoint == initial.iconCodePoint,
      );
      if (_selectedIconIndex < 0) _selectedIconIndex = 0;
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      AppSnackbar.show(context, '请输入愿望标题');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(wishRepositoryProvider);
      if (_isEditing) {
        final wish = widget.initial!
          ..title = title
          ..description = _descController.text.trim()
          ..iconCodePoint = _presetIcons[_selectedIconIndex].codePoint;
        await repo.update(wish);
      } else {
        final wish = Wish()
          ..title = title
          ..description = _descController.text.trim()
          ..iconCodePoint = _presetIcons[_selectedIconIndex].codePoint
          ..done = false
          ..createdAt = DateTime.now();
        await repo.add(wish);
      }

      if (mounted) {
        Navigator.of(context).pop();
        AppSnackbar.show(context, _isEditing ? '愿望已更新 ✨' : '愿望已添加 ✨');
      }
    } catch (e) {
      debugPrint('[AddWishSheet] 保存失败: $e');
      if (mounted) {
        AppSnackbar.show(context, '保存失败，请重试');
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_isEditing ? '编辑愿望' : '添加愿望',
                      style: AppTextStyles.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 标题输入
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '愿望标题',
                  hintText: '例如：一起去北海道看雪',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    borderSide: const BorderSide(color: AppColors.accentRose),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 描述输入
              TextField(
                controller: _descController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: '描述（可选）',
                  hintText: '添加一些细节...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    borderSide: const BorderSide(color: AppColors.accentRose),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 图标选择
              Text('选择图标', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: List.generate(_presetIcons.length, (i) {
                  final isSelected = i == _selectedIconIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedIconIndex = i),
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? AppColors.accentRose
                            : AppColors.accentPinkSoft,
                        borderRadius: BorderRadius.circular(AppColors.radiusSm),
                      ),
                      child: Icon(
                        _presetIcons[i],
                        color: isSelected ? Colors.white : AppColors.accentRose,
                        size: 22,
                      ),
                    ),
                  );
                }),
              ),
              const SizedBox(height: 24),

              // 提交按钮
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentRose,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text('保存',
                          style: AppTextStyles.onPink.copyWith(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
