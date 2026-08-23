import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/timeline_event.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';

/// 预设颜色（与设计令牌保持一致）
const _presetColors = [
  AppColors.accentRose,
  AppColors.accentPink,
  AppColors.accentCoral,
  AppColors.accentMauve,
];

/// 添加/编辑时间轴事件的底部弹出表单
///
/// [initial] 传入时进入编辑模式（回填并走 update 保存）。
class AddTimelineSheet extends ConsumerStatefulWidget {
  final TimelineEvent? initial;
  const AddTimelineSheet({super.key, this.initial});

  /// 弹出表单的便捷方法
  static Future<void> show(BuildContext context, {TimelineEvent? initial}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppColors.radiusCard)),
      ),
      builder: (_) => AddTimelineSheet(initial: initial),
    );
  }

  @override
  ConsumerState<AddTimelineSheet> createState() => _AddTimelineSheetState();
}

class _AddTimelineSheetState extends ConsumerState<AddTimelineSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  late DateTime _selectedDate;
  int _selectedColorIndex = 0;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _selectedDate = initial.date;
      _titleController.text = initial.title;
      _descController.text = initial.description;
      // 匹配预设颜色（未命中则用第 0 个）
      _selectedColorIndex = _presetColors.indexWhere(
        (c) => c.toARGB32() == initial.dotColorValue,
      );
      if (_selectedColorIndex < 0) _selectedColorIndex = 0;
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      helpText: '选择日期',
      cancelText: '取消',
      confirmText: '确认',
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      AppSnackbar.show(context, '请输入标题');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(timelineRepositoryProvider);
      if (_isEditing) {
        // 编辑模式：复用原条目 id，走 update
        final event = widget.initial!
          ..date = _selectedDate
          ..title = title
          ..description = _descController.text.trim()
          ..dotColorValue = _presetColors[_selectedColorIndex].toARGB32();
        await repo.update(event);
      } else {
        final event = TimelineEvent()
          ..date = _selectedDate
          ..title = title
          ..description = _descController.text.trim()
          ..dotColorValue = _presetColors[_selectedColorIndex].toARGB32();
        await repo.add(event);
      }

      if (mounted) {
        Navigator.of(context).pop();
        AppSnackbar.show(context, _isEditing ? '时光已更新 💕' : '时光已记录 💕');
      }
    } catch (e) {
      debugPrint('[AddTimelineSheet] 保存失败: $e');
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
                  Text(_isEditing ? '编辑时光' : '记录时光',
                      style: AppTextStyles.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 日期选择
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderSoft),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 20, color: AppColors.accentRose),
                      const SizedBox(width: 12),
                      Text(
                        '${_selectedDate.year}.${_selectedDate.month.toString().padLeft(2, '0')}.${_selectedDate.day.toString().padLeft(2, '0')}',
                        style: AppTextStyles.body,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 标题输入
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '标题',
                  hintText: '例如：第一次旅行',
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
                  hintText: '记录这个美好的时刻...',
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

              // 颜色选择
              Text('标记颜色', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Row(
                children: List.generate(_presetColors.length, (i) {
                  final isSelected = i == _selectedColorIndex;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedColorIndex = i),
                    child: Container(
                      width: 36,
                      height: 36,
                      margin: const EdgeInsets.only(right: 12),
                      decoration: BoxDecoration(
                        color: _presetColors[i],
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: Colors.white, width: 3)
                            : null,
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                    color:
                                        _presetColors[i].withValues(alpha: 0.4),
                                    blurRadius: 8)
                              ]
                            : null,
                      ),
                      child: isSelected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
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
