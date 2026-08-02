# 音乐功能加固迭代 · 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 音乐功能收尾加固：真机实测、AudioPlayer 资源释放、设计令牌魔法数值收敛、version/ APK 存储策略评估。

**Architecture:** 四项独立工作：真机验证（用户执行，发现问题我修）、main.dart 音频后端生命周期修复、music+profile 魔法数值收敛到 AppColors 令牌、version/ APK 二进制策略决策。

**Tech Stack:** Flutter 3.44 / Dart 3.12 / Riverpod / just_audio / on_audio_query

**约束（CLAUDE.md）：** 颜色/圆角/字号用 AppColors/AppTextStyles 令牌；间距标准 8/12/16/24；不硬编码；真机验证由用户操作、我据反馈修复。

---

## Task A: 真机实测（用户执行 + 我修复）

**性质：** 验证任务，需真机（vivo V2338A）。用户操作，反馈现象，我据此修。

**Files:** 无代码改动；本 Task 产出"实测结果 → 待修复项"清单。

- [ ] **Step 1: 用户 `flutter run` 到手机，按清单逐项验证**：

| # | 验证项 | 预期 |
|---|---|---|
| A1 | 冷启动 App | **不弹**音频权限框（权限只在进播放页才请求） |
| A2 | 打开「我的」tab | 音乐卡显示「还没有音乐 · 点击播放」，**不弹**权限框 |
| A3 | 首页点音乐入口 → 全屏播放页 | **首次弹**系统音频权限框；授权后开始扫描 |
| A4 | 扫描到本地音乐 | 歌单列表/迷你条出现真实歌曲；profile 卡显示真实首数 |
| A5 | 点播放/暂停、上一首/下一首 | 有声音、进度走动、切歌正确 |
| A6 | 拖进度条 seek | 进度跳到对应位置 |
| A7 | 播完一首 | 自动切下一首（列表末尾回第一首） |
| A8 | 快速连点切歌 | 播放的是最后点的歌（无竞态错乱） |
| A9 | 删除/损坏某首文件后点播 | 提示「该曲目无法播放」并自动跳下一首，不崩溃 |
| A10 | 大曲库（几百首）打开播放页 | 封面分批加载，不长时间白屏 |
| A11 | 权限拒绝后进入播放页 | 显示「需要音乐权限」+「重新授权」按钮，点后可恢复 |

- [ ] **Step 2: 我根据反馈修复**：用户反馈失败项 → 我定位修复（走 systematic-debugging）
- [ ] **Step 3: 验证修复**：`flutter analyze` + `flutter test` + 复测

---

## Task B: AudioPlayer 资源释放（dispose 接入生命周期）

**Files:**
- Modify: `love_space/lib/main.dart:30,36`

**问题：** `JustAudioBackend` 在 `main()` 创建并注入 override，但 `JustAudioBackend.dispose()`（内部 `_player.dispose()` + StreamController close）**生产代码从不调用**——测试/热重载/ProviderScope 重建时泄漏 AudioPlayer 平台资源。

**修复：** `audioBackendProvider` 的 override 从 `overrideWithValue` 改为 `overrideWith`，注册 `ref.onDispose`：

- [ ] **Step 1: 修改 main.dart**

```dart
// 原：final audioBackend = JustAudioBackend()..init();  第 30 行
// 原：audioBackendProvider.overrideWithValue(audioBackend),  第 36 行

// 改为（删除第 30 行的 audioBackend 局部变量）：
runApp(
  ProviderScope(
    overrides: [
      isarProvider.overrideWithValue(isar),
      // 音乐播放后端：just_audio 实例，ref.onDispose 确保 ProviderScope 重建时释放
      audioBackendProvider.overrideWith((ref) {
        final backend = JustAudioBackend()..init();
        ref.onDispose(backend.dispose);
        return backend;
      }),
    ],
    child: const LoveSpaceApp(),
  ),
);
```

- [ ] **Step 2: 验证**

Run: `cd love_space && flutter analyze && flutter test`
Expected: `No issues found!` + `All tests passed!`（controller_test 用 FakeAudioBackend，不受影响）

- [ ] **Step 3: Commit**

```bash
cd ..
git add love_space/lib/main.dart
git commit -m "fix(music): audioBackend 接入 ref.onDispose 释放 just_audio 资源"
```

---

## Task C: 设计令牌魔法数值收敛

**Files:**
- Modify: `love_space/lib/features/music/presentation/music_player_page.dart`
- Modify: `love_space/lib/features/music/presentation/widgets/playlist_sheet.dart`
- Modify: `love_space/lib/features/music/presentation/widgets/music_player_widgets.dart`
- Modify: `love_space/lib/features/music/presentation/widgets/mini_player_bar.dart`
- Modify: `love_space/lib/features/profile/presentation/profile_page.dart`（`_MusicCard`）
- Modify（如需新增令牌）: `love_space/lib/app/theme/app_colors.dart`
- Modify（如需新增字号）: `love_space/lib/app/theme/app_text_styles.dart`

**目标：** 消除 music + profile 音乐卡的硬编码颜色、魔法圆角、内联字号，全部收敛到设计令牌。已有令牌：`AppColors.radiusCard=24 / radiusMd=16 / radiusSm=12 / radiusXs=8 / radiusPill=26`；间距标准 8/12/16/24。

**已定位的违规点（收敛方向）：**

