import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../models/love_quiz.dart';

/// 恋爱测试开始页。
class LoveQuizIntro extends StatelessWidget {
  const LoveQuizIntro({
    super.key,
    required this.firstName,
    required this.secondName,
    required this.onStart,
  });

  final String firstName;
  final String secondName;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
      child: Column(
        children: [
          const Spacer(),
          const _QuizEmblem(),
          const SizedBox(height: 32),
          Text('默契交换所', style: AppTextStyles.titleLarge),
          const SizedBox(height: 12),
          Text(
            '$firstName 和 $secondName 将轮流回答 ${loveQuizQuestions.length} 道题\n不偷看答案，最后一起揭晓默契度',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(height: 1.7),
          ),
          const Spacer(),
          _PrimaryButton(label: '开始交换答案', onPressed: onStart),
          const SizedBox(height: 12),
          Text('答案没有对错，真实最有趣', style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

/// 单道题作答页。
class LoveQuizQuestionView extends StatelessWidget {
  const LoveQuizQuestionView({
    super.key,
    required this.partnerName,
    required this.questionIndex,
    required this.selectedIndex,
    required this.onSelected,
    required this.onNext,
  });

  final String partnerName;
  final int questionIndex;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final question = loveQuizQuestions[questionIndex];
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppColors.radiusPill),
                  child: LinearProgressIndicator(
                    value: (questionIndex + 1) / loveQuizQuestions.length,
                    minHeight: 8,
                    backgroundColor: AppColors.borderSoft,
                    color: AppColors.accentRose,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text('${questionIndex + 1}/${loveQuizQuestions.length}',
                  style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 28),
          Text('$partnerName 的答案',
              style:
                  AppTextStyles.caption.copyWith(color: AppColors.accentRose)),
          const SizedBox(height: 8),
          Text(question.prompt, style: AppTextStyles.titleLarge),
          const SizedBox(height: 24),
          for (int index = 0; index < question.options.length; index++) ...[
            _AnswerOption(
              label: question.options[index],
              marker: String.fromCharCode(65 + index),
              selected: selectedIndex == index,
              onTap: () => onSelected(index),
            ),
            const SizedBox(height: 12),
          ],
          const Spacer(),
          _PrimaryButton(
            label:
                questionIndex == loveQuizQuestions.length - 1 ? '完成这一轮' : '下一题',
            onPressed: onNext,
          ),
        ],
      ),
    );
  }
}

/// 第一位答完后的隐私交接页。
class LoveQuizHandoff extends StatelessWidget {
  const LoveQuizHandoff({
    super.key,
    required this.nextName,
    required this.onContinue,
  });

  final String nextName;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const Spacer(),
          Container(
            width: 112,
            height: 112,
            decoration: const BoxDecoration(
              color: AppColors.bgCard,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(color: AppColors.shadowPink, blurRadius: 28),
              ],
            ),
            child: const Icon(Icons.visibility_off_rounded,
                size: 44, color: AppColors.accentMauve),
          ),
          const SizedBox(height: 28),
          Text('答案已悄悄收好', style: AppTextStyles.titleLarge),
          const SizedBox(height: 12),
          Text(
            '把手机交给 $nextName\n确认上一位已经看不到屏幕后再继续',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodySmall.copyWith(height: 1.7),
          ),
          const Spacer(),
          _PrimaryButton(label: '我是 $nextName，继续', onPressed: onContinue),
        ],
      ),
    );
  }
}

class _QuizEmblem extends StatelessWidget {
  const _QuizEmblem();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 144,
      height: 144,
      decoration: const BoxDecoration(
        gradient: AppColors.heroGradient,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: AppColors.shadowPinkHero, blurRadius: 32)],
      ),
      child: const Icon(Icons.favorite_rounded,
          size: 64, color: AppColors.textOnPink),
    );
  }
}

class _AnswerOption extends StatelessWidget {
  const _AnswerOption({
    required this.label,
    required this.marker,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String marker;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.bgBlush : AppColors.bgCard,
      borderRadius: BorderRadius.circular(AppColors.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppColors.radiusMd),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(
              color: selected ? AppColors.accentRose : AppColors.borderSoft,
            ),
            borderRadius: BorderRadius.circular(AppColors.radiusMd),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 15,
                backgroundColor:
                    selected ? AppColors.accentRose : AppColors.bgCream,
                child: Text(marker,
                    style: AppTextStyles.caption.copyWith(
                      color: selected
                          ? AppColors.textOnPink
                          : AppColors.textSecondary,
                      fontWeight: FontWeight.w700,
                    )),
              ),
              const SizedBox(width: 12),
              Expanded(child: Text(label, style: AppTextStyles.body)),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.accentRose,
          foregroundColor: AppColors.textOnPink,
          shape: const StadiumBorder(),
        ),
        child: Text(label, style: AppTextStyles.onPink),
      ),
    );
  }
}
