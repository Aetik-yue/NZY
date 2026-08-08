import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/models/pomodoro_settings.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../shared/widgets/app_snackbar.dart';

/// 番茄钟设置弹层（自定义时长 + 自动开始开关）
///
/// 读取 [pomodoroSettingsProvider] 回填，保存调 repository.save。
/// 设置未加载完成前禁用保存，避免用默认值覆盖用户配置。
class PomodoroSettingsSheet extends ConsumerStatefulWidget {
  const PomodoroSettingsSheet({super.key});

  /// 弹出设置弹层
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppColors.radiusCard)),
      ),
      builder: (_) => const PomodoroSettingsSheet(),
    );
  }

  @override
  ConsumerState<PomodoroSettingsSheet> createState() =>
      _PomodoroSettingsSheetState();
}

class _PomodoroSettingsSheetState
    extends ConsumerState<PomodoroSettingsSheet> {
  // 表单当前值（settings 未加载时以默认值兜底）
  int _focusMin = 25;
  int _shortBreakMin = 5;
  int _longBreakMin = 15;
  int _longBreakInterval = 4;
  bool _autoStartBreak = true;
  bool _autoStartFocus = false;

  /// 设置是否已回填（未回填时禁用保存）
  bool _loaded = false;
  bool _saving = false;
  ProviderSubscription<AsyncValue<PomodoroSettings>>? _sub;

  @override
  void initState() {
    super.initState();
    final s = ref.read(pomodoroSettingsProvider).valueOrNull;
    if (s != null) {
      _apply(s);
    } else {
      // 父页通常已 watch 设置，此处兜底：未加载时监听到达后回填
      _sub = ref.listenManual(
        pomodoroSettingsProvider,
        (_, next) {
          final v = next.valueOrNull;
          if (v != null && !_loaded) {
            _apply(v);
            if (mounted) setState(() {});
          }
        },
        fireImmediately: true,
      );
    }
  }

  @override
  void dispose() {
    _sub?.close();
    super.dispose();
  }

  /// 回填设置到表单字段（首帧前直接赋值，之后由调用方触发刷新）
  void _apply(PomodoroSettings s) {
    _focusMin = s.focusMin;
    _shortBreakMin = s.shortBreakMin;
    _longBreakMin = s.longBreakMin;
    _longBreakInterval = s.longBreakInterval;
    _autoStartBreak = s.autoStartBreak;
    _autoStartFocus = s.autoStartFocus;
    _loaded = true;
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(pomodoroSettingsRepositoryProvider);
      await repo.save(PomodoroSettings()
        ..focusMin = _focusMin
        ..shortBreakMin = _shortBreakMin
        ..longBreakMin = _longBreakMin
        ..longBreakInterval = _longBreakInterval
        ..autoStartBreak = _autoStartBreak
        ..autoStartFocus = _autoStartFocus);
      if (!mounted) return;
      Navigator.of(context).pop();
      AppSnackbar.show(context, '设置已保存');
    } catch (e) {
      debugPrint('[PomodoroSettingsSheet] 保存失败: $e');
      if (mounted) AppSnackbar.show(context, '保存失败，请重试');
    } finally {
      if (mounted) setState(() => _saving = false);
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
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 标题栏
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('番茄钟设置', style: AppTextStyles.titleMedium),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _StepperField(
                label: '专注时长',
                value: _focusMin,
                min: 5,
                max: 90,
                step: 5,
                unit: '分钟',
                onChanged: (v) => setState(() => _focusMin = v),
              ),
              _StepperField(
                label: '短休息',
                value: _shortBreakMin,
                min: 1,
                max: 30,
                step: 1,
                unit: '分钟',
                onChanged: (v) => setState(() => _shortBreakMin = v),
              ),
              _StepperField(
                label: '长休息',
                value: _longBreakMin,
                min: 5,
                max: 60,
                step: 5,
                unit: '分钟',
                onChanged: (v) => setState(() => _longBreakMin = v),
              ),
              _StepperField(
                label: '长休间隔',
                value: _longBreakInterval,
                min: 2,
                max: 8,
                step: 1,
                unit: '个',
                onChanged: (v) => setState(() => _longBreakInterval = v),
              ),
              const SizedBox(height: 4),
              SwitchListTile(
                title: Text('专注后自动开始休息', style: AppTextStyles.body),
                value: _autoStartBreak,
                activeThumbColor: AppColors.accentRose,
                activeTrackColor: AppColors.accentPinkSoft,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _autoStartBreak = v),
              ),
              SwitchListTile(
                title: Text('休息后自动开始专注', style: AppTextStyles.body),
                value: _autoStartFocus,
                activeThumbColor: AppColors.accentRose,
                activeTrackColor: AppColors.accentPinkSoft,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _autoStartFocus = v),
              ),
              const SizedBox(height: 16),
              // 保存按钮（设置未加载完成时禁用，避免默认值覆盖）
              SizedBox(
                width: double.infinity,
                height: 50,
                child: FilledButton(
                  onPressed: (_saving || !_loaded) ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.accentRose,
                    disabledBackgroundColor: AppColors.accentPinkSoft,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppColors.radiusSm),
                    ),
                  ),
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
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

/// 步进器字段（- label value +）
class _StepperField extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final int step;
  final String unit;
  final ValueChanged<int> onChanged;

  const _StepperField({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.step,
    required this.unit,
    required this.onChanged,
  });

  int _clamp(int v) => v < min ? min : (v > max ? max : v);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            child:
                Text('$label（$min-$max $unit）', style: AppTextStyles.body),
          ),
          _stepButton(
            Icons.remove_rounded,
            value > min,
            () => onChanged(_clamp(value - step)),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text('$value $unit',
                style: AppTextStyles.body
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
          _stepButton(
            Icons.add_rounded,
            value < max,
            () => onChanged(_clamp(value + step)),
          ),
        ],
      ),
    );
  }

  Widget _stepButton(IconData icon, bool enabled, VoidCallback onTap) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: enabled ? AppColors.accentRose : AppColors.borderSoft,
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: Colors.white, size: 18),
      ),
    );
  }
}
