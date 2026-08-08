# 番茄钟 + 待办改造 · 设计文档

> 日期：2026-08-08
> 状态：待用户审阅
> 范围：① 新增番茄钟（标准版，纯个人）② 备忘录改造为待办（done + 截止日期 + 优先级）

---

## 一、背景与目标

1. **番茄钟**：主页快捷入口「相册」替换为「番茄钟」（导航栏相册保留不动），参考番茄TODO，提供专注计时/休息切换/自定义时长/专注记录/统计/标签。纯个人、纯离线。
2. **待办**：备忘录原地改造为 todolist--新增完成状态 + 截止日期 + 优先级，保留现有 #标签/双作者/搜索/置顶/日期分组。

## 二、范围与取舍

### 番茄钟（标准版）
**做**：专注倒计时（截止时间戳实现，回前台校准）｜短/长休息切换（每 N 个番茄长休）｜自定义时长配置（PomodoroSettings 单例）｜专注记录持久化（FocusSession）｜统计（今日/累计时长次数、连续天数、最近记录）｜标签｜暂停/恢复/放弃。
**不做**（YAGNI）：双作者/「我们」视图、完成写时光线、白噪音、严格锁机、种树、云同步、本地通知、小组件、跨 app 重启恢复、热力图。

### 待办
**做**：Memo 加 `done` + `dueDate` + `priority`｜卡片勾选 + 已完成沉底归档｜「全部/待办/已完成」筛选｜截止日期选择 + 逾期高亮｜优先级色点标识｜文案同步（备忘录→待办）｜保留全部现有功能。
**不做**：子任务、重复任务、本地提醒通知、复杂分类、批量操作。

---

## 三、番茄钟设计

### 3.1 数据模型

**PomodoroSettings（单例，仿 reader_settings.dart）**
```dart
@collection
class PomodoroSettings {
  Id id = 0;  // 固定单例
  late int focusMin;        // 专注分钟，默认 25，范围 5-90 步长 5
  late int shortBreakMin;   // 短休息，默认 5，1-30
  late int longBreakMin;    // 长休息，默认 15，5-60
  late int longBreakInterval; // 每 N 个番茄长休，默认 4，2-8
  late bool autoStartBreak; // 专注完自动开始休息，默认 true
  late bool autoStartFocus; // 休息完自动开始专注，默认 false
}
```

**FocusSession（专注记录）**
```dart
@collection
class FocusSession {
  Id id = Isar.autoIncrement;
  @Index late DateTime startTime;
  late int plannedMin;    // 计划时长
  late int actualMin;     // 实际时长（完成=planned，放弃=中断时长）
  late bool completed;    // 是否完成
  @Enumerated(EnumType.name) late FocusType type; // focus/shortBreak/longBreak
  String? tag;            // 标签（学习/工作/陪伴...）
}
enum FocusType { focus, shortBreak, longBreak }
```

### 3.2 Repository
- `PomodoroSettingsRepository`：getOrCreate（幂等单例）/ save（find id=0 拷贝再 put）/ watch
- `FocusSessionRepository`：标准 getAll/watchAll(fireImmediately)/add/update/delete + watchToday（按 startTime 过滤今日）

### 3.3 Provider（data_providers.dart 集中）
- `pomodoroSettingsRepositoryProvider` / `pomodoroSettingsProvider`（Stream）
- `focusSessionRepositoryProvider` / `focusSessionsProvider`（Stream<List<FocusSession>>）
- `todayFocusProvider`（今日专注时长分钟 + 次数，从 watchToday 计算）
- `focusStreakProvider`（连续专注天数，复用 streak.dart computeStreak，注入 today 便于测试）

### 3.4 计时状态机（PomodoroTimerController，Notifier）
```dart
class PomodoroTimerState {
  final FocusPhase phase;        // focus / shortBreak / longBreak
  final TimerStatus status;      // idle / running / paused
  final DateTime? endTime;       // 截止时间戳（running 时），回前台重算 remaining
  final Duration remaining;      // 剩余（paused/展示用）
  final int completedFocusCount; // 本轮已完成专注数（决定是否长休）
  final String? currentTag;
}
enum FocusPhase { focus, shortBreak, longBreak }
enum TimerStatus { idle, running, paused }
```
- **start**：设 endTime = now + remaining，status=running，启动 Timer.periodic(1s) 刷新 remaining
- **pause**：remaining = endTime - now，停 Timer，status=paused
- **resume**：endTime = now + remaining，重启 Timer
- **abort**：写 FocusSession(completed=false, actualMin=已过时长)，重置 idle
- **完成（remaining 到 0）**：写 FocusSession(completed=true)；按 phase 切换：
  - focus 完 -> completedFocusCount++；若 % interval==0 进 longBreak 否则 shortBreak；autoStartBreak ? 自动开始 : idle
  - break 完 -> focus；autoStartFocus ? 自动开始 : idle
- **回前台校准**：didChangeAppLifecycleState(resumed) 时若 running，remaining = endTime - now（若已到 0 触发完成）

### 3.5 UI
**PomodoroPage（主页 push 全屏，lib/features/pomodoro/presentation/pomodoro_page.dart）**
- 顶部：标签 chip 行（学习/工作/陪伴/无）+ 设置图标
- 中部：大倒计时数字（mm:ss，AppTextStyles.heroNumber 56px）+ 阶段文案（专注中/短休息/长休息）+ 番茄进度点（本轮第 N 个，长休间隔）
- 底部：开始/暂停/恢复 + 放弃按钮
- 底部入口：统计按钮 -> PomodoroStatsPage

