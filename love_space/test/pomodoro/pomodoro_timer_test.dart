// 番茄钟计时状态机单元测试
//
// 通过 setClockForTesting 注入可控时间源，避免真 sleep：
// - 测公开状态转换（start/pause/abort/skip）+ onAppResumed 校准
// - 阶段完成通过 onAppResumed（超时）触发，避免依赖 Timer.periodic 实时 tick
// - FocusSessionRepository 用内存 fake 捕获 add 调用，无需 Isar 原生库
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:love_space/data/models/focus_session.dart';
import 'package:love_space/data/models/pomodoro_settings.dart';
import 'package:love_space/data/providers/data_providers.dart';
import 'package:love_space/data/repositories/focus_session_repository.dart';
import 'package:love_space/features/pomodoro/providers/pomodoro_timer_provider.dart';

/// Isar 桩：仅用于构造 FocusSessionRepository（fake 覆写 add 后不访问 _isar）
///
/// implements + noSuchMethod 满足 Isar 接口，避免依赖原生库加载。
class _FakeIsar implements Isar {
  @override
  dynamic noSuchMethod(Invocation invocation) {}
}

/// 捕获 add 调用的 FocusSessionRepository fake
///
/// 继承 FocusSessionRepository 以满足 Provider<FocusSessionRepository> 类型；
/// 覆写 add 捕获 session 而不写入 Isar，供断言 completed/actualMin/tag 等。
class _CapturingFocusSessionRepository extends FocusSessionRepository {
  _CapturingFocusSessionRepository() : super(_FakeIsar());

  final List<FocusSession> added = [];

  @override
  Future<void> add(FocusSession session) {
    added.add(session);
    return Future.value();
  }
}

/// 构造测试用设置（默认 autoStartBreak=false 便于断言 idle 状态）
PomodoroSettings _settings({
  int focusMin = 25,
  int shortBreakMin = 5,
  int longBreakMin = 15,
  int longBreakInterval = 4,
  bool autoStartBreak = false,
  bool autoStartFocus = false,
}) =>
    PomodoroSettings()
      ..focusMin = focusMin
      ..shortBreakMin = shortBreakMin
      ..longBreakMin = longBreakMin
      ..longBreakInterval = longBreakInterval
      ..autoStartBreak = autoStartBreak
      ..autoStartFocus = autoStartFocus;

