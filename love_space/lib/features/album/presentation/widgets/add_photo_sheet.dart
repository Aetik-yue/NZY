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

/// 添加/编辑照片的底部弹出表单
///
/// [initial] 传入时进入编辑模式（回填并走 update 保存），
/// 编辑成功后 pop 返回更新后的 [AlbumPhoto]。
class AddPhotoSheet extends ConsumerStatefulWidget {
  final AlbumPhoto? initial;
  const AddPhotoSheet({super.key, this.initial});

  /// 弹出表单的便捷方法；编辑模式下返回更新后的照片
  static Future<AlbumPhoto?> show(
    BuildContext context, {
    AlbumPhoto? initial,
  }) {
    return showModalBottomSheet<AlbumPhoto>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AddPhotoSheet(initial: initial),
    );
  }

  @override
  ConsumerState<AddPhotoSheet> createState() => _AddPhotoSheetState();
}

class _AddPhotoSheetState extends ConsumerState<AddPhotoSheet> {
  String? _imagePath;
  PhotoCategory _selectedCategory = PhotoCategory.daily;
  bool _isSubmitting = false;
  DateTime _selectedDate = DateTime.now();
  int _gradientIndex = 0;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      // 编辑模式：回填
      _imagePath = initial.filePath;
      _selectedCategory = initial.category;
      _selectedDate = initial.date;
      _gradientIndex = initial.gradientIndex;
    } else {
      // 随机渐变色，让每张照片视觉有区别
      _gradientIndex =
          DateTime.now().millisecondsSinceEpoch % AppColors.coverGradients.length;
    }
  }

  Future<void> _pickImage() async {
    final path = await ImagePickerHelper.pickImage(context);
    if (path != null && mounted) {
      setState(() => _imagePath = path);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2010),
      lastDate: now,
      confirmText: '确定',
      cancelText: '取消',
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    if (_imagePath == null) {
      AppSnackbar.show(context, '请先选择一张照片');
      return;
    }
    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(albumRepositoryProvider);
      if (_isEditing) {
        final photo = widget.initial!
          ..date = _selectedDate
          ..category = _selectedCategory
          ..filePath = _imagePath
          ..gradientIndex = _gradientIndex;
        await repo.update(photo);
        if (mounted) {
          Navigator.of(context).pop(photo); // 返回更新后的照片
          AppSnackbar.show(context, '照片已更新 📷');
        }
      } else {
        final photo = AlbumPhoto()
          ..date = _selectedDate
          ..category = _selectedCategory
          ..filePath = _imagePath
          ..gradientIndex = _gradientIndex;

        await repo.add(photo);

        if (mounted) {
          Navigator.of(context).pop();
          AppSnackbar.show(context, '照片已添加 📷');
        }
      }
    } catch (e) {
      debugPrint('[AddPhotoSheet] 保存失败: $e');
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
                  Text(_isEditing ? '编辑照片' : '添加照片',
                      style: AppTextStyles.titleMedium),
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
                    borderRadius: BorderRadius.circular(AppColors.radiusMd),
                    border: Border.all(color: AppColors.borderSoft, style: BorderStyle.solid),
                  ),
                  child: _imagePath != null
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(AppColors.radiusMd),
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
              const SizedBox(height: 16),

              // 日期选择
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.bgCream,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 18, color: AppColors.accentRose),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _formatDate(_selectedDate),
                          style: AppTextStyles.body,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 20, color: AppColors.textTertiary),
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
                          borderRadius: BorderRadius.circular(AppColors.radiusSm),
                          border: Border.all(
                            color: isSelected ? AppColors.accentRose : AppColors.borderSoft,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(cat.$3,
                                color: isSelected ? Colors.white : AppColors.accentRose),
                            const SizedBox(height: 4),
                            Text(cat.$2,
                                style: AppTextStyles.caption.copyWith(
                                  color: isSelected
                                      ? Colors.white
                                      : AppColors.textSecondary,
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

  String _formatDate(DateTime d) =>
      '${d.year}年${d.month}月${d.day}日';
}
