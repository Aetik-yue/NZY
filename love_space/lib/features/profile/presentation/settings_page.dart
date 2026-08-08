import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/providers/data_providers.dart';
import '../../../shared/widgets/app_snackbar.dart';

/// 设置页（二级页）
///
/// 编辑双方昵称、在一起的起始日期、隐私开关（隐藏在一起天数）。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _name1Controller = TextEditingController();
  final _name2Controller = TextEditingController();
  DateTime? _togetherSince;
  bool _hideDays = false;
  bool _loaded = false;

  /// 防重：保存进行中禁止再次提交
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final settings = await ref.read(settingsRepositoryProvider).get();
    if (!mounted) return;
    if (settings != null) {
      _name1Controller.text = settings.partner1Name;
      _name2Controller.text = settings.partner2Name;
      _togetherSince = settings.togetherSince;
      _hideDays = settings.hideDaysTogether;
    }
    setState(() => _loaded = true);
  }

  @override
  void dispose() {
    _name1Controller.dispose();
    _name2Controller.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _togetherSince ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      confirmText: '确定',
      cancelText: '取消',
    );
    if (picked != null) setState(() => _togetherSince = picked);
  }

  Future<void> _save() async {
    final name1 = _name1Controller.text.trim();
    final name2 = _name2Controller.text.trim();
    if (name1.isEmpty || name2.isEmpty) {
      AppSnackbar.show(context, '昵称不能为空');
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(settingsRepositoryProvider);
      // 复用已有单例行，避免插入重复行；显式 if/else 避免级联优先级误读
      final existing = await repo.get();
      if (existing != null) {
        existing
          ..partner1Name = name1
          ..partner2Name = name2
          ..togetherSince = _togetherSince ?? existing.togetherSince
          ..hideDaysTogether = _hideDays;
        await repo.save(existing);
      } else {
        final settings = AppSettings()
          ..partner1Name = name1
          ..partner2Name = name2
          ..togetherSince = _togetherSince ?? DateTime.now();
        await repo.save(settings);
      }
      if (!mounted) return;
      AppSnackbar.show(context, '设置已保存 💕');
      Navigator.of(context).pop();
    } catch (e) {
      debugPrint('[SettingsPage] 保存失败: $e');
      if (mounted) AppSnackbar.show(context, '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
        title: Text('设置', style: AppTextStyles.titleMedium),
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
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                _sectionTitle('情侣信息'),
                const SizedBox(height: 8),
                _inputField(_name1Controller, '我的昵称', '例如：小越'),
                const SizedBox(height: 12),
                _inputField(_name2Controller, 'TA 的昵称', '例如：小名'),
                const SizedBox(height: 20),
                _sectionTitle('纪念日'),
                const SizedBox(height: 8),
                // 起始日期
                GestureDetector(
                  onTap: _pickDate,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppColors.bgCard,
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
                            '在一起的起始日期',
                            style: AppTextStyles.body,
                          ),
                        ),
                        Text(
                          _formatDate(_togetherSince),
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.accentRose,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                _sectionTitle('隐私'),
                const SizedBox(height: 8),
                // 隐私开关
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(AppColors.radiusSm),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('隐藏在一起天数', style: AppTextStyles.body),
                    subtitle: Text('在首页和「我的」页不显示相伴天数',
                        style: AppTextStyles.caption),
                    value: _hideDays,
                    activeThumbColor: AppColors.accentRose,
                    activeTrackColor: AppColors.accentPinkSoft,
                    onChanged: (v) => setState(() => _hideDays = v),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(title, style: AppTextStyles.titleSmall);
  }

  Widget _inputField(
    TextEditingController controller,
    String label,
    String hint,
  ) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: AppColors.bgCard,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
          borderSide: const BorderSide(color: AppColors.accentRose),
        ),
      ),
    );
  }

  String _formatDate(DateTime? d) {
    if (d == null) return '未设置';
    return '${d.year}.${d.month.toString().padLeft(2, '0')}.${d.day.toString().padLeft(2, '0')}';
  }
}
