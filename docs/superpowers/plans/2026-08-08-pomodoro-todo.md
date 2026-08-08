# 番茄钟 + 待办改造 · 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development to implement task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** ① 新增番茄钟（主页替换相册入口）② 备忘录改造为待办（done+截止日期+优先级）。

**Architecture:** 番茄钟新模块 `features/pomodoro/`（模型+状态机+UI），截止时间戳计时；待办原地改造 Memo 模型加字段。两模块独立，顺序执行（共享 data_providers.dart/widget_test.dart，不并行）。

**Spec:** `docs/superpowers/specs/2026-08-08-pomodoro-todo-design.md`

**约束（CLAUDE.md）：** AppColors/AppTextStyles 令牌、AppSnackbar、context.mounted、文件<300行、Provider 集中 data_providers.dart、build_runner 重跑、widget_test override 同步。

---

## 文件结构

**新建（番茄钟）：**
- `lib/data/models/pomodoro_settings.dart` + `.g.dart`
- `lib/data/models/focus_session.dart` + `.g.dart`
- `lib/data/repositories/pomodoro_settings_repository.dart`
- `lib/data/repositories/focus_session_repository.dart`
- `lib/features/pomodoro/providers/pomodoro_timer_provider.dart`（计时状态机）
- `lib/features/pomodoro/presentation/pomodoro_page.dart`
- `lib/features/pomodoro/presentation/pomodoro_stats_page.dart`
- `lib/features/pomodoro/presentation/widgets/pomodoro_settings_sheet.dart`
- `test/pomodoro/pomodoro_timer_test.dart`

**修改（番茄钟入口）：** `lib/features/home/presentation/home_page.dart`、`lib/data/providers/data_providers.dart`、`lib/data/database/isar_provider.dart`、`test/widget_test.dart`

**修改（待办）：** `lib/data/models/memo.dart`+`.g.dart`、`lib/data/repositories/memo_repository.dart`、`lib/data/providers/data_providers.dart`、`lib/features/memo/presentation/memo_page.dart`、`memo_edit_page.dart`、`widgets/memo_card.dart`、`lib/features/profile/presentation/profile_page.dart`、`lib/features/profile/presentation/all_features_page.dart`、`test/widget_test.dart`

---

## 阶段一：番茄钟

### Task 1: 番茄钟模型 + build_runner

**Files:** Create `pomodoro_settings.dart`、`focus_session.dart`；Modify `isar_provider.dart`

- [ ] 创建 `PomodoroSettings`（单例 id=0，focusMin/shortBreakMin/longBreakMin/longBreakInterval/autoStartBreak/autoStartFocus，默认 25/5/15/4/true/false）
- [ ] 创建 `FocusSession`（autoIncrement id，@Index startTime，plannedMin/actualMin/completed，@Enumerated type，tag?）+ `enum FocusType { focus, shortBreak, longBreak }`
- [ ] `isar_provider.dart` 的 isarSchemas 追加 `PomodoroSettingsSchema`、`FocusSessionSchema`
- [ ] 跑 `dart run build_runner build --delete-conflicting-outputs` 生成 .g.dart
- [ ] `flutter analyze` 零告警
- [ ] Commit `feat(pomodoro): 新增 PomodoroSettings 与 FocusSession 模型`

### Task 2: 番茄钟 Repository + Provider

**Files:** Create 两个 repository；Modify `data_providers.dart`

- [ ] `PomodoroSettingsRepository`：getOrCreate（id=0 幂等）/ save（find id=0 拷贝再 put）/ watch
- [ ] `FocusSessionRepository`：getAll/watchAll(fireImmediately)/add/update/delete + watchToday（startTime 在今日）
- [ ] `data_providers.dart` 追加：pomodoroSettingsRepositoryProvider/pomodoroSettingsProvider(Stream)/focusSessionRepositoryProvider/focusSessionsProvider/todayFocusProvider(今日时长分钟+次数)/focusStreakProvider(复用 computeStreak，注入 today)
- [ ] `flutter analyze` 零告警
- [ ] Commit `feat(pomodoro): Repository 与 Provider（设置/记录/今日统计/连续天数）`

### Task 3: 计时状态机 + 测试（TDD）

**Files:** Create `pomodoro_timer_provider.dart`、`test/pomodoro/pomodoro_timer_test.dart`

- [ ] `PomodoroTimerState`（phase/status/endTime?/remaining/completedFocusCount/currentTag?）+ `enum FocusPhase { focus, shortBreak, longBreak }` + `enum TimerStatus { idle, running, paused }`
- [ ] `PomodoroTimerController extends Notifier`：start/pause/resume/abort/skip + 内部 Timer.periodic + 完成时写 FocusSession + 阶段切换（focus完->count++->按 interval 选 long/short break->autoStartBreak；break完->focus->autoStartFocus）
- [ ] **测试**（注入可控时间，避免真 sleep）：start 后 remaining 递减；pause 冻结；resume 继续；abort 写 completed=false；focus 完成切 shortBreak（count<interval）/longBreak（count%interval==0）；completedFocusCount 累加
- [ ] `flutter analyze` + `flutter test`（含新增）
- [ ] Commit `feat(pomodoro): 计时状态机（截止时间戳+阶段切换）+ 单测`

### Task 4: 番茄钟 UI（Page + Stats + Settings）

**Files:** Create `pomodoro_page.dart`、`pomodoro_stats_page.dart`、`widgets/pomodoro_settings_sheet.dart`

