import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/wish.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';

/// 预定义图标列表
const _presetIcons = [
  Icons.flight_rounded,
  Icons.cake_rounded,
  Icons.pets_rounded,
  Icons.star_rounded,
  Icons.favorite_rounded,
  Icons.home_rounded,
  Icons.wb_sunny_rounded,
  Icons.music_note_rounded,
  Icons.menu_book_rounded,
  Icons.photo_camera_rounded,
  Icons.directions_bike_rounded,
  Icons.celebration_rounded,
];

/// 添加愿望的底部弹出表单
class AddWishSheet extends ConsumerStatefulWidget {
  const AddWishSheet({super.key});

  /// 弹出表单的便捷方法
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddWishSheet(),
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
      final wish = Wish()
        ..title = title
        ..description = _descController.text.trim()
        ..iconCodePoint = _presetIcons[_selectedIconIndex].codePoint
        ..done = false
        ..createdAt = DateTime.now();

      await ref.read(wishRepositoryProvider).add(wish);

      if (mounted) {
        Navigator.of(context).pop();
        AppSnackbar.show(context, '愿望已添加 ✨');
      }
    } catch (_) {
      if (mounted) {
        AppSnackbar.show(context, '添加失败，请重试');
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
                  Text('添加愿望', style: AppTextStyles.titleMedium),
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
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
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
                    borderRadius: BorderRadius.circular(14),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
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
                        borderRadius: BorderRadius.circular(12),
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
                      borderRadius: BorderRadius.circular(14),
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
                      : const Text('保存', style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
