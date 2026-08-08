import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/focus_session.dart';
import '../../../data/providers/data_providers.dart';

/// 专注阶段
enum FocusPhase { focus, shortBreak, longBreak }

/// 计时状态
enum TimerStatus { idle, running, paused }

/// 番茄钟计时状态
///
/// [endTime] 为截止时间戳（running 时非空），用于回前台校准与 tick 计算；
/// [remainingSec] 在 paused/idle 时为展示值，running 时由 endTime-now 计算。
class PomodoroTimerState {
  final FocusPhase phase;
  final TimerStatus status;

  /// 截止时间戳（running 时非空，paused/idle 时清空）
  final DateTime? endTime;

  /// 剩余秒（paused/idle 展示用；running 时由 endTime-now 计算）
  final int remainingSec;

  /// 本轮已完成专注数（决定是否长休：count % interval == 0 时长休）
  final int completedFocusCount;

  /// 当前专注标签（可选，写入 FocusSession.tag）
  final String? currentTag;

  const PomodoroTimerState({
    this.phase = FocusPhase.focus,
    this.status = TimerStatus.idle,
    this.endTime,
    this.remainingSec = 0,
    this.completedFocusCount = 0,
    this.currentTag,
  });

  /// copyWith
  ///
  /// 注意 [endTime] 采用直接赋值（非 `endTime ?? this.endTime`），
  /// 因为 paused/idle 时需要显式置空；不传 endTime 时结果为 null。
  /// 其余可空字段用 `??` 保留旧值。
  PomodoroTimerState copyWith({
    FocusPhase? phase,
    TimerStatus? status,
    DateTime? endTime,
    int? remainingSec,
    int? completedFocusCount,
    String? currentTag,
  }) =>
      PomodoroTimerState(
        phase: phase ?? this.phase,
        status: status ?? this.status,
        endTime: endTime,
        remainingSec: remainingSec ?? this.remainingSec,
        completedFocusCount:
            completedFocusCount ?? this.completedFocusCount,
        currentTag: currentTag ?? this.currentTag,
      );
}

/// 番茄钟计时状态机控制器
///
/// 基于截止时间戳（endTime）驱动倒计时，而非累计已过秒数：
/// - 回前台（onAppResumed）时用 endTime-now 校准，后台期间无需 tick
/// - tick 仅刷新 remainingSec 展示值，不累积误差
///
/// 阶段流转：focus -> shortBreak/longBreak -> focus -> ...
/// 长休触发条件：completedFocusCount % longBreakInterval == 0
class PomodoroTimerController extends Notifier<PomodoroTimerState> {
  Timer? _timer;

  /// 可注入的当前时间源（测试用），null 则 DateTime.now()
  DateTime Function()? _now;

  @override
  PomodoroTimerState build() {
    ref.onDispose(() => _timer?.cancel());
    return const PomodoroTimerState();
  }

  DateTime get _currentTime => _now?.call() ?? DateTime.now();

  /// 开始/恢复计时
  ///
  /// - idle：开始新一轮专注（remainingSec 重置为 focusMin*60，tag 更新）
  /// - paused：从剩余时间恢复（endTime 重设为 now+remaining）
  /// - running：已在计时，直接返回不重复启动
  void start({String? tag}) {
    if (state.status == TimerStatus.running) return;

    final settings = ref.read(pomodoroSettingsProvider).valueOrNull;
    final focusMin = settings?.focusMin ?? 25;

    if (state.status == TimerStatus.idle) {
      // 新一轮专注
      state = state.copyWith(
        phase: FocusPhase.focus,
        status: TimerStatus.running,
        currentTag: tag,
        remainingSec: focusMin * 60,
      );
    }
    // idle（已设 remainingSec）或 paused（保留 remainingSec）-> running
    state = state.copyWith(
      status: TimerStatus.running,
      endTime: _currentTime.add(Duration(seconds: state.remainingSec)),
    );
    _startTimer();
  }

  /// 启动每秒 tick 定时器
  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  /// 每秒 tick：根据 endTime 计算剩余，归零则触发阶段完成
  void _tick() {
    final remaining = state.endTime!.difference(_currentTime).inSeconds;
    if (remaining <= 0) {
      _onPhaseComplete();
      return;
    }
    state = state.copyWith(remainingSec: remaining);
  }

  /// 暂停（running -> paused）
  ///
  /// 从时钟计算实际剩余（tick 可能尚未触发），清空 endTime，保留 remainingSec。
  void pause() {
    if (state.status != TimerStatus.running) return;
    _timer?.cancel();
    final remaining = state.endTime!.difference(_currentTime).inSeconds;
    state = state.copyWith(
      status: TimerStatus.paused,
      endTime: null,
      remainingSec: remaining > 0 ? remaining : 0,
    );
  }

