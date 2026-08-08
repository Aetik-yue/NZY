# 以越之名 · 代码规范

> **每次修改本项目的任何代码前，必须先完整阅读本文件。**

---

## 一、项目概览

**以越之名** 是一款情侣恋爱空间 Flutter 应用，纯离线、本地优先（Isar 数据库）。

### 技术栈
| 类别 | 选型 |
|---|---|
| 框架 | Flutter 3.x / Dart 3.5+ |
| 状态管理 | Riverpod (`flutter_riverpod`) |
| 本地数据库 | Isar (`isar` + `isar_flutter_libs`) |
| 路由 | 底部导航（IndexedStack，5 个 Tab） |
| 音乐 | `just_audio`（播放）+ `on_audio_query`（本地曲库扫描） |
| 网络/爬虫 | `http` + `html` + `charset`（GBK 编码） |
| 设计系统 | 暖奶油粉主题，AppColors + AppTextStyles |

### 目录结构
```
love_space/
├── lib/
│   ├── main.dart                  # 入口：Isar 初始化 + ProviderScope
│   ├── app/
│   │   ├── app.dart               # MaterialApp 根节点
│   │   └── theme/                 # AppColors / AppTextStyles / AppTheme
│   ├── core/                      # 跨层共享的工具和常量
│   │   ├── constants/             # 种子数据等常量
│   │   ├── network/               # AppHttpClient（重试/UA/编码检测）/ UserAgentRotator
│   │   └── utils/                 # 问候语 / 日期工具 / 打卡计算 / 标签解析
│   ├── data/
│   │   ├── models/                # Isar @collection 模型
│   │   ├── database/              # isar_provider.dart / seed_service.dart
│   │   ├── crawler/               # BaseCrawler / BiqugeCrawler / ContentCleaner / DTO
│   │   ├── repositories/          # 每模型一个 Repository（CRUD + Stream）+ CrawlRepository 协调器
│   │   └── providers/             # Riverpod Provider 集中定义
│   ├── features/                  # 按业务模块划分
│   │   ├── home/                  # 首页（时光 + 打卡）
│   │   ├── album/                 # 相册（网格 + 时间轴）
│   │   ├── wishes/                # 愿望清单
│   │   ├── novel/                 # 小说（书架 + 爬虫 + 阅读器）
│   │   ├── memo/                  # 备忘录
│   │   ├── music/                 # 音乐（播放器 + 曲库）
│   │   └── profile/               # 我的（设置）
│   └── shared/                    # 跨模块共享的组件
│       ├── layouts/               # MainShell（主壳层）
│       ├── widgets/               # PillNavBar / SectionHeader / AppSnackbar / ConfirmDialog
│       └── utils/                 # ImagePickerHelper
└── test/                          # 测试
```

### 模块职责速览
| 模块 | 职责 | 关键文件 |
|---|---|---|
| home | 问候语、纪念日卡片、每日打卡（幂等+streak）、时光线 | `home_page.dart` |
| album | 照片九宫格、分类筛选、照片时间轴、全屏查看器 | `album_page.dart` / `photo_timeline_page.dart` |
| wishes | 愿望清单、完成统计、进度卡、完成记录到时光线 | `wishes_page.dart` |
| novel | 书架、搜索/分类添加、爬虫增量更新、滚动/翻页阅读器 | `novel_page.dart` / `novel_reader_page.dart` |
| memo | 快速输入、#标签筛选、置顶、作者双头像 | `memo_page.dart` |
| music | 本地曲库扫描、播放后端抽象、迷你播放条、全屏播放页 | `music_player_page.dart` |
| profile | 情侣信息、隐私开关、统计行、设置 | `profile_page.dart` |

---

## 二、架构规范

### 2.1 分层原则（严格遵守）

```
UI 层 (features/*/presentation/)
    ↓ 调用
数据层 (data/repositories/)
    ↓ 操作
数据库 (Isar)
```

