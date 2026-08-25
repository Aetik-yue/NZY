import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/seed_data.dart';
import '../../../data/providers/data_providers.dart';
import '../models/daily_fortune.dart';
import 'widgets/daily_fortune_widgets.dart';

/// 每对情侣每天固定一签的离线缘分签页面。
class DailyFortunePage extends ConsumerStatefulWidget {
  const DailyFortunePage({super.key});

  @override
  ConsumerState<DailyFortunePage> createState() => _DailyFortunePageState();
}

class _DailyFortunePageState extends ConsumerState<DailyFortunePage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _shake;
  bool _revealing = false;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _shake = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0, end: -0.07), weight: 1),
      TweenSequenceItem(tween: Tween(begin: -0.07, end: 0.07), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.07, end: -0.05), weight: 2),
      TweenSequenceItem(tween: Tween(begin: -0.05, end: 0.04), weight: 2),
      TweenSequenceItem(tween: Tween(begin: 0.04, end: 0), weight: 1),
    ]).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _draw() async {
    if (_revealing || _revealed) return;
    setState(() => _revealing = true);
    await _controller.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _revealing = false;
      _revealed = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final firstName = settings?.partner1Name ?? Seed.partner1Name;
    final secondName = settings?.partner2Name ?? Seed.partner2Name;
    final now = DateTime.now();
    final draw = drawDailyFortune(now, '$firstName|$secondName');

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('缘分签', style: AppTextStyles.titleMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 420),
          child: _revealed
              ? DailyFortuneResult(
                  key: const ValueKey('result'), draw: draw, date: now)
              : DailyFortuneDrawStage(
                  key: const ValueKey('draw'),
                  firstName: firstName,
                  secondName: secondName,
                  shake: _shake,
                  revealing: _revealing,
                  onDraw: _draw,
                ),
        ),
      ),
    );
  }
}
