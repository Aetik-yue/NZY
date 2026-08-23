import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../shared/widgets/app_snackbar.dart';

/// 随机数生成器页
///
/// 自定义范围生成随机整数；记录最近 5 次结果横向展示。
/// 纯 StatefulWidget，无 Riverpod/Isar 依赖。
class RandomNumberPage extends StatefulWidget {
  const RandomNumberPage({super.key});

  @override
  State<RandomNumberPage> createState() => _RandomNumberPageState();
}

class _RandomNumberPageState extends State<RandomNumberPage> {
  final _minCtrl = TextEditingController(text: '1');
  final _maxCtrl = TextEditingController(text: '100');
  final _random = Random();

  /// 当前结果（null 表示尚未生成）
  int? _result;

  /// 最近 5 次结果（最新在右）
  final List<int> _history = [];

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _generate() {
    final min = int.tryParse(_minCtrl.text.trim());
    final max = int.tryParse(_maxCtrl.text.trim());
    if (min == null || max == null) {
      AppSnackbar.show(context, '请输入有效的整数');
      return;
    }
    if (min > max) {
      AppSnackbar.show(context, '最小值不能大于最大值');
      return;
    }
    // min==max 时直接返回该值，避免 Random.nextInt(0) 抛异常
    final value = (min == max) ? min : min + _random.nextInt(max - min + 1);
    setState(() {
      _result = value;
      _history.add(value);
      if (_history.length > 5) _history.removeAt(0);
    });
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
        title: Text('随机数', style: AppTextStyles.titleMedium),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            const SizedBox(height: AppColors.spacingSm),
            _buildResultCard(),
            const SizedBox(height: AppColors.spacingXl),
            _buildRangeCard(),
            const SizedBox(height: AppColors.spacingLg),
            _buildGenerateButton(),
            if (_history.isNotEmpty) ...[
              const SizedBox(height: AppColors.spacingXl),
              _buildHistory(),
            ],
          ],
        ),
      ),
    );
  }

  /// 结果展示卡（粉色渐变底 + 白色大数字）
  Widget _buildResultCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
          vertical: AppColors.spacing2xl, horizontal: AppColors.spacingXl),
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
      child: Column(
        children: [
          Text('本次结果', style: AppTextStyles.onPink),
          const SizedBox(height: AppColors.spacingXs),
          Text(
            _result == null ? '—' : '$_result',
            style: AppTextStyles.heroNumber,
          ),
        ],
      ),
    );
  }

  /// 范围设置卡
  Widget _buildRangeCard() {
    return Container(
      padding: const EdgeInsets.all(AppColors.spacingLg),
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
      child: Row(
        children: [
          Expanded(child: _buildField('最小值', _minCtrl)),
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: AppColors.spacingSm),
            child: Text('～',
                style: AppTextStyles.titleMedium
                    .copyWith(color: AppColors.textTertiary)),
          ),
          Expanded(child: _buildField('最大值', _maxCtrl)),
        ],
      ),
    );
  }

  Widget _buildField(String label, TextEditingController ctrl) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(label, style: AppTextStyles.label),
        ),
        TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          style: AppTextStyles.titleSmall,
          decoration: InputDecoration(
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: AppColors.spacingMd, vertical: AppColors.spacingSm),
            filled: true,
            fillColor: AppColors.bgCream,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AppColors.radiusSm),
              borderSide:
                  const BorderSide(color: AppColors.accentRose, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  /// 生成按钮（渐变胶囊）
  Widget _buildGenerateButton() {
    return GestureDetector(
      onTap: _generate,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: double.infinity,
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
        child: Text('生成随机数',
            textAlign: TextAlign.center,
            style: AppTextStyles.onPink
                .copyWith(fontSize: 16, fontWeight: FontWeight.w600)),
      ),
    );
  }

  /// 最近 5 次历史（横向小字）
  Widget _buildHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('最近 ${_history.length} 次', style: AppTextStyles.label),
        const SizedBox(height: AppColors.spacingXs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (var i = 0; i < _history.length; i++) ...[
                if (i > 0) const SizedBox(width: AppColors.spacingXs),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: AppColors.spacingSm, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.bgCard,
                    borderRadius: BorderRadius.circular(AppColors.radiusPill),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: Text(
                    '${_history[i]}',
                    style: AppTextStyles.bodySmall.copyWith(
                        fontFamily: AppTextStyles.latinFontFamily,
                        color: AppColors.textPrimary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