**规则：**
- ❌ **禁止**在 Widget 中直接操作 Isar 实例
- ❌ **禁止**跨层调用（如 `core/` 直接 import `data/repositories/`）
- ✅ Widget 只通过 `ref.watch` / `ref.read` 与 Provider 交互
- ✅ Provider 调用 Repository，Repository 操作 Isar
- ✅ Repository 暴露 `Stream<T>` 供 Provider 监听，实现 UI 自动刷新

### 202 Riverpod 使用规范

**Provider 定义位置：** 全部集中在 `lib/data/providers/data_providers.dart`

```dart
// ✅ 正确：Repository Provider
final wishRepositoryProvider = Provider((ref) =>
    WishRepository(ref.watch(isarProvider)));

// ✅ 正确：Stream Provider（自动刷新 UI）
final wishesProvider = StreamProvider<List<Widget>>((ref) =>
    ref.watch(wishRepositoryProvider).watchAll());

// ✅ 正确：StateProvider（简单状态）
final currentTabProvider = StateProvider<NavTab>((ref) => NavTab.home);
```

**Widget 中消费：**
```dart
// ✅ 正确
final wishes = ref.watch(wishesProvider);
wishes.when(
  data: (list) => ...,
  loading: () => ...,
  error: (_, __) => ...,
);

// ✅ 正确：调用 repository 方法
await ref.read(wishRepositoryProvider).toggleDone(id);
```

**禁止：**
- ❌ 在 Widget 中 `await` 后不使用 `context.mounted` 检查
- ❌ 在 `build()` 方法中调用 `ref.read()` 执行副作用（如写入数据库）
- ❌ 创建全局单例替代 Riverpod Provider

### 2.3 Isar 模型规范

```dart
// ✅ 正确
import 'package:isar/isar.dart';

part 'wish.g.dart';  // build_runner 生成

@collection
class Wish {
  Id id = Isar.autoIncrement;  // 自增主键

  late String title;           // 非空用 late
  String? description;         // 可空用 ?

  late bool done;              // 基本类型直接声明
  late DateTime createdAt;

  // 枚举存储方式：
  @Enumerated(EnumType.name)   // 存为字符串，可读性好
  late PhotoCategory category;
}
```

**命名约定：**
- 模型类名：大驼峰单数（`Wish`, `TimelineEvent`, `AlbumPhoto`）
- Repository Accessor：Isar 自动生成的名称（如 `wishs`, `timelineEvents`）—— 注意 Isar 的复数化规则可能不规则，以 `.g.dart` 中实际生成为准

### 2.4 Repository 规范

每个 Repository 必须提供以下标准方法：

```dart
class XxxRepository {
  XxxRepository(this._isar);
  final Isar _isar;

  // 查询全部（一次性）
  Future<List<Xxx>> getAll() => ...

  // 监听全部（实时流，fireImmediately: true）
  Stream<List<Xxx>> watchAll() => ...

  // 新增
  Future<void> add(Xxx item) => _isar.writeTxn(() async => ...);

  // 编辑
  Future<void> update(Xxx item) => _isar.writeTxn(() async => ...);

  // 删除
  Future<void> delete(Id id) => _isar.writeTxn(() async => ...);

  // 按 ID 查询（可选，按需添加）
  Future<Xxx?> getById(Id id) => ...
}
```

**规则：**
- 所有写操作必须包裹在 `_isar.writeTxn()` 中
- `watchAll()` 必须传 `fireImmediately: true`
- Repository 中**不处理 UI 逻辑**（不 import Flutter Widget）

---

## 三、UI 编码规范

### 3.1 Widget 类型选择

| 场景 | 使用 |
|---|---|
| 需要读取/监听 Provider | `ConsumerWidget` |
| 需要 `StatefulWidget` 特性（如 TextEditingController） | `ConsumerStatefulWidget` |
| 纯展示、无 Provider 依赖 | `StatelessWidget` |

