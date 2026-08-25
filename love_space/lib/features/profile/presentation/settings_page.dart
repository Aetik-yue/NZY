import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/models/app_settings.dart';
import '../../../data/providers/data_providers.dart';
import '../../../shared/utils/image_picker_helper.dart';
import '../../../shared/widgets/app_snackbar.dart';
import 'widgets/settings_widgets.dart';

/// 情侣信息、纪念起始日、主页封面和隐私显示设置。
class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  final _name1Controller = TextEditingController();
  final _name2Controller = TextEditingController();
  DateTime? _togetherSince;
  String? _profileCoverPath;
  bool _hideDays = false;
  bool _loaded = false;
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
      _profileCoverPath = settings.profileCoverPath;
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

  Future<void> _pickCover() async {
    final path = await ImagePickerHelper.pickFromGallery();
    if (path != null && mounted) setState(() => _profileCoverPath = path);
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
      final repository = ref.read(settingsRepositoryProvider);
      final existing = await repository.get();
      final settings = existing ?? AppSettings();
      settings
        ..partner1Name = name1
        ..partner2Name = name2
        ..togetherSince = _togetherSince ?? DateTime.now()
        ..profileCoverPath = _profileCoverPath
        ..hideDaysTogether = _hideDays;
      await repository.save(settings);
      if (!mounted) return;
      AppSnackbar.show(context, '设置已保存');
      Navigator.of(context).pop();
    } catch (error) {
      debugPrint('[SettingsPage] 保存失败: $error');
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
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('设置', style: AppTextStyles.titleMedium),
        centerTitle: true,
      ),
      body: _loaded
          ? ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
              children: [
                const SettingsIntroCard(),
                const SizedBox(height: 16),
                SettingsSection(
                  icon: Icons.people_alt_rounded,
                  title: '情侣信息',
                  subtitle: '这些昵称会显示在主页和互动功能中',
                  children: [
                    SettingsNameField(
                      controller: _name1Controller,
                      label: '我的昵称',
                      hint: '例如：小越',
                    ),
                    const SizedBox(height: 12),
                    SettingsNameField(
                      controller: _name2Controller,
                      label: 'TA 的昵称',
                      hint: '例如：小名',
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SettingsSection(
                  icon: Icons.event_rounded,
                  title: '重要日期',
                  subtitle: '用于计算相伴天数和周年问候',
                  children: [
                    SettingsValueRow(
                      icon: Icons.favorite_rounded,
                      title: '在一起的起始日期',
                      subtitle: '从这一天开始记录相伴时间',
                      value: _formatDate(_togetherSince),
                      onTap: _pickDate,
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                SettingsSection(
                  icon: Icons.wallpaper_rounded,
                  title: '主页显示',
                  subtitle: '调整「我的」页封面和隐私信息',
                  children: [
                    SettingsCoverRow(
                      path: _profileCoverPath,
                      onPick: _pickCover,
                      onReset: () => setState(() => _profileCoverPath = null),
                    ),
                    const Divider(height: 24),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text('隐藏相伴天数', style: AppTextStyles.body),
                      subtitle:
                          Text('首页和「我的」页不显示具体天数', style: AppTextStyles.caption),
                      value: _hideDays,
                      activeThumbColor: AppColors.accentRose,
                      activeTrackColor: AppColors.accentPinkSoft,
                      onChanged: (value) => setState(() => _hideDays = value),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 52,
                  child: FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.accentRose,
                      foregroundColor: AppColors.textOnPink,
                      shape: const StadiumBorder(),
                    ),
                    child: Text(_saving ? '保存中…' : '保存设置',
                        style: AppTextStyles.onPink),
                  ),
                ),
              ],
            )
          : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '未设置';
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}.$month.$day';
  }
}
