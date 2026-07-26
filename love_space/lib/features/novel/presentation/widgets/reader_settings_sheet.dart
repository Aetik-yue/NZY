import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../../../data/providers/data_providers.dart';
import '../../../../data/models/reader_settings.dart';

/// 阅读设置底部面板
///
/// 调整字号 / 行距 / 翻页模式 / 背景主题 / 常亮，改动即写回 ReaderSettings，
/// 阅读页通过 readerSettingsProvider 自动刷新。
class ReaderSettingsSheet extends ConsumerStatefulWidget {
  const ReaderSettingsSheet({super.key});

  /// 弹出设置面板
  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const ReaderSettingsSheet(),
    );
  }

  @override
  ConsumerState<ReaderSettingsSheet> createState() =>
      _ReaderSettingsSheetState();
}

class _ReaderSettingsSheetState extends ConsumerState<ReaderSettingsSheet> {
  double _fontSize = 18;
  double _lineHeight = 1.6;
  int _pageMode = 0;
  int _bgTheme = 0;
  bool _keepScreenOn = true;
  bool _initialized = false;

  void _syncFrom(ReaderSettings? settings) {
    if (settings == null) return;
    _fontSize = settings.fontSize;
    _lineHeight = settings.lineHeight;
    _pageMode = settings.pageMode;
    _bgTheme = settings.bgTheme;
    _keepScreenOn = settings.keepScreenOn;
  }

  /// 保存当前设置到数据库
  Future<void> _save() async {
    final repo = ref.read(readerSettingsRepositoryProvider);
    final current = await repo.getOrCreate();
    current
      ..fontSize = _fontSize
      ..lineHeight = _lineHeight
      ..pageMode = _pageMode
      ..bgTheme = _bgTheme
      ..keepScreenOn = _keepScreenOn;
    await repo.save(current);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(readerSettingsProvider);

    return settingsAsync.when(
      data: (settings) {
        if (!_initialized) {
          _syncFrom(settings);
          _initialized = true;
        }
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 标题栏
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('阅读设置', style: AppTextStyles.titleMedium),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 字号
                  _buildLabel('字号 ${_fontSize.round()}'),
                  Slider(
                    value: _fontSize,
                    min: 16,
                    max: 24,
                    divisions: 8,
                    activeColor: AppColors.accentRose,
                    onChanged: (v) {
                      setState(() => _fontSize = v);
                      _save();
                    },
                  ),

                  // 行距
                  _buildLabel('行距 ${_lineHeight.toStringAsFixed(1)}'),
                  Slider(
                    value: _lineHeight,
                    min: 1.2,
                    max: 2.0,
                    divisions: 8,
                    activeColor: AppColors.accentRose,
                    onChanged: (v) {
                      setState(() => _lineHeight = v);
                      _save();
                    },
                  ),

                  // 翻页模式
                  _buildLabel('翻页模式'),
                  const SizedBox(height: 8),
                  SegmentedButton<int>(
                    selected: {_pageMode},
                    style: ButtonStyle(
                      backgroundColor: WidgetStateProperty.resolveWith((states) =>
                          states.contains(WidgetState.selected)
                              ? AppColors.accentRose
                              : AppColors.bgCard),
                    ),
                    segments: const [
                      ButtonSegment(
                          value: 0, label: Text('滚动')),
                      ButtonSegment(
                          value: 1, label: Text('翻页')),
                    ],
                    onSelectionChanged: (set) {
                      setState(() => _pageMode = set.first);
                      _save();
                    },
                  ),

                  const SizedBox(height: 16),

                  // 背景主题
                  _buildLabel('背景主题'),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (var i = 0; i < 5; i++) _buildThemeSwatch(i),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // 常亮
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('保持屏幕常亮', style: AppTextStyles.body),
                      Switch(
                        value: _keepScreenOn,
                        activeColor: AppColors.accentRose,
                        onChanged: (v) {
                          setState(() => _keepScreenOn = v);
                          _save();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      ),
      error: (_, __) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('设置加载失败'),
        ),
      ),
    );
  }

  Widget _buildLabel(String text) =>
      Text(text, style: AppTextStyles.label);

  Widget _buildThemeSwatch(int index) {
    final color = AppColors.readerBg(index);
    final isSelected = _bgTheme == index;
    return GestureDetector(
      onTap: () {
        setState(() => _bgTheme = index);
        _save();
      },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          border: Border.all(
            color: isSelected
                ? AppColors.accentRose
                : AppColors.borderSoft,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(AppColors.radiusSm),
        ),
        child: isSelected
            ? const Center(
                child: Icon(Icons.check_rounded,
                    color: AppColors.accentRose, size: 20),
              )
            : null,
      ),
    );
  }
}
