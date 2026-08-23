import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';

/// 播放中等化器动效；暂停时静止并降低对比度。
class MusicEqualizerBars extends StatefulWidget {
  const MusicEqualizerBars({super.key, required this.playing});

  final bool playing;

  @override
  State<MusicEqualizerBars> createState() => _MusicEqualizerBarsState();
}

class _MusicEqualizerBarsState extends State<MusicEqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<Animation<double>> _bars;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _bars = [
      Tween<double>(begin: 0.3, end: 1).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      Tween<double>(begin: 1, end: 0.3).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      Tween<double>(begin: 0.6, end: 0.9).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
    ];
    _syncAnimation();
  }

  @override
  void didUpdateWidget(MusicEqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncAnimation();
  }

  void _syncAnimation() {
    if (widget.playing) {
      if (!_controller.isAnimating) _controller.repeat(reverse: true);
      return;
    }
    _controller.stop();
    _controller.value = 0.5;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          for (var i = 0; i < _bars.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Container(
              width: 3,
              height: (_bars[i].value * 14).clamp(4, 14),
              decoration: BoxDecoration(
                color: widget.playing
                    ? AppColors.accentRose
                    : AppColors.textTertiary,
                borderRadius: BorderRadius.circular(AppColors.radiusXs),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