- [ ] `PomodoroPage`：标签 chip 行 + 设置图标 + 大倒计时（heroNumber mm:ss）+ 阶段文案 + 番茄进度点 + 开始/暂停/恢复/放弃按钮 + 统计入口；didChangeAppLifecycleState 回前台校准 endTime
- [ ] `PomodoroStatsPage`：今日时长/次数、累计、连续天数、最近 10 条 FocusSession 列表
- [ ] `PomodoroSettingsSheet`：专注/短休/长休/长休间隔步进器 + autoStartBreak/autoStartFocus 开关，保存到 PomodoroSettings
- [ ] 文件 <300 行（超则拆 widget）
- [ ] `flutter analyze` + `flutter build apk --debug`
- [ ] Commit `feat(pomodoro): 计时页/统计页/设置弹层`

### Task 5: 番茄钟主页入口 + widget_test

**Files:** Modify `home_page.dart`、`widget_test.dart`

- [ ] `home_page.dart:485-490` 相册 _QuickAction 替换为番茄钟：icon=timer_rounded, label='番茄钟', bg=accentPinkSoft, onTap=Navigator.push(PomodoroPage)
- [ ] `widget_test.dart` _buildOverrides 追加番茄钟相关 provider override（pomodoroSettingsProvider/focusSessionsProvider 等被 watch 的）
- [ ] `flutter analyze` + `flutter test`
- [ ] Commit `feat(pomodoro): 主页替换相册入口为番茄钟 + 测试 override`

---

## 阶段二：待办改造

### Task 6: Memo 模型加字段 + build_runner

**Files:** Modify `memo.dart`、`memo.g.dart`（生成）

- [ ] `memo.dart` 加 `late bool done`、`DateTime? dueDate`、`@Enumerated(EnumType.name) late TodoPriority priority` + `enum TodoPriority { none, high, medium, low }`
- [ ] 跑 `dart run build_runner build --delete-conflicting-outputs`
- [ ] `flutter analyze`（Isar 新增字段向前兼容，老数据 done=false/dueDate=null/priority=none）
- [ ] Commit `feat(todo): Memo 模型加 done/dueDate/priority 字段`

### Task 7: 待办 Repository + Provider

**Files:** Modify `memo_repository.dart`、`data_providers.dart`

- [ ] `memo_repository.dart` 新增 `toggleDone(Id id)`（writeTxn get->反转->put，仿 wish）
- [ ] `data_providers.dart` 新增 `memoDoneFilterProvider`(StateProvider<TodoFilter> all/active/done) + `enum TodoFilter`；`filteredMemosProvider` 加 done 过滤 + 排序（未完成在前、已完成沉底、同状态按 priority 高>中>低>无、截止日期近的在前）；新增 `memoStatsProvider`(done/total/percent，仿 wishStats)
- [ ] `flutter analyze`
- [ ] Commit `feat(todo): toggleDone + done 筛选/排序/统计 Provider`

### Task 8: 待办 UI（Card + Page + EditPage）

**Files:** Modify `memo_card.dart`、`memo_page.dart`、`memo_edit_page.dart`

- [ ] `memo_card.dart`：左侧圆形勾选（check_circle/radio_button_unchecked）toggleDone；done 删除线+置灰；优先级色点（high=accentRose/medium=accentCoral/low=accentPeach/none=无）；截止日期标签（逾期且未完成=accentRose 高亮）
- [ ] `memo_page.dart`：_AuthorFilterChips 旁加「全部/待办/已完成」筛选行（复用胶囊样式）；_MemoList 已完成项单独分区沉底
- [ ] `memo_edit_page.dart`：加截止日期选择器（showDatePicker + 预设今天/明天/本周/自定义/清除）+ 优先级选择 chip（无/高/中/低）
- [ ] 文件 <300 行
- [ ] `flutter analyze`
- [ ] Commit `feat(todo): 卡片勾选/优先级/截止日期 + 筛选/归档 + 编辑页选择器`

### Task 9: 待办文案同步 + widget_test

**Files:** Modify `all_features_page.dart`、`profile_page.dart`、`widget_test.dart`

- [ ] `all_features_page.dart`：「备忘录」->「待办」，subtitle->「记录要一起完成的事」
- [ ] `profile_page.dart` 统计行：「备忘录」->「待办」；功能卡：title「备忘录」->「待办」，sub 用 memoStats 显示「X/Y 完成」或「$memoCount 项待办」
- [ ] `widget_test.dart` 追加 memoDoneFilterProvider/memoStatsProvider override（若被 watch）
- [ ] `flutter analyze` + `flutter test`
- [ ] Commit `feat(todo): 文案同步备忘录->待办 + 测试 override`

---

## 阶段三：验证

### Task 10: 全量验证

- [ ] `flutter analyze` -> No issues found
- [ ] `flutter test` -> All tests passed
- [ ] `flutter build apk --debug` -> 成功
- [ ] 真机冒烟：番茄钟计时/休息/统计/自定义；待办勾选/截止日期/优先级/筛选

---

## Self-Review

**Spec 覆盖**：番茄钟模型(T1)/repo+provider(T2)/状态机+测试(T3)/UI(T4)/入口(T5) ✅；待办模型(T6)/repo+provider(T7)/UI(T8)/文案(T9) ✅；验证(T10) ✅。
**依赖**：T1->T2->T3->T4->T5（番茄钟顺序）；T6->T7->T8->T9（待办顺序）；两阶段独立。build_runner 在 T1/T6 各跑一次。
**一致性**：TodoPriority/TodoFilter/PomodoroSettings/FocusSession/FocusPhase/TimerStatus 命名跨任务一致。