### 3.2 交互组件规范

**按钮/可点击区域：**
```dart
// ✅ 正确：用 GestureDetector 包裹无 onTap 的组件
GestureDetector(
  onTap: () => _handleTap(context, ref),
  behavior: HitTestBehavior.opaque,  // 确保空白区域也可点击
  child: Container(...)
)

// ✅ 正确：InkWell（需要涟漪效果时）
InkWell(
  onTap: _handleTap,
  borderRadius: BorderRadius.circular(14),
  child: Container(...)
)
```

**表单弹窗：**
```dart
// ✅ 正确：showModalBottomSheet + isScrollControlled
showModalBottomSheet(
  context: context,
  isScrollControlled: true,    // 关键：允许键盘弹出时调整高度
  shape: RoundedRectangleBorder(...),
  builder: (_) => Padding(
    padding: EdgeInsets.only(
      bottom: MediaQuery.of(context).viewInsets.bottom,  // 键盘避让
    ),
    child: MyForm(),
  ),
);
```

**异步操作后的 mounted 检查：**
```dart
// ✅ 正确
final result = await someAsyncCall();
if (!context.mounted) return;  // 必须检查
Navigator.of(context).pop();
```

### 3.3 反馈规范

**统一使用 AppSnackbar，禁止直接使用 ScaffoldMessenger：**
```dart
// ✅ 正确
AppSnackbar.show(context, '操作成功');
AppSnackbar.showUndo(context, '已删除', () => _undo());

// ❌ 禁止
ScaffoldMessenger.of(context).showSnackBar(...);
```

**删除操作必须使用确认对话框：**
```dart
// ✅ 正确
final confirmed = await showConfirmDeleteDialog(context, content: '...');
if (confirmed) {
  await repository.delete(id);
  if (context.mounted) AppSnackbar.showUndo(context, '已删除', _undo);
}
```

### 3.4 空状态处理

```dart
// ✅ 正确：数据为空时显示友好提示 + 操作引导
if (items.isEmpty) {
  return Center(
    child: Column(
      children: [
        Text('还没有数据', style: AppTextStyles.caption),
        const SizedBox(height: 8),
        FilledButton(
          onPressed: () => _addItem(context),
          child: const Text('添加第一个'),
        ),
      ],
    ),
  );
}
```

---

## 四、命名规范

### 4.1 文件命名
- 全部使用 **snake_case**：`add_wish_sheet.dart`, `app_snackbar.dart`
- 文件名应清晰表达内容：`{功能}_{组件类型}.dart`
  - `add_wish_sheet.dart` — 添加愿望的底部表单
  - `pill_nav_bar.dart` — 胶囊导航栏
  - `wish_repository.dart` — 愿望数据仓库

### 4.2 代码命名
| 类型 | 规范 | 示例 |
|---|---|---|
| 类名 | 大驼峰 | `WishRepository`, `AddWishSheet` |
| 方法名 | 小驼峰 | `watchAll()`, `toggleDone()` |
| 私有成员 | 下划线前缀 | `_isar`, `_handleTap()` |
| 常量 | 小驼峰（const）或 lowerCamelCase | `accentRose`, `bgPrimary` |
| Provider | 小驼峰 + Provider 后缀 | `wishesProvider`, `currentTabProvider` |
| 枚举值 | 小驼峰 | `PhotoCategory.travel` |

### 4.3 私有 Widget
页面内的子 Widget 使用下划线前缀表示私有：
```dart
class _GreetingHeader extends ConsumerWidget { ... }
class _CheckinCard extends ConsumerWidget { ... }
class _TimelineItem extends StatelessWidget { ... }
```

---

## 五、设计系统使用规范

### 5.1 颜色 — 禁止硬编码

```dart
// ✅ 正确
color: AppColors.accentRose
color: AppColors.bgCard

// ❌ 禁止
color: Color(0xFFFF6B9D)
color: Colors.pink
```

