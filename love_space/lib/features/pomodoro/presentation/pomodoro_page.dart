import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../data/providers/data_providers.dart';
import '../providers/pomodoro_timer_provider.dart';
import 'pomodoro_stats_page.dart';
import 'widgets/pomodoro_settings_sheet.dart';
import 'widgets/pomodoro_widgets.dart';

/// 番茄钟计时主页
///
/// 大倒计时 + 阶段文案 + 番茄进度点 + 控制按钮。
/// 通过 [WidgetsBindingObserver] 在回前台时校准计时（后台期间不 tick，
/// 由 controller.onAppResumed 用 endTime-now 重算剩余）。
class PomodoroPage extends ConsumerStatefulWidget {
  const PomodoroPage({super.key});

  @override
  ConsumerState<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends ConsumerState<PomodoroPage>
    with WidgetsBindingObserver {
  /// 当前选中的标签（null = 无）。仅 idle 时可改；running/paused 锁定。
  String? _selectedTag;

  /// 可选标签（「无」对应 null，由行尾单独渲染）
  static const _tags = ['学习', '工作', '陪伴'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // 回前台校准：后台期间不 tick，用 endTime-now 重算剩余或触发完成
    if (state == AppLifecycleState.resumed) {
      ref.read(pomodoroTimerProvider.notifier).onAppResumed();
    }
  }

  /// 开始/继续 或 暂停
  void _toggle() {
    final controller = ref.read(pomodoroTimerProvider.notifier);
    if (ref.read(pomodoroTimerProvider).status == TimerStatus.running) {
      controller.pause();
    } else {
      // idle：开新一轮专注（传 tag）；paused：从剩余时间恢复
      controller.start(tag: _selectedTag);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(pomodoroTimerProvider);
    final settings = ref.watch(pomodoroSettingsProvider).valueOrNull;
    final interval = settings?.longBreakInterval ?? 4;
    final today = ref.watch(todayFocusProvider);
    final locked = s.status != TimerStatus.idle;
    // running/paused 锁定展示 state.currentTag；idle 时展示本地选择
    final tag = locked ? s.currentTag : _selectedTag;

    return Scaffold(
      backgroundColor: AppColors.bgPrimary,
      appBar: AppBar(
        backgroundColor: AppColors.bgPrimary,
        elevation: 0,
        centerTitle: true,
        title: Text('番茄钟', style: AppTextStyles.titleMedium),
        actions: [
          IconButton(
            tooltip: '专注统计',
            icon: const Icon(Icons.insights_rounded,
                color: AppColors.textPrimary, size: 22),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PomodoroStatsPage()),
            ),
          ),
          IconButton(
            tooltip: '设置',
            icon: const Icon(Icons.settings_rounded,
                color: AppColors.textPrimary, size: 22),
            onPressed: () => PomodoroSettingsSheet.show(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Column(
            children: [
              PomodoroTagRow(
                tags: _tags,
                selected: tag,
                locked: locked,
                onSelected: (t) => setState(() => _selectedTag = t),
              ),
              const SizedBox(height: 24),
              PomodoroPhaseCard(state: s, interval: interval),
              const SizedBox(height: 32),
              PomodoroControls(
                status: s.status,
                onToggle: _toggle,
                onAbort: () => ref.read(pomodoroTimerProvider.notifier).abort(),
              ),
              const Spacer(),
              PomodoroTodaySummary(minutes: today.minutes, count: today.count),
            ],
          ),
        ),
      ),
    );
  }
}
