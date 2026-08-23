import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// 简易计时器页（正计时秒表）
///
/// 基于 Ticker 的真实时间累加：高刷屏下计时不会加速；
/// 支持开始/暂停/继续、计圈、重置。纯 StatefulWidget，无 Riverpod/Isar 依赖。
class StopwatchPage extends StatefulWidget {
  const StopwatchPage({super.key});

  @override
  State<StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends State<StopwatchPage>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker;

  /// 累计已计时（跨暂停/继续）
  Duration _elapsed = Duration.zero;

  /// 上一帧 Ticker 回调的 elapsed，用于计算帧间 dt
  Duration _lastTick = Duration.zero;

  /// 是否正在计时
  bool _running = false;

  /// 计圈记录：每圈按下时的累计时长（index 0 = 第一圈）
  final List<Duration> _laps = [];

  @override
  void initState() {
    super.initState();
    _ticker = createTicker(_onTick);
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  void _onTick(Duration elapsed) {
    if (!mounted) return;
    // Ticker 的 elapsed 自 start() 起算；暂停恢复时 _lastTick 归零，
    // 首帧 dt = elapsed（恢复后的小段时间），累加正确。
    final dt = elapsed - _lastTick;
    _lastTick = elapsed;
    if (dt > Duration.zero) {
      setState(() => _elapsed += dt);
    }
  }

  void _toggle() {
    if (_running) {
      _ticker.stop();
      setState(() => _running = false);
    } else {
      _lastTick = Duration.zero;
      _ticker.start();
      setState(() => _running = true);
    }
  }

  void _lap() {
    if (!_running) return;
    setState(() => _laps.add(_elapsed));
  }

  void _reset() {
    _ticker.stop();
    setState(() {
      _running = false;
      _elapsed = Duration.zero;
      _lastTick = Duration.zero;
      _laps.clear();
    });
  }

  /// 格式化为 mm:ss.cs（分:秒.厘秒）
  String _format(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    final cs =
        (d.inMilliseconds ~/ 10).remainder(100).toString().padLeft(2, '0');
    return '$m:$s.$cs';
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
        title: Text('计时器', style: AppTextStyles.titleMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: AppColors.spacingMd),
            _buildDisplay(),
            const SizedBox(height: AppColors.spacingXl),
            _buildControls(),
            const SizedBox(height: AppColors.spacingLg),
            Expanded(child: _buildLapList()),
          ],
        ),
      ),
    );
  }

  /// 计时显示卡（渐变底 + 白色大数字）
  Widget _buildDisplay() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: AppColors.spacingLg),
      padding: const EdgeInsets.symmetric(vertical: AppColors.spacing2xl),
      decoration: BoxDecoration(
        gradient: AppColors.pinkButtonGradient,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowPinkMedium,
            blurRadius: 24,
            offset: Offset(0, 8),
            spreadRadius: -4,
          ),
        ],
      ),
      child: Text(
        _format(_elapsed),
        textAlign: TextAlign.center,
        style: AppTextStyles.heroNumber,
      ),
    );
  }

  /// 控制按钮组
  Widget _buildControls() {
    final canReset = _elapsed > Duration.zero || _laps.isNotEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppColors.spacingLg),
      child: Row(
        children: [
          _secondaryButton(
            label: '重置',
            icon: Icons.refresh_rounded,
            enabled: canReset,
            onTap: _reset,
          ),
          const SizedBox(width: AppColors.spacingSm),
          Expanded(
            child: _primaryButton(
              label:
                  _running ? '暂停' : (_elapsed == Duration.zero ? '开始' : '继续'),
              icon: _running ? Icons.pause_rounded : Icons.play_arrow_rounded,
              onTap: _toggle,
            ),
          ),
          const SizedBox(width: AppColors.spacingSm),
          _secondaryButton(
            label: '计圈',
            icon: Icons.flag_rounded,
            enabled: _running,
            onTap: _lap,
          ),
        ],
      ),
    );
  }

  /// 主按钮（渐变胶囊）
  Widget _primaryButton({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: AppColors.spacingMd),
        decoration: BoxDecoration(
          gradient: AppColors.pinkButtonGradient,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          boxShadow: const [
            BoxShadow(
              color: AppColors.shadowPinkStrong,
              blurRadius: 16,
              offset: Offset(0, 6),
              spreadRadius: -4,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.textOnPink, size: 20),
            const SizedBox(width: AppColors.spacingXs),
            Text(label,
                style: AppTextStyles.onPink
                    .copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  /// 次按钮（描边胶囊）
  Widget _secondaryButton({
    required String label,
    required IconData icon,
    required bool enabled,
    required VoidCallback onTap,
  }) {
    final color = enabled ? AppColors.accentRose : AppColors.textTertiary;
    return GestureDetector(
      onTap: enabled ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: AppColors.spacingMd),
        decoration: BoxDecoration(
          color: AppColors.bgCard,
          borderRadius: BorderRadius.circular(AppColors.radiusPill),
          border: Border.all(color: color.withValues(alpha: 0.4)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 2),
            Text(label, style: AppTextStyles.label.copyWith(color: color)),
          ],
        ),
      ),
    );
  }

  /// 圈数列表（最新在上）
  Widget _buildLapList() {
    if (_laps.isEmpty) {
      return Center(child: Text('计圈后这里会显示每圈用时', style: AppTextStyles.caption));
    }
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AppColors.spacingLg),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppColors.radiusCard),
        boxShadow: const [
          BoxShadow(
            color: AppColors.shadowCard,
            blurRadius: 16,
            offset: Offset(0, 4),
            spreadRadius: -4,
          ),
        ],
      ),
      child: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: _laps.length,
        separatorBuilder: (_, __) =>
            const Divider(height: 1, indent: 16, color: AppColors.borderSoft),
        itemBuilder: (_, i) {
          // 最新在上：倒序展示
          final idx = _laps.length - i;
          final total = _laps[idx - 1];
          final prev = idx >= 2 ? _laps[idx - 2] : Duration.zero;
          final delta = total - prev;
          return ListTile(
            dense: true,
            title: Text('第 $idx 圈', style: AppTextStyles.body),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(_format(total),
                    style: AppTextStyles.bodySmall.copyWith(
                        fontFamily: AppTextStyles.latinFontFamily,
                        color: AppColors.textPrimary)),
                const SizedBox(width: AppColors.spacingSm),
                Text('+${_format(delta)}',
                    style: AppTextStyles.label.copyWith(
                        fontFamily: AppTextStyles.latinFontFamily,
                        color: AppColors.accentRose)),
              ],
            ),
          );
        },
      ),
    );
  }
}
