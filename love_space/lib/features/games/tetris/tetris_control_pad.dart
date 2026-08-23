import 'dart:async';

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

/// 俄罗斯方块街机控制区：5 键（← / ↻ / → / ↓ / DROP）
///
/// ← / → / ↓ 支持 DAS（按住延迟自动重复）：按下立即执行一次动作，
/// 250ms 后切换为 100ms 周期的连续执行；松开或取消即停。
/// ↻ 与 DROP 仅点按一次，不重复。
class TetrisControlPad extends StatefulWidget {
  final VoidCallback onLeft;
  final VoidCallback onRight;
  final VoidCallback onRotate;
  final VoidCallback onSoftDrop;
  final VoidCallback onHardDrop;

  /// 是否可用：false 时按钮 40% 透明度且不响应
  final bool enabled;

  const TetrisControlPad({
    super.key,
    required this.onLeft,
    required this.onRight,
    required this.onRotate,
    required this.onSoftDrop,
    required this.onHardDrop,
    this.enabled = true,
  });

  @override
  State<TetrisControlPad> createState() => _TetrisControlPadState();
}

class _TetrisControlPadState extends State<TetrisControlPad> {
  /// DAS 初始延迟：按住多久开始连续触发
  static const _dasDelay = Duration(milliseconds: 250);

  /// DAS 重复间隔：延迟结束后每多久触发一次
  static const _repeatInterval = Duration(milliseconds: 100);

  Timer? _dasTimer;
  Timer? _repeatTimer;
  VoidCallback? _repeatAction;

  @override
  void dispose() {
    _cancelRepeat();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant TetrisControlPad oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled && !widget.enabled) _cancelRepeat();
  }

  /// 按下：立即执行一次，250ms 后转 100ms 周期连续执行
  void _startRepeat(VoidCallback action) {
    if (!widget.enabled) return;
    _cancelRepeat();
    action();
    _repeatAction = action;
    _dasTimer = Timer(_dasDelay, () {
      _repeatTimer?.cancel();
      _repeatTimer = Timer.periodic(_repeatInterval, (_) {
        if (!widget.enabled) return;
        _repeatAction?.call();
      });
    });
  }

  /// 松开 / 取消 / dispose：取消 DAS 与重复两个 Timer
  void _cancelRepeat() {
    _dasTimer?.cancel();
    _dasTimer = null;
    _repeatTimer?.cancel();
    _repeatTimer = null;
    _repeatAction = null;
  }

  void _tapOnce(VoidCallback action) {
    if (!widget.enabled) return;
    action();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          _PadButton(
            label: '←',
            repeat: true,
            enabled: widget.enabled,
            onRepeatStart: () => _startRepeat(widget.onLeft),
            onRepeatStop: _cancelRepeat,
          ),
          const SizedBox(width: 8),
          _PadButton(
            label: '↻',
            repeat: false,
            enabled: widget.enabled,
            onTap: () => _tapOnce(widget.onRotate),
          ),
          const SizedBox(width: 8),
          _PadButton(
            label: '→',
            repeat: true,
            enabled: widget.enabled,
            onRepeatStart: () => _startRepeat(widget.onRight),
            onRepeatStop: _cancelRepeat,
          ),
          const SizedBox(width: 8),
          _PadButton(
            label: '↓',
            repeat: true,
            enabled: widget.enabled,
            onRepeatStart: () => _startRepeat(widget.onSoftDrop),
            onRepeatStop: _cancelRepeat,
          ),
          const SizedBox(width: 8),
          _PadButton(
            label: 'DROP',
            repeat: false,
            enabled: widget.enabled,
            onTap: () => _tapOnce(widget.onHardDrop),
          ),
        ],
      ),
    );
  }
}

/// 单键：白底圆角 + 浅阴影 + 玫瑰色图标/文字
///
/// [repeat] 为 true 时走 DAS 手势（onTapDown 启动 / onTapUp、onTapCancel 停止），
/// 否则仅 onTap 点按一次。
class _PadButton extends StatelessWidget {
  final String label;
  final bool repeat;
  final bool enabled;
  final VoidCallback? onTap;
  final VoidCallback? onRepeatStart;
  final VoidCallback? onRepeatStop;

  const _PadButton({
    required this.label,
    required this.repeat,
    required this.enabled,
    this.onTap,
    this.onRepeatStart,
    this.onRepeatStop,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Opacity(
        opacity: enabled ? 1 : 0.4,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: repeat ? (_) => onRepeatStart?.call() : null,
          onTapUp: repeat ? (_) => onRepeatStop?.call() : null,
          onTapCancel: repeat ? onRepeatStop : null,
          onTap: repeat ? null : onTap,
          child: Container(
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.bgCard,
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              boxShadow: const [
                BoxShadow(
                  color: AppColors.shadowPink,
                  blurRadius: 8,
                  offset: Offset(0, 2),
                ),
              ],
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style:
                  AppTextStyles.titleXs.copyWith(color: AppColors.accentRose),
            ),
          ),
        ),
      ),
    );
  }
}
