import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../models/love_quiz.dart';

/// 双方答案的最终结果页。
class LoveQuizResultView extends StatelessWidget {
  const LoveQuizResultView({
    super.key,
    required this.firstAnswers,
    required this.secondAnswers,
    required this.onRestart,
  });

  final List<int> firstAnswers;
  final List<int> secondAnswers;
  final VoidCallback onRestart;

  @override
  Widget build(BuildContext context) {
    final result = scoreLoveQuiz(firstAnswers, secondAnswers);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppColors.heroGradient,
            borderRadius: BorderRadius.circular(AppColors.radiusCard),
            boxShadow: const [
              BoxShadow(color: AppColors.shadowPinkHero, blurRadius: 24),
            ],
          ),
          child: Column(
            children: [
              Text(result.title,
                  style: AppTextStyles.titleMedium
                      .copyWith(color: AppColors.textOnPink)),
              const SizedBox(height: 12),
              Text('${result.percentage}%', style: AppTextStyles.heroNumber),
              const SizedBox(height: 10),
              Text(result.message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.onPink.copyWith(height: 1.6)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text('答案回声', style: AppTextStyles.titleMedium),
        const SizedBox(height: 12),
        for (int index = 0; index < loveQuizQuestions.length; index++)
          _ResultRow(
            question: loveQuizQuestions[index].prompt,
            matched: firstAnswers[index] == secondAnswers[index],
          ),
        const SizedBox(height: 20),
        SizedBox(
          height: 52,
          child: FilledButton(
            onPressed: onRestart,
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.accentRose,
              foregroundColor: AppColors.textOnPink,
              shape: const StadiumBorder(),
            ),
            child: Text('再测一次', style: AppTextStyles.onPink),
          ),
        ),
      ],
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.question, required this.matched});

  final String question;
  final bool matched;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            matched ? Icons.favorite_rounded : Icons.compare_arrows_rounded,
            color: matched ? AppColors.accentRose : AppColors.accentMauve,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(question, style: AppTextStyles.bodySmall)),
          Text(matched ? '同频' : '不同', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}