所有颜色定义在 `lib/app/theme/app_colors.dart`，新增颜色必须先添加到该文件。

### 5.2 文字样式 — 禁止内联定义

```dart
// ✅ 正确
Text('标题', style: AppTextStyles.titleMedium)
Text('正文', style: AppTextStyles.body)

// 禁止（除非是极特殊的单次使用场景）
Text('标题', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700))
```

所有文字样式定义在 `lib/app/theme/app_text_styles.dart`。如需新样式，先在定义文件中添加。

### 5.3 圆角/阴影 — 使用设计令牌

```dart
// ✅ 正确
borderRadius: BorderRadius.circular(AppColors.radiusCard)
borderRadius: BorderRadius.circular(AppColors.radiusPill)

// ❌ 禁止随意数值
borderRadius: BorderRadius.circular(13)
```

---

## 六、import 规范

### 6.1 分组顺序（每组之间空一行）
```dart
// 1. Dart SDK
import 'package:flutter/material.dart';

// 2. 第三方包
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';

// 3. 项目内（使用相对路径）
import '../../../app/theme/app_colors.dart';
import '../../../data/providers/data_providers.dart';
import '../../shared/widgets/app_snackbar.dart';
```

### 6.2 路径规范
- 项目内 import 使用**相对路径**（不使用 `package:love_space/...`）
- 深层引用不超过 4 级 `../`，超过考虑将共享内容提升到 `shared/` 或 `core/`

---

## 七、注释规范

### 7.1 必须添加注释的场景
- 类定义：`/// 愿望数据仓库`
- 公开方法：`/// 监听所有愿望的变化（实时流）`
- 非显而易见的逻辑：解释 **为什么** 而不是 **是什么**
- TODO 标记：`// TODO: 待实现 xxx`

### 7.2 注释风格
```dart
// ✅ 正确：文档注释（///）用于公开 API
/// 计算连续打卡天数
/// 从今天开始往前回溯，统计连续有记录的天数
int computeStreak(List<DateTime> dates) { ... }

// ✅ 正确：行内注释用于说明原因
// Isar 的复数化不规则（wishs 非 wishes），以 .g.dart 为准
Future<void> add(Wish wish) => _isar.wishs.put(wish);

// ❌ 禁止：无意义注释
/// 构造函数
WishRepository(this._isar);
```

---

## 八、异步处理规范

### 8.1 AsyncValue 处理
Riverpod StreamProvider 返回 `AsyncValue`，必须处理三种状态：

```dart
// ✅ 正确
final wishesAsync = ref.watch(wishesProvider);
return wishesAsync.when(
  data: (wishes) => _buildList(wishes),
  loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
  error: (err, stack) => Center(child: Text('加载失败')),
);
```

### 8.2 错误处理
```dart
// ✅ 正确：try-catch + 用户反馈
try {
  await repository.add(item);
  if (mounted) {
    Navigator.of(context).pop();
    AppSnackbar.show(context, '添加成功');
  }
} catch (e) {
  if (mounted) AppSnackbar.show(context, '添加失败，请重试');
  // 可选：记录日志
  debugPrint('Add item error: $e');
}
```

---

## 九、测试规范

### 9.1 测试文件位置
```
test/
├── widget_test.dart               # 冒烟测试
├── music/                         # 播放器控制器 / 权限时机
└── repositories/                  # 数据层单元测试
    └── data_repositories_test.dart
```

### 9.2 Provider 测试覆盖
修改任何 Provider 后，必须确保 `widget_test.dart` 中的 override 列表同步更新。

```dart
// widget_test.dart 中必须 override 所有被页面 watch 的 provider
ProviderScope(
  overrides: [
    greetingProvider.overrideWithValue('早上好，亲爱的'),
    daysTogetherProvider.overrideWithValue(365),
    wishesProvider.overrideWith((ref) => Stream.value([...])),
    // ... 新增的 provider 必须在此添加 override
  ],
  child: const LoveSpaceApp(),
);
```