| 位置 | 现值 | 收敛为 |
|---|---|---|
| music_player_page.dart:130 | `BorderRadius.circular(2)`（收起条） | `AppColors.radiusXs`（8）或新增 `AppColors.radiusXs` 已存在，用 `radiusXs` |
| music_player_page.dart:127 | `EdgeInsets.only(top: 10)` | `SizedBox`/`EdgeInsets.only(top: 12)`（对齐标准间距） |
| playlist_sheet.dart:22 | `Radius.circular(24)`（弹层顶部圆角） | `AppColors.radiusCard` |
| playlist_sheet.dart:43 | `EdgeInsets.only(top: 10)` | `top: 12` |
| playlist_sheet.dart:48 | `BorderRadius.circular(2)`（拖拽条） | `AppColors.radiusXs` |
| music_player_widgets.dart:65 | `EdgeInsets.symmetric(horizontal: 24)` | 对齐标准（保留 24 可，间距 24 在标准列） |
| music_player_widgets.dart:115,163 | 图标 `size: 48`（上/下一首） | 提取 `_kControlIconSize` 常量或保留（尺寸无令牌，统一常量即可） |
| music_player_widgets.dart:142 | 大播放按钮 `width/height: 72` | 提取常量 |
| mini_player_bar.dart:27-28 | `fromLTRB(12,0,12,4)` / `symmetric(10,6)` | 对齐 8/12/16/24（`fromLTRB(12,0,12,4)` 保留 12 与 4 合理；`10,6` → `12,8` 或保留） |
| profile_page.dart:217 | `LinearGradient(colors: [Color(0xFFFFD4E0), Color(0xFFFFA1C6)])` 音乐卡渐变 | 新增 `AppColors.musicCardGradient`（先入 AppColors 再引用） |
| profile_page.dart:219 | `BorderRadius.circular(24)` | `AppColors.radiusCard` |
| profile_page.dart:236 | `BorderRadius.circular(14)`（封面小图标） | `AppColors.radiusSm`（12） |
| profile_page.dart:246 | `AppTextStyles.titleSmall.copyWith(fontSize: 14)` | 新增 `AppTextStyles.cardTitle` 或直接 `titleSmall`（去掉内联字号） |
| profile_page.dart:238,258 | `Colors.white`（icon/圆形背景） | 语义白可保留，但按 CLAUDE.md 5.1 尽量入令牌（`AppColors.textOnPink` 用于粉色背景上的文字） |

**处理原则：**
- 颜色：新增色值必须**先入 AppColors** 再引用（CLAUDE.md 5.1）
- 圆角：一律 `AppColors.radiusXxx`
- 字号：不用 `copyWith(fontSize)`，需要则新增 `AppTextStyles` 成员
- 间距：对齐 8/12/16/24
- 尺寸（按钮/图标）：无令牌，提取具名常量即可（不新增色值）

- [ ] **Step 1: 按上述表逐项收敛**（先加令牌，再替换引用）
- [ ] **Step 2: 验证**

Run: `cd love_space && flutter analyze && flutter test && flutter build apk --debug`
Expected: `No issues found!` + `All tests passed!` + `✓ Built`

- [ ] **Step 3: Commit**

```bash
cd ..
git add love_space/lib/app/theme/ love_space/lib/features/music/ love_space/lib/features/profile/presentation/profile_page.dart
git commit -m "refactor(music): 设计令牌收敛——硬编码颜色/圆角/字号入 AppColors/AppTextStyles"
```

---

## Task D: version/ APK 二进制存储策略

**性质：** 决策项，需用户拍板后实施。

**现状：** `version/1.0.0` ~ `1.0.5` 目录下有被 git 跟踪的 APK 构建产物（约 6 个、累计 ~300MB），`git clone` 体积膨胀。

**Files:**
- `version/*.apk`（git 跟踪的二进制）
- `.gitignore`（如需忽略新版本）
- `.gitattributes`（如需 Git LFS）

**三个方案（需用户选择）：**

- [ ] **Step 1: 用户选择方案**

**方案 1（推荐）：Git LFS 化**
- 装 git-lfs，`.gitattributes` 加 `version/**/*.apk filter=lfs diff=lfs merge=lfs -text`
- `git lfs migrate` 把历史 APK 转为 LFS 指针（或用 `git rm --cached` + 重新 add）
- 优点：历史保留、仓库瘦身；缺点：需装 git-lfs、远端需支持 LFS（GitHub 免费额度对 APK 可用）
- 需确认：`git lfs` 是否已安装（`git lfs version`）

**方案 2：从 git 移除 APK，发布产物放外部**
- `git rm --cached version/*.apk` + `.gitignore` 加 `version/*.apk`
- 保留 `version/*/更新日志.md`（文本）在 git
- 优点：最简、彻底瘦身；缺点：历史提交仍含旧 APK（除非 filter-repo），新 APK 只存本地

**方案 3：保持现状**
- 接受仓库体积，不做处理

- [ ] **Step 2: 按用户选择实施**（LFS 迁移 / git rm + gitignore / 不动）
- [ ] **Step 3: 验证**

```bash
git status   # 干净
git ls-files version/ | grep -c apk   # 按方案预期（0 或 LFS 指针）
```

- [ ] **Step 4: Commit**（按方案）

---

## 自检 / 验证汇总

- Task A 真机结果闭环：失败项已修、analyze/test 全绿
- Task B：`flutter analyze` + `flutter test` + `flutter build apk --debug` 全过
- Task C：同上全过，无新增色值外泄漏
- Task D：按选定方案仓库体积变化符合预期
