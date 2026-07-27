import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/album_photo.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../shared/utils/image_picker_helper.dart';
import '../../../../shared/widgets/app_snackbar.dart';

/// 照片分类选项
const _categories = [
  (PhotoCategory.travel, '旅行', Icons.flight_rounded),
  (PhotoCategory.food, '美食', Icons.restaurant_rounded),
  (PhotoCategory.daily, '日常', Icons.wb_sunny_rounded),
];

/// 添加照片的底部弹出表单
class AddPhotoSheet extends ConsumerStatefulWidget {
  const AddPhotoSheet({super.key});

  /// 弹出表单的便捷方法
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const AddPhotoSheet(),
    );
  }

  @override
  ConsumerState<AddPhotoSheet> createState() => _AddPhotoSheetState();
}

class _AddPhotoSheetState extends ConsumerState<AddPhotoSheet> {
  String? _imagePath;
  PhotoCategory _selectedCategory = PhotoCategory.daily;
  bool _isSubmitting = false;

  Future<void> _pickImage() async {
    final path = await ImagePickerHelper.pickImage(context);
    if (path != null && mounted) {
      setState(() => _imagePath = path);
    }
  }

  Future<void> _submit() async {
    if (_imagePath == null) {
      AppSnackbar.show(context, '请先选择一张照片');
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final photo = AlbumPhoto()
        ..date = DateTime.now()
        ..category = _selectedCategory
        ..filePath = _imagePath
        ..gradientIndex = 0;

      await ref.read(albumRepositoryProvider).add(photo);

      if (mounted) {
        Navigator.of(context).pop();
        AppSnackbar.show(context, '照片已添加 📷');
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
                  Text('添加照片', style: AppTextStyles.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 图片选择区域
              GestureDetector(
                onTap: _pickImage,
                child: Container(
                  width: double.infinity,
                  height: 180,
                  decoration: BoxDecoration(
                    color: AppColors.accentPinkSoft.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.borderSoft, style: BorderStyle.solid),
                  ),
                  child: _imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.file(
                            File(_imagePath!),
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => const Center(
                              child: Icon(Icons.image, size: 48, color: AppColors.textTertiary),
                            ),
                          ),
                        )
                      : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.add_photo_alternate_rounded,
                                size: 48, color: AppColors.accentRose),
                            const SizedBox(height: 8),
                            Text('点击选择照片', style: AppTextStyles.caption),
                          ],
                        ),
                ),
              ),
              const SizedBox(height: 20),

              // 分类选择
              Text('选择分类', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Row(
                children: _categories.map((cat) {
                  final isSelected = cat.$1 == _selectedCategory;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => setState(() => _selectedCategory = cat.$1),
                      child: Container(
                        margin: const EdgeInsets.only(right: 8),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.accentRose
                              : AppColors.bgCard,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isSelected ? AppColors.accentRose : AppColors.borderSoft,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(cat.$2 == '旅行' ? Icons.flight_rounded :
                                 cat.$2 == '美食' ? Icons.restaurant_rounded :
                                 Icons.wb_sunny_rounded,
                                color: isSelected ? Colors.white : AppColors.accentRose),
                            const SizedBox(height: 4),
                            Text(cat.$2,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isSelected ? Colors.white : AppColors.textSecondary,
                                )),
                          ],
                        ),
                      ),
                    ),
                  );
                }).toList(),
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
