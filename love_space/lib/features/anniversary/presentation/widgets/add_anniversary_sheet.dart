import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/anniversary.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';

/// 预定义标记色（存 ARGB 整型，取自设计令牌调色板）
final List<int> _presetColorValues = [
  AppColors.accentRose.toARGB32(),
  AppColors.accentPink.toARGB32(),
  AppColors.accentCoral.toARGB32(),
  AppColors.accentPeach.toARGB32(),
  AppColors.accentMauve.toARGB32(),
];

/// 添加/编辑纪念日的底部弹出表单
///
/// [initial] 传入时进入编辑模式（回填并走 update 保存）。
class AddAnniversarySheet extends ConsumerStatefulWidget {
  final Anniversary? initial;
  const AddAnniversarySheet({super.key, this.initial});

  /// 弹出表单的便捷方法
  static Future<void> show(BuildContext context, {Anniversary? initial}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppColors.radiusCard)),
      ),
      builder: (_) => AddAnniversarySheet(initial: initial),
    );
  }

  @override
  ConsumerState<AddAnniversarySheet> createState() =>
      _AddAnniversarySheetState();
}

class _AddAnniversarySheetState extends ConsumerState<AddAnniversarySheet> {
  final _titleController = TextEditingController();
  final _noteController = TextEditingController();
  late DateTime _selectedDate;
  int _selectedColorValue = _presetColorValues.first;
  bool _remindEnabled = false;
  int _remindDays = 3;
  bool _isSubmitting = false;

  bool get _isEditing => widget.initial != null;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    if (initial != null) {
      _titleController.text = initial.title;
      _noteController.text = initial.note;
      _selectedDate = initial.date;
      // 匹配预设颜色（未命中用第一个）
      final idx = _presetColorValues.indexOf(initial.colorValue);
      _selectedColorValue =
          idx >= 0 ? _presetColorValues[idx] : _presetColorValues.first;
      _remindEnabled = initial.remindEnabled;
      _remindDays = initial.remindDays;
    } else {
      _selectedDate = DateTime.now();
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 10, 12, 31),
      helpText: '选择纪念日日期',
      cancelText: '取消',
      confirmText: '确定',
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submit() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      AppSnackbar.show(context, '请输入纪念日名称');
      return;
    }
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(anniversaryRepositoryProvider);
      if (_isEditing) {
        final item = widget.initial!
          ..title = title
          ..date = _selectedDate
          ..note = _noteController.text.trim()
          ..colorValue = _selectedColorValue
          ..remindEnabled = _remindEnabled
          ..remindDays = _remindDays;
        await repo.update(item);
      } else {
        await repo.add(Anniversary()
          ..title = title
          ..date = _selectedDate
          ..note = _noteController.text.trim()
          ..colorValue = _selectedColorValue
          ..remindEnabled = _remindEnabled
          ..remindDays = _remindDays
          ..createdAt = DateTime.now());
      }
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackbar.show(context, _isEditing ? '纪念日已更新 💕' : '纪念日已添加 💕');
    } catch (e) {
      debugPrint('[AddAnniversarySheet] 保存失败: $e');
      if (mounted) AppSnackbar.show(context, '保存失败，请重试');
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
                  Text(_isEditing ? '编辑纪念日' : '添加纪念日',
                      style: AppTextStyles.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // 名称输入
              TextField(
                controller: _titleController,
                decoration: InputDecoration(
                  labelText: '名称',
                  hintText: '例如：我们在一起 / 你的生日',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    borderSide:
                        const BorderSide(color: AppColors.accentRose),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 日期选择
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppColors.borderSoft),
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today_rounded,
                          size: 20, color: AppColors.accentRose),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          '${_selectedDate.year}年${_selectedDate.month}月${_selectedDate.day}日',
                          style: AppTextStyles.body,
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded,
                          size: 20, color: AppColors.textTertiary),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 备注输入
              TextField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '记录这个日子的意义...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    borderSide:
                        const BorderSide(color: AppColors.accentRose),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 标记色
              Text('标记颜色', style: AppTextStyles.label),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final colorValue in _presetColorValues)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _selectedColorValue = colorValue),
                        child: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: Color(colorValue),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedColorValue == colorValue
                                  ? AppColors.textPrimary
                                  : Colors.transparent,
                              width: 2,
                            ),
                          ),
                          child: _selectedColorValue == colorValue
                              ? const Icon(Icons.check,
                                  color: Colors.white, size: 18)
                              : null,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),

              // 提前提醒
              Row(
                children: [
                  Expanded(
                    child: Text('提前提醒', style: AppTextStyles.body),
                  ),
                  Switch(
                    value: _remindEnabled,
                    activeThumbColor: AppColors.accentRose,
                    activeTrackColor: AppColors.accentPinkSoft,
                    onChanged: (v) =>
                        setState(() => _remindEnabled = v),
                  ),
                ],
              ),
              if (_remindEnabled) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Expanded(
                      child: Text('提前天数', style: AppTextStyles.bodySmall),
                    ),
                    for (final days in [0, 3, 7])
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: ChoiceChip(
                          label: Text(days == 0 ? '当天' : '$days 天'),
                          selected: _remindDays == days,
                          onSelected: (_) =>
                              setState(() => _remindDays = days),
                          selectedColor: AppColors.accentRose,
                          labelStyle: AppTextStyles.label.copyWith(
                            color: _remindDays == days
                                ? Colors.white
                                : AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
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