  /// 放弃当前阶段
  ///
  /// focus 阶段放弃写一条 completed=false 的记录（actualMin=已专注分钟）；
  /// break 阶段放弃不写记录。状态回到 idle，endTime 清空。
  Future<void> abort() async {
    _timer?.cancel();
    if (state.phase == FocusPhase.focus &&
        state.status != TimerStatus.idle) {
      // 从时钟计算实际剩余（tick 可能尚未触发），保证 actualMin 准确
      final remaining =
          state.endTime?.difference(_currentTime).inSeconds ??
              state.remainingSec;
      state = state.copyWith(
        remainingSec: remaining > 0 ? remaining : 0,
      );
      await _recordSession(completed: false);
    }
    state = state.copyWith(status: TimerStatus.idle, endTime: null);
  }

  /// 跳过当前阶段（休息时手动跳过 -> 进入专注 idle）
  ///
  /// 不写记录：跳过休息不产生专注记录，跳过专注视为放弃但不留痕。
  Future<void> skip() async {
    _timer?.cancel();
    _enterFocus();
  }

  /// 阶段完成（tick 或 onAppResumed 检测到 remaining<=0 时调用）
  ///
  /// focus 完成：写 completed=true 记录，count+1，按 count%interval 选短/长休，
  /// autoStartBreak 决定是否自动开始休息。
  /// break 完成：进入专注，autoStartFocus 决定是否自动开始。
  Future<void> _onPhaseComplete() async {
    _timer?.cancel();
    final settings = ref.read(pomodoroSettingsProvider).valueOrNull;

    if (state.phase == FocusPhase.focus) {
      await _recordSession(completed: true);
      final newCount = state.completedFocusCount + 1;
      final interval = settings?.longBreakInterval ?? 4;
      final isLongBreak = newCount % interval == 0;
      final nextPhase = isLongBreak
          ? FocusPhase.longBreak
          : FocusPhase.shortBreak;
      final breakMin = isLongBreak
          ? (settings?.longBreakMin ?? 15)
          : (settings?.shortBreakMin ?? 5);
      state = state.copyWith(
        completedFocusCount: newCount,
        phase: nextPhase,
        remainingSec: breakMin * 60,
      );
      if (settings?.autoStartBreak ?? true) {
        state = state.copyWith(
          status: TimerStatus.running,
          endTime: _currentTime.add(Duration(seconds: breakMin * 60)),
        );
        _startTimer();
      } else {
        state = state.copyWith(status: TimerStatus.idle, endTime: null);
      }
    } else {
      // 休息完 -> 专注
      final focusMin = settings?.focusMin ?? 25;
      state = state.copyWith(
        phase: FocusPhase.focus,
        remainingSec: focusMin * 60,
      );
      if (settings?.autoStartFocus ?? false) {
        state = state.copyWith(
          status: TimerStatus.running,
          endTime: _currentTime.add(Duration(seconds: focusMin * 60)),
        );
        _startTimer();
      } else {
        state = state.copyWith(status: TimerStatus.idle, endTime: null);
      }
    }
  }

  /// 进入专注 idle（skip 或休息完成后调用）
  void _enterFocus() {
    final settings = ref.read(pomodoroSettingsProvider).valueOrNull;
    final focusMin = settings?.focusMin ?? 25;
    state = state.copyWith(
      phase: FocusPhase.focus,
      status: TimerStatus.idle,
      endTime: null,
      remainingSec: focusMin * 60,
    );
  }

  /// 写专注记录
  ///
  /// completed=true: actualMin=plannedMin，startTime=now-plannedMin
  /// completed=false: actualMin=已专注分钟（plannedMin-remainingMin），startTime=now-actualMin
  Future<void> _recordSession({required bool completed}) async {
    final settings = ref.read(pomodoroSettingsProvider).valueOrNull;
    final plannedMin = settings?.focusMin ?? 25;
    final actualMin = completed
        ? plannedMin
        : (plannedMin - state.remainingSec ~/ 60).clamp(0, plannedMin);
    final repo = ref.read(focusSessionRepositoryProvider);
    await repo.add(FocusSession()
      ..startTime = _currentTime.subtract(
        Duration(minutes: completed ? plannedMin : actualMin),
      )
      ..plannedMin = plannedMin
      ..actualMin = actualMin
      ..completed = completed
      ..type = FocusType.focus
      ..tag = state.currentTag);
  }

  /// 回前台校准（WidgetsBindingObserver resumed 时调用）
  ///
  /// running 时根据 endTime 重新计算 remaining：
  /// - 已超时（remaining<=0）：触发阶段完成
  /// - 未超时：更新 remainingSec 展示值
  Future<void> onAppResumed() async {
    if (state.status == TimerStatus.running &&
        state.endTime != null) {
      final remaining = state.endTime!.difference(_currentTime).inSeconds;
      if (remaining <= 0) {
        await _onPhaseComplete();
      } else {
        state = state.copyWith(remainingSec: remaining);
      }
    }
  }

  /// 测试注入：设置当前时间源
  @visibleForTesting
  void setClockForTesting(DateTime Function() now) => _now = now;
}

/// 番茄钟计时状态 provider
final pomodoroTimerProvider =
    NotifierProvider<PomodoroTimerController, PomodoroTimerState>(
  PomodoroTimerController.new,
);