### 9.3 Repository 测试
新增 Repository 方法时，必须编写对应的单元测试：
```dart
test('add wish should persist to database', () async {
  final isar = await Isar.open([WishSchema], directory: '');
  final repo = WishRepository(isar);
  await repo.add(Wish()..title = 'Test');
  final all = await repo.getAll();
  expect(all.length, 1);
  expect(all.first.title, 'Test');
});
```

---

## 十、禁止事项（红线）

| 禁止 | 正确做法 |
|---|---|
| 在 Widget 中直接操作 Isar | 通过 Repository → Provider |
| 硬编码颜色/字号 | 使用 AppColors / AppTextStyles |
| `print()` 输出调试 | 使用 `debugPrint()` |
| 在 `build()` 中执行副作用 | 在 `onTap` / `initState` 中执行 |
| 异步操作后不检查 `mounted` | `if (!context.mounted) return;` |
| 使用 `ScaffoldMessenger` 直接 | 使用 `AppSnackbar.show()` / `showUndo()` |
| 超过 300 行的 Widget 文件 | 拆分为多个子 Widget |
| 超过 3 层嵌套的 if/for | 提取为方法或使用 early return |
| 魔法数字（圆角、间距等） | 使用 `AppColors.radiusXxx` / `SizedBox(height: 8/12/16/24)` |
| `var` 声明（类型明显时） | 使用精确类型或 `final` |

---

## 十一、新增功能 Checklist

开始编码前逐项确认：

- [ ] 是否需要在 `data/models/` 新增/修改模型？
- [ ] 是否需要在 `data/repositories/` 新增/修改方法？
- [ ] 是否需要在 `data/providers/data_providers.dart` 新增 Provider？
- [ ] 是否需要在 `shared/widgets/` 新增可复用组件？
- [ ] 是否正确处理了 `AsyncValue` 的三种状态？
- [ ] 异步操作后是否检查了 `context.mounted`？
- [ ] 用户反馈是否使用了 `AppSnackbar`？
- [ ] 删除操作是否有确认对话框 + 撤销？
- [ ] 空状态是否有友好提示？
- [ ] 颜色/样式是否使用了设计系统？
- [ ] `widget_test.dart` 的 override 是否同步更新？
- [ ] 新文件是否有 `part '*.g.dart'`（如果是 Isar 模型）？

---

## 十二、常见问题

### Q: 如何添加新的页面/Tab？
1. 在 `NavTab` 枚举中新增值（`pill_nav_bar.dart`）
2. 在 `MainShell` 的 `IndexedStack.children` 中添加页面
3. 在 `NavTabX` extension 中添加 `label` 和 `icon`
4. 在 `data/providers/data_providers.dart` 添加相关 Provider（含 `currentTabProvider`）

### Q: 如何添加新的数据模型？
1. 在 `data/models/` 创建 `@collection` 类
2. 运行 `dart run build_runner build --delete-conflicting-outputs`
3. 创建对应的 `XxxRepository`
4. 在 `data/providers/data_providers.dart` 添加 Repository 和 Stream Provider
5. 在 `isar_provider.dart` 的 `isarSchemas` 中添加 Schema
6. 在 `seed_service.dart` 中添加种子数据（如需要）

### Q: 如何添加新的交互功能？
1. 确认 Repository 有所需的 CRUD 方法
2. 在对应的 Provider 中添加状态（如需要）
3. 创建表单 Widget（放在 `features/*/presentation/widgets/`）
4. 使用 `showModalBottomSheet` 或 `showDialog` 弹出
5. 表单提交后调用 Repository + AppSnackbar 反馈
6. 更新测试

---

> **本规范是活的文档。发现更好的模式时，更新本文件并同步到全项目。**
