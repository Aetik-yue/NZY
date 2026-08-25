import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../models/daily_fortune.dart';

/// 抽签前的摇签舞台。
class DailyFortuneDrawStage extends StatelessWidget {
  const DailyFortuneDrawStage({
    super.key,
    required this.firstName,
    required this.secondName,
    required this.shake,
    required this.revealing,
    required this.onDraw,
  });

  final String firstName;
  final String secondName;
  final Animation<double> shake;
  final bool revealing;
  final VoidCallback onDraw;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        children: [
          Text('今日缘分签', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          Text('$firstName × $secondName', style: AppTextStyles.bodySmall),
          const Spacer(),
          AnimatedBuilder(
            animation: shake,
            builder: (context, child) =>
                Transform.rotate(angle: shake.value, child: child),
            child: const _FortuneTube(),
          ),
          const Spacer(),
          Text(
            revealing ? '正在听签筒的回声…' : '轻轻摇动，把今天交给一点小小的随机与期待',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: revealing ? null : onDraw,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accentRose,
                foregroundColor: AppColors.textOnPink,
                shape: const StadiumBorder(),
              ),
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label:
                  Text(revealing ? '摇签中' : '摇一摇', style: AppTextStyles.onPink),
            ),
          ),
        ],
      ),
    );
  }
}

class _FortuneTube extends StatelessWidget {
  const _FortuneTube();

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.topCenter,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(
            5,
            (index) => Transform.translate(
              offset: Offset((index - 2) * -3, index.isEven ? 8 : 0),
              child: Container(
                width: 18,
                height: 116,
                decoration: BoxDecoration(
                  color: index.isEven
                      ? AppColors.accentPeach
                      : AppColors.accentPinkSoft,
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                ),
              ),
            ),
          ),
        ),
        Container(
          margin: const EdgeInsets.only(top: 42),
          width: 132,
          height: 152,
          decoration: const BoxDecoration(
            gradient: AppColors.headerGradient,
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(AppColors.radiusCard),
              bottomRight: Radius.circular(AppColors.radiusCard),
              topLeft: Radius.circular(AppColors.radiusXs),
              topRight: Radius.circular(AppColors.radiusXs),
            ),
            boxShadow: [
              BoxShadow(color: AppColors.shadowPinkHero, blurRadius: 28),
            ],
          ),
          child: Center(
            child: Text('缘\n分',
                textAlign: TextAlign.center,
                style: AppTextStyles.titleLarge.copyWith(
                  color: AppColors.textOnPink,
                  height: 1.6,
                )),
          ),
        ),
      ],
    );
  }
}

/// 抽签完成后的签文与当日行动。
class DailyFortuneResult extends StatelessWidget {
  const DailyFortuneResult({
    super.key,
    required this.draw,
    required this.date,
  });

  final DailyFortuneDraw draw;
  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Text('${date.month} 月 ${date.day} 日 · 今日已定',
            textAlign: TextAlign.center, style: AppTextStyles.caption),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 30),
          decoration: BoxDecoration(
            color: AppColors.bgCard,
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
            border: Border.all(color: AppColors.accentPinkSoft),
            boxShadow: const [
              BoxShadow(color: AppColors.shadowPink, blurRadius: 24),
            ],
          ),
          child: Column(
            children: [
              const Icon(Icons.auto_awesome_rounded,
                  color: AppColors.accentGold, size: 28),
              const SizedBox(height: 12),
              Text(draw.fortune.title, style: AppTextStyles.titleLarge),
              const SizedBox(height: 18),
              Text(draw.fortune.verse,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleSmall.copyWith(height: 1.7)),
              const SizedBox(height: 20),
              Container(width: 40, height: 1, color: AppColors.borderSoft),
              const SizedBox(height: 20),
              Text(draw.fortune.tip,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(height: 1.7)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _FortuneMetric(
                icon: Icons.favorite_rounded,
                label: '缘分温度',
                value: '${draw.temperature}°',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _FortuneMetric(
                icon: Icons.schedule_rounded,
                label: '幸运时刻',
                value: draw.luckyMoment,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppColors.bgBlush,
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle_rounded,
                  color: AppColors.accentRose),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('今日小行动', style: AppTextStyles.titleXs),
                    const SizedBox(height: 4),
                    Text(draw.fortune.action, style: AppTextStyles.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('同一对情侣今天会一直抽到这一签，明天再来看看。',
            textAlign: TextAlign.center, style: AppTextStyles.caption),
      ],
    );
  }
}

class _FortuneMetric extends StatelessWidget {
  const _FortuneMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.bgCard,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: AppColors.accentMauve),
          const SizedBox(height: 8),
          Text(value, style: AppTextStyles.titleMedium),
          const SizedBox(height: 2),
          Text(label, style: AppTextStyles.label),
        ],
      ),
    );
  }
}
