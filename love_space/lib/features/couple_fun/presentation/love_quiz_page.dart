import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/constants/seed_data.dart';
import '../../../data/providers/data_providers.dart';
import '../models/love_quiz.dart';
import 'widgets/love_quiz_result_view.dart';
import 'widgets/love_quiz_widgets.dart';

enum _QuizPhase { intro, answering, handoff, result }

/// 情侣双方轮流作答、最后比较偏好的恋爱测试。
class LoveQuizPage extends ConsumerStatefulWidget {
  const LoveQuizPage({super.key});

  @override
  ConsumerState<LoveQuizPage> createState() => _LoveQuizPageState();
}

class _LoveQuizPageState extends ConsumerState<LoveQuizPage> {
  _QuizPhase _phase = _QuizPhase.intro;
  int _partnerIndex = 0;
  int _questionIndex = 0;
  int? _selectedIndex;
  final List<int> _firstAnswers = [];
  final List<int> _secondAnswers = [];

  void _start() => setState(() => _phase = _QuizPhase.answering);

  void _nextQuestion() {
    final selected = _selectedIndex;
    if (selected == null) return;
    final answers = _partnerIndex == 0 ? _firstAnswers : _secondAnswers;
    answers.add(selected);

    if (_questionIndex < loveQuizQuestions.length - 1) {
      setState(() {
        _questionIndex++;
        _selectedIndex = null;
      });
      return;
    }

    setState(() {
      _selectedIndex = null;
      if (_partnerIndex == 0) {
        _partnerIndex = 1;
        _questionIndex = 0;
        _phase = _QuizPhase.handoff;
      } else {
        _phase = _QuizPhase.result;
      }
    });
  }

  void _restart() {
    setState(() {
      _phase = _QuizPhase.intro;
      _partnerIndex = 0;
      _questionIndex = 0;
      _selectedIndex = null;
      _firstAnswers.clear();
      _secondAnswers.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(appSettingsProvider).valueOrNull;
    final firstName = settings?.partner1Name ?? Seed.partner1Name;
    final secondName = settings?.partner2Name ?? Seed.partner2Name;
    final names = [firstName, secondName];

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text('恋爱测试', style: AppTextStyles.titleMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 260),
          child: _buildPhase(names),
        ),
      ),
    );
  }

  Widget _buildPhase(List<String> names) {
    switch (_phase) {
      case _QuizPhase.intro:
        return LoveQuizIntro(
          key: const ValueKey('intro'),
          firstName: names[0],
          secondName: names[1],
          onStart: _start,
        );
      case _QuizPhase.answering:
        return LoveQuizQuestionView(
          key: ValueKey('question-$_partnerIndex-$_questionIndex'),
          partnerName: names[_partnerIndex],
          questionIndex: _questionIndex,
          selectedIndex: _selectedIndex,
          onSelected: (index) => setState(() => _selectedIndex = index),
          onNext: _selectedIndex == null ? null : _nextQuestion,
        );
      case _QuizPhase.handoff:
        return LoveQuizHandoff(
          key: const ValueKey('handoff'),
          nextName: names[1],
          onContinue: () => setState(() => _phase = _QuizPhase.answering),
        );
      case _QuizPhase.result:
        return LoveQuizResultView(
          key: const ValueKey('result'),
          firstAnswers: _firstAnswers,
          secondAnswers: _secondAnswers,
          onRestart: _restart,
        );
    }
  }
}