void main() {
  late ProviderContainer container;
  late DateTime fakeNow;
  late _CapturingFocusSessionRepository fakeRepo;

  setUp(() async {
    fakeNow = DateTime(2026, 8, 8, 10, 0, 0);
    fakeRepo = _CapturingFocusSessionRepository();
    container = ProviderContainer(overrides: [
      pomodoroSettingsProvider.overrideWith(
        (ref) => Stream.value(_settings()),
      ),
      focusSessionRepositoryProvider.overrideWithValue(fakeRepo),
    ]);
    // 预热设置流，使 valueOrNull 非空
    await container.read(pomodoroSettingsProvider.future);
    // 注入可控时钟
    container
        .read(pomodoroTimerProvider.notifier)
        .setClockForTesting(() => fakeNow);
  });

  tearDown(() => container.dispose());

  test('初始状态：idle / focus / remainingSec=0 / count=0', () {
    final state = container.read(pomodoroTimerProvider);
    expect(state.status, TimerStatus.idle);
    expect(state.phase, FocusPhase.focus);
    expect(state.remainingSec, 0);
    expect(state.completedFocusCount, 0);
    expect(state.endTime, isNull);
  });

  group('start', () {
    test('从 idle 进入 running，phase=focus，remaining=25min，endTime=now+25min', () {
      final ctrl = container.read(pomodoroTimerProvider.notifier);
      ctrl.start();

      final state = container.read(pomodoroTimerProvider);
      expect(state.status, TimerStatus.running);
      expect(state.phase, FocusPhase.focus);
      expect(state.remainingSec, 25 * 60);
      expect(state.endTime, fakeNow.add(const Duration(minutes: 25)));
    });

    test('带标签启动：currentTag 保留', () {
      final ctrl = container.read(pomodoroTimerProvider.notifier);
      ctrl.start(tag: '写作');

      expect(container.read(pomodoroTimerProvider).currentTag, '写作');
    });

    test('running 时重复 start 为空操作（不重置 endTime）', () {
      final ctrl = container.read(pomodoroTimerProvider.notifier);
      ctrl.start();
      final endTimeBefore = container.read(pomodoroTimerProvider).endTime;

      fakeNow = fakeNow.add(const Duration(seconds: 30));
      ctrl.start(); // 已 running，应 no-op

      expect(
        container.read(pomodoroTimerProvider).endTime,
        endTimeBefore, // 未被重置
      );
    });
  });

  group('pause / resume', () {
    test('running->paused：endTime 清空，remaining 保留', () {
      final ctrl = container.read(pomodoroTimerProvider.notifier);
      ctrl.start();
      fakeNow = fakeNow.add(const Duration(seconds: 10));
      ctrl.pause();

      final state = container.read(pomodoroTimerProvider);
      expect(state.status, TimerStatus.paused);
      expect(state.endTime, isNull);
      expect(state.remainingSec, 25 * 60 - 10);
    });

    test('paused->running（resume）：endTime 用 remainingSec 重设', () {
      final ctrl = container.read(pomodoroTimerProvider.notifier);
      ctrl.start();
      fakeNow = fakeNow.add(const Duration(seconds: 10));
      ctrl.pause();

      // 暂停期间时间流逝不影响 resume 的 endTime 计算
      fakeNow = fakeNow.add(const Duration(minutes: 5));
      ctrl.start(); // resume

      final state = container.read(pomodoroTimerProvider);
      expect(state.status, TimerStatus.running);
      expect(state.remainingSec, 25 * 60 - 10);
      expect(
        state.endTime,
        fakeNow.add(const Duration(seconds: 25 * 60 - 10)),
      );
    });

    test('resume 保留 currentTag', () {
      final ctrl = container.read(pomodoroTimerProvider.notifier);
      ctrl.start(tag: '写作');
      ctrl.pause();
      ctrl.start(); // resume

      expect(container.read(pomodoroTimerProvider).currentTag, '写作');
    });
  });

  group('onAppResumed 校准', () {
    test('running 时回前台校准 remaining（未超时）', () async {
      final ctrl = container.read(pomodoroTimerProvider.notifier);
      ctrl.start();
      fakeNow = fakeNow.add(const Duration(minutes: 5)); // 后台 5 分钟

      await ctrl.onAppResumed();

      final state = container.read(pomodoroTimerProvider);
      expect(state.status, TimerStatus.running); // 仍 running
      expect(state.remainingSec, 20 * 60); // 25-5=20min
    });

    test('超时触发阶段完成：focus->shortBreak，count+1，idle', () async {
      final ctrl = container.read(pomodoroTimerProvider.notifier);
      ctrl.start();
      fakeNow = fakeNow.add(const Duration(minutes: 25)); // 恰好到时

      await ctrl.onAppResumed();

      final state = container.read(pomodoroTimerProvider);
      expect(state.status, TimerStatus.idle); // autoStartBreak=false
      expect(state.phase, FocusPhase.shortBreak);
      expect(state.completedFocusCount, 1);
      expect(state.remainingSec, 5 * 60);
      // 写了 1 条 completed=true 记录
      expect(fakeRepo.added, hasLength(1));
      expect(fakeRepo.added.first.completed, true);
      expect(fakeRepo.added.first.actualMin, 25);
      expect(fakeRepo.added.first.plannedMin, 25);
      expect(fakeRepo.added.first.type, FocusType.focus);
    });

    test('带标签的专注完成：记录中保留 tag', () async {
      final ctrl = container.read(pomodoroTimerProvider.notifier);
      ctrl.start(tag: '写作');
      fakeNow = fakeNow.add(const Duration(minutes: 25));

      await ctrl.onAppResumed();

      expect(fakeRepo.added.first.tag, '写作');
    });

    test('第 4 次 focus 完成 -> longBreak', () async {
      final ctrl = container.read(pomodoroTimerProvider.notifier);
      // 完成 4 轮 focus（每轮 start -> advance 25min -> onAppResumed）
      for (var i = 0; i < 4; i++) {
        ctrl.start(); // 从 idle（break idle 或初始 idle）开始新一轮 focus
        fakeNow = fakeNow.add(const Duration(minutes: 25));
        await ctrl.onAppResumed();
      }

      final state = container.read(pomodoroTimerProvider);
      expect(state.phase, FocusPhase.longBreak);
      expect(state.completedFocusCount, 4);
      expect(state.remainingSec, 15 * 60);
      expect(fakeRepo.added, hasLength(4)); // 4 条 completed 记录
    });

    test('前 3 次 focus 完成 -> shortBreak，第 4 次 -> longBreak', () async {
      final ctrl = container.read(pomodoroTimerProvider.notifier);
      for (var i = 1; i <= 4; i++) {
        ctrl.start();
        fakeNow = fakeNow.add(const Duration(minutes: 25));
        await ctrl.onAppResumed();
        final state = container.read(pomodoroTimerProvider);
        if (i < 4) {
          expect(state.phase, FocusPhase.shortBreak, reason: '第 $i 次应为短休');
        } else {
          expect(state.phase, FocusPhase.longBreak, reason: '第 $i 次应为长休');
        }
      }
    });
  });

  group('abort', () {
    test('focus 阶段放弃：写 completed=false 记录，actualMin=已专注分钟', () async {
      final ctrl = container.read(pomodoroTimerProvider.notifier);
      ctrl.start();
      fakeNow = fakeNow.add(const Duration(minutes: 10)); // 专注了 10 分钟

      await ctrl.abort();

      final state = container.read(pomodoroTimerProvider);
      expect(state.status, TimerStatus.idle);
      expect(state.endTime, isNull);
      expect(fakeRepo.added, hasLength(1));
      final session = fakeRepo.added.first;
      expect(session.completed, false);
      expect(session.plannedMin, 25);
      expect(session.actualMin, 10); // 25-15=10
      expect(session.type, FocusType.focus);
    });

    test('focus 放弃记录 startTime=now-actualMin', () async {
      final ctrl = container.read(pomodoroTimerProvider.notifier);
      ctrl.start();
      fakeNow = fakeNow.add(const Duration(minutes: 10));

      await ctrl.abort();

      final session = fakeRepo.added.first;
      // startTime 应为 10 分钟前（开始专注的时刻）
      expect(
        session.startTime,
        fakeNow.subtract(const Duration(minutes: 10)),
      );
    });

    test('idle 时 abort 为空操作（不写记录）', () async {
      final ctrl = container.read(pomodoroTimerProvider.notifier);

      await ctrl.abort();

      expect(container.read(pomodoroTimerProvider).status, TimerStatus.idle);
      expect(fakeRepo.added, isEmpty);
    });

    test('break 阶段放弃：不写记录，回到 idle', () async {
      // 需 autoStartBreak=true 才能进入 running 的 break
      final repo = _CapturingFocusSessionRepository();
      final c = ProviderContainer(overrides: [
        pomodoroSettingsProvider.overrideWith(
          (ref) => Stream.value(_settings(autoStartBreak: true)),
        ),
        focusSessionRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      await c.read(pomodoroSettingsProvider.future);
      final ctrl = c.read(pomodoroTimerProvider.notifier);
      ctrl.setClockForTesting(() => fakeNow);

      ctrl.start();
      fakeNow = fakeNow.add(const Duration(minutes: 25));
      await ctrl.onAppResumed(); // focus 完成 -> break 自动开始（running）

      // 确认已进入 break running
      final breakState = c.read(pomodoroTimerProvider);
      expect(breakState.status, TimerStatus.running);
      expect(breakState.phase, FocusPhase.shortBreak);

      await ctrl.abort();

      final state = c.read(pomodoroTimerProvider);
      expect(state.status, TimerStatus.idle);
      expect(state.endTime, isNull);
      expect(repo.added, hasLength(1)); // 只写了 focus 记录，break 不写
    });
  });

  group('skip', () {
    test('休息 idle 时 skip -> focus idle', () async {
      final ctrl = container.read(pomodoroTimerProvider.notifier);
      ctrl.start();
      fakeNow = fakeNow.add(const Duration(minutes: 25));
      await ctrl.onAppResumed(); // focus 完成 -> shortBreak idle

      ctrl.skip();

      final state = container.read(pomodoroTimerProvider);
      expect(state.status, TimerStatus.idle);
      expect(state.phase, FocusPhase.focus);
      expect(state.remainingSec, 25 * 60);
    });

    test('focus running 时 skip -> focus idle（重置，不写记录）', () {
      final ctrl = container.read(pomodoroTimerProvider.notifier);
      ctrl.start();

      ctrl.skip();

      final state = container.read(pomodoroTimerProvider);
      expect(state.status, TimerStatus.idle);
      expect(state.phase, FocusPhase.focus);
      expect(state.remainingSec, 25 * 60);
      expect(fakeRepo.added, isEmpty); // skip 不写记录
    });
  });

  group('autoStart', () {
    test('autoStartBreak=true：focus 完成后自动开始休息（running）', () async {
      final repo = _CapturingFocusSessionRepository();
      final c = ProviderContainer(overrides: [
        pomodoroSettingsProvider.overrideWith(
          (ref) => Stream.value(_settings(autoStartBreak: true)),
        ),
        focusSessionRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      await c.read(pomodoroSettingsProvider.future);
      final ctrl = c.read(pomodoroTimerProvider.notifier);
      ctrl.setClockForTesting(() => fakeNow);

      ctrl.start();
      fakeNow = fakeNow.add(const Duration(minutes: 25));
      await ctrl.onAppResumed(); // focus 完成 -> break 自动开始

      final state = c.read(pomodoroTimerProvider);
      expect(state.status, TimerStatus.running);
      expect(state.phase, FocusPhase.shortBreak);
      expect(state.remainingSec, 5 * 60);
      expect(state.endTime, fakeNow.add(const Duration(minutes: 5)));
    });

    test('break 完成 -> focus idle（autoStartFocus=false）', () async {
      final repo = _CapturingFocusSessionRepository();
      final c = ProviderContainer(overrides: [
        pomodoroSettingsProvider.overrideWith(
          (ref) => Stream.value(
            _settings(autoStartBreak: true, autoStartFocus: false),
          ),
        ),
        focusSessionRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      await c.read(pomodoroSettingsProvider.future);
      final ctrl = c.read(pomodoroTimerProvider.notifier);
      ctrl.setClockForTesting(() => fakeNow);

      ctrl.start();
      fakeNow = fakeNow.add(const Duration(minutes: 25));
      await ctrl.onAppResumed(); // focus -> break running（auto-start）
      fakeNow = fakeNow.add(const Duration(minutes: 5));
      await ctrl.onAppResumed(); // break -> focus idle

      final state = c.read(pomodoroTimerProvider);
      expect(state.status, TimerStatus.idle);
      expect(state.phase, FocusPhase.focus);
      expect(state.completedFocusCount, 1);
      expect(state.remainingSec, 25 * 60);
    });

    test('autoStartFocus=true：break 完成后自动开始专注', () async {
      final repo = _CapturingFocusSessionRepository();
      final c = ProviderContainer(overrides: [
        pomodoroSettingsProvider.overrideWith(
          (ref) => Stream.value(
            _settings(autoStartBreak: true, autoStartFocus: true),
          ),
        ),
        focusSessionRepositoryProvider.overrideWithValue(repo),
      ]);
      addTearDown(c.dispose);
      await c.read(pomodoroSettingsProvider.future);
      final ctrl = c.read(pomodoroTimerProvider.notifier);
      ctrl.setClockForTesting(() => fakeNow);

      ctrl.start();
      fakeNow = fakeNow.add(const Duration(minutes: 25));
      await ctrl.onAppResumed(); // focus -> break running
      fakeNow = fakeNow.add(const Duration(minutes: 5));
      await ctrl.onAppResumed(); // break -> focus running（auto-start）

      final state = c.read(pomodoroTimerProvider);
      expect(state.status, TimerStatus.running);
      expect(state.phase, FocusPhase.focus);
      expect(state.remainingSec, 25 * 60);
      expect(state.endTime, fakeNow.add(const Duration(minutes: 25)));
    });
  });
}