**PomodoroStatsPage（统计）**：今日时长/次数、累计时长/次数、连续天数、最近 10 条 FocusSession 列表

**PomodoroSettingsSheet（自定义时长）**：专注/短休/长休/长休间隔滑块或步进器 + 两个自动开关，保存到 PomodoroSettings

### 3.6 入口
`home_page.dart:485-490` 相册 _QuickAction 整项替换为番茄钟：
- icon: Icons.timer_rounded / hourglass_bottom_rounded
- label: '番茄钟'
- bg: AppColors.accentPinkSoft
- onTap: Navigator.push -> PomodoroPage

### 3.7 颜色
番茄钟主色用 `AppColors.accentRose`（红粉色调，与 app 一致），不新增「番茄红」令牌（YAGNI，accentRose 已接近）。

---

## 四、待办改造设计

### 4.1 模型改造（memo.dart）
新增字段：
```dart
late bool done;              // 完成状态，默认 false
DateTime? dueDate;           // 截止日期（可选）
@Enumerated(EnumType.name) late TodoPriority priority; // 优先级，默认 none
enum TodoPriority { none, high, medium, low }
```
重跑 `dart run build_runner build --delete-conflicting-outputs`。Isar 新增字段向前兼容（老数据 done=false, dueDate=null, priority=none）。

### 4.2 仓库（memo_repository.dart）
- 新增 `toggleDone(Id id)`（仿 wish_repository，writeTxn 内 get->反转->put）
- update 已有（编辑 dueDate/priority 走 update）

### 4.3 Provider（data_providers.dart）
- 新增 `memoDoneFilterProvider`（StateProvider<TodoFilter>，all/active/done）
- `filteredMemosProvider` 加 done 过滤维度 + 排序：未完成在前、已完成沉底；同状态内按优先级（high>medium>low>none）+ 截止日期（近的在前，无截止日期在后）
- 新增 `memoStatsProvider`（done/total/percent，仿 wishStatsProvider）供 profile 统计行

### 4.4 UI 改造
**MemoCard（memo_card.dart）**：
- 左侧圆形勾选框（check_circle/radio_button_unchecked，仿 wish），点击 toggleDone
- done 时正文删除线 + 置灰
- 优先级色点（high=accentRose / medium=accentCoral / low=accentPeach / none=无）
- 截止日期标签（dueDate 存在时显示，逾期且未完成=accentRose 高亮）

**MemoPage（memo_page.dart）**：
- _AuthorFilterChips 旁新增「全部/待办/已完成」筛选行（复用胶囊样式）
- _MemoList 已完成项单独分区沉底（可折叠）

**MemoEditPage（memo_edit_page.dart）**：
- 加截止日期选择器（showDatePicker，预设 今天/明天/本周/自定义 + 清除）
- 加优先级选择器（无/高/中/低 chip）

**QuickCaptureBar**：保持（快速记录即待办，默认 done=false/none 优先级）

### 4.5 文案同步（必改）
- `all_features_page.dart`：「备忘录」→「待办」，subtitle→「记录要一起完成的事」
- `profile_page.dart` 统计行：「备忘录」→「待办」
- `profile_page.dart` 功能卡：title「备忘录」→「待办」，sub「$memoCount 条记录」→「$memoCount 项待办」（或用 doneStats 显示「X/Y 完成」）

### 4.6 测试同步（widget_test.dart）
- 现有 memosProvider/memoCountProvider override 保留
- 新增 provider（memoDoneFilterProvider/memoStatsProvider/番茄钟相关）若被页面 watch，在 _buildOverrides() 追加 override

---

## 五、数据流

### 番茄钟
```
PomodoroSettingsProvider(配置) -> PomodoroTimerController(状态机, Timer.periodic)
  完成时 -> FocusSessionRepository.add -> focusSessionsProvider/todayFocusProvider 更新
UI(PomodoroPage) watch 状态机 + 统计
```

### 待办
```
MemoRepository(watchAll) -> filteredMemosProvider(done+tag+author+search 过滤+排序)
  toggleDone/update -> Repository -> 流刷新
UI(MemoPage/MemoCard) watch
```

## 六、错误处理
- 番茄钟：Timer.periodic 在 dispose 取消；回前台校准用 endTime 时间戳；放弃写记录不抛
- 待办：toggleDone 失败 try/catch + AppSnackbar；截止日期逾期仅 UI 高亮，不阻塞

## 七、测试
1. `test/repositories/`：FocusSessionRepository（add/watchToday）、PomodoroSettingsRepository（getOrCreate 幂等）、MemoRepository.toggleDone
2. `test/`：PomodoroTimerController 状态机（start/pause/resume/abort/完成切换，用 Fake 时间注入）；filteredMemosProvider 排序与过滤
3. `widget_test.dart`：冒烟 + override 同步

## 八、验证
- `flutter analyze` 零告警
- `flutter test` 全部通过
- `flutter build apk --debug` 成功
- 真机：番茄钟计时/休息/统计/自定义；待办勾选/截止日期/优先级/筛选
