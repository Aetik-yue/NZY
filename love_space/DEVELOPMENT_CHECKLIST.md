# 以越之名 · 开发清单

> 生成时间：2026-08-01
> 方式：7 个模块审计 agent 并行调研 + 1 个技术负责人汇总，全部结论均附 `file:line` 证据并经 P0/P1 复核。

## 整体进度评估

| 模块 | 成熟度 | 一句话结论 |
|---|---|---|
| 首页·时光 | 基本完整 | 骨架完整（问候语/天数/打卡/时光线）但时光线「添加」入口缺失（表单死代码）、打卡无撤销/历史/留言，交互单薄 |
| 相册 | 基本完整 | 查看/筛选/时间轴/全屏较完整，缺编辑、删除撤销与磁盘文件清理、缩略图内存优化 |
| 愿望清单 | 部分实现 | 完成即消失不可回看、无编辑无全部页、空态文案误导 |
| 我的/设置 | 部分实现 | 入口齐全但设置/小说/音乐三卡均为占位，头像与纪念日无真实能力 |
| 备忘录 | 基本完整 | 差作者筛选启用、删除确认对话框与编辑页空数据边界处理 |
| 小说·爬虫 | 基本完整 | 爬虫体系成熟，但阅读器存在 4 个 P0（目录跳章、正文不按需抓取、添加重复 pop、滚动进度丢失） |
| 数据层 | 基本完整 | 分层与设计令牌较规范，但零单元测试、widget_test 隔离不彻底、本地化未启用、5 个未用依赖堆积 |

## 最值得优先做的 3 件事

1. **✅ 修复小说阅读器 4 个 P0**：目录跳章失效、正文不按需抓取、添加成功重复 pop、滚动模式进度丢失 —— 直接影响核心阅读体验
2. **✅ 接通时光线「添加」入口 + 落地设置页**（含 daysTogether 边界归一化与 memoCount 死字段清理），补全情侣核心交互闭环
3. **✅ 补齐 Repository 单元测试与 widget_test 数据层隔离**，并修复爬虫添加/更新的半成品与 crawlStatus 卡死，守住数据完整性与工程底线

---

## P0 — 重要且紧急

### 功能
1. **✅ 修复小说阅读器目录跳章失效**（2026-08-01 完成）
   目录面板 onSelect 传空列表 `_goToChapter(i, [])`，而 `_goToChapter` 对空列表执行 `index.clamp(0,0)` 恒为 0，点任意章节都跳回第 1 章。应基于已排序 chapters 做 clamp 后跳转，并同步保存进度。
   `lib/features/novel/presentation/novel_reader_page.dart`、`lib/features/novel/presentation/widgets/chapter_list_sheet.dart`

2. **✅ 阅读器章节正文按需抓取**（2026-08-01 完成）
   `addNovel` 仅预取 prefetchChapters（默认 5）章正文，后续章节 content 为空直接渲染空白；`crawl_repository.fetchChapterContent` 已实现（第 333 行）但阅读器从未调用。应在章节 content 为空时按需抓取并写回 NovelChapter，加章节级 loading 与失败重试。
   `lib/features/novel/presentation/novel_reader_page.dart`、`lib/data/repositories/crawl_repository.dart`

3. **✅ 修复添加小说成功后重复 pop 关闭面板**（2026-08-01 完成）
   `add_novel_sheet` 三处手动连 pop 两次（搜索/分类/链接入口），而 CrawlProgressSheet build 中 watch 到 success 又调度一次自动 pop，竞态下可能多 pop 把书架页整个关掉。应给进度面板自动关闭加防重标志或移除手动 pop 改为显式关闭。
   `lib/features/novel/presentation/widgets/add_novel_sheet.dart`、`lib/features/novel/presentation/widgets/crawl_progress_sheet.dart`

4. **✅ 修复滚动模式阅读进度不恢复/不保存**（2026-08-01 完成）
   `_maybeRestore` 仅在翻页模式 LayoutBuilder 分支被调用（第 389 行），滚动分支从不调用；且 `_onScroll` 在 `_restored=false` 时直接 return（第 117-122 行），滚动模式下首次进入既不复位进度也不实时保存，仅 dispose 时落库一次。需滚动分支也恢复进度，并去掉对 `_restored` 的依赖按防抖保存。
   `lib/features/novel/presentation/novel_reader_page.dart`

5. **✅ 接通时光线「添加」入口 + 空态引导**（2026-08-01 完成）
   `AddTimelineSheet.show()` 全项目无任何调用点（表单为死代码），时光线区块无加号按钮/FAB，空状态「快去添加第一个吧」纯文字无操作引导（规范 3.4 要求带按钮）。应在 SectionHeader 行加「＋」按钮调用表单，空态改为「添加第一个」按钮。
   `lib/features/home/presentation/home_page.dart`、`lib/features/home/presentation/widgets/add_timeline_sheet.dart`

### 数据
6. **✅ 修复爬虫添加/更新的半成品与 crawlStatus 卡死**（2026-08-01 完成）
   `addNovel` 先写 Novel（第 147 行）再写章节（第 184 行），中途取消会残留 0 章但 `crawlStatus='success'` 的半成品；`updateNovel` catch（第 314-326 行）把用户主动取消的 CancelledException 也记成 failed 并写失败日志；进程被杀后 crawlStatus 永久卡 'crawling'，详情页「更新章节」按钮永久禁用。应改为先抓全再一次性写入或取消时回滚，取消态不覆盖 failed，启动/进入详情时重置 stale 的 crawling。
   `lib/data/repositories/crawl_repository.dart`、`lib/features/novel/presentation/novel_detail_page.dart`

### 测试
7. **✅ 补齐各 Repository 单元测试**（2026-08-01 完成）
   test/ 目录仅 widget_test.dart 一个冒烟测试，无 CLAUDE.md 9.3 要求的 `test/repositories/*_test.dart`。应覆盖 Wish（CRUD/toggleDone）、Checkin（checkInToday 幂等/delete）、Memo（CRUD/togglePin）、Album（CRUD/分类过滤）、CrawlConfig/ReaderSettings（getOrCreate 幂等）及小说各仓库，用 Isar 内存库（directory:''）编写。
   `test/widget_test.dart`、`lib/data/repositories`

8. **✅ 修复 widget_test 数据层隔离与 override 完整性**（2026-08-01 完成）
   MainShell 用 IndexedStack 提前构建全部 Tab，相册页 watch 的 `filteredAlbumPhotosProvider` 未在 widget_test override，其依赖链会走到真实 isarProvider 抛 UnimplementedError，测试在错误态下「通过」掩盖真实问题。应 override filteredAlbumPhotosProvider/albumRepositoryProvider 等，并同步补齐 memo/novel 各 provider。
   `test/widget_test.dart`、`lib/shared/layouts/main_shell.dart`

---

## P1 — 重要

### 功能
9. **✅ 时光线「全部」全量页**（按年月分组 + 首页限条数）
   时光线「全部」按钮只弹「即将上线 📅」，首页无全量页。应新增按年月分组的全量时光线页面，首页区块改为展示最新 N 条（如 5 条）+「查看全部」，并与照片时间轴的月份导航/高亮模式对齐。
   `lib/features/home/presentation/home_page.dart`

10. **✅ 打卡交互增强：今日已打卡态 + 撤销 + 防连点 + try-catch**
    `_handleCheckin` 无 try-catch（违反规范 8.2）、打卡按钮无 loading/禁用态会连弹成功 Snackbar、无撤销入口（checkinRepository.delete 已实现但无 UI 调用）。应打卡后显示「今日已打卡」态+撤销按钮，加防连点与错误反馈。
    `lib/features/home/presentation/home_page.dart`、`lib/data/repositories/checkin_repository.dart`

11. **✅ 打卡历史月历/热力图 + streak 文案修复**
    `computeStreak` 今天未打卡返回 0（streak.dart:13），连打 128 天早上一忘就打回「连续打卡 0 天」；且无历史/月历视图。应新增月历/热力图页（复用 checkinsProvider），streak 改为昨天锚定「已连续 N 天」，computeStreak 增加可注入 today 便于测试。
    `lib/core/utils/streak.dart`、`lib/data/providers/data_providers.dart`

12. **✅ 时光线编辑功能**（长按操作单 编辑/删除 + 撤销闭包健壮化）
    timelineRepository.update 已实现但 UI 仅支持删除。长按应弹底部操作单（编辑/删除），编辑复用 update；同时修复删除撤销闭包在异步间隙后引用 events[i] 可能过期的问题（改为捕获 eventToDelete）。
    `lib/features/home/presentation/home_page.dart`、`lib/data/repositories/timeline_repository.dart`

13. **✅ 相册删除撤销 + 磁盘文件清理策略**
    照片删除仅 AppSnackbar.show('已删除照片') 无 showUndo，且只删数据库记录不清理磁盘图片，长期累积孤儿文件。应删除后走 showUndo（暂存恢复），并设计记录+文件一致性的清理策略（文件移临时目录可恢复，超期物理清理）。
    `lib/features/album/presentation/widgets/photo_viewer.dart`、`lib/data/repositories/album_repository.dart`

14. **✅ 照片编辑（改日期/分类）**
    albumRepository.update 已实现但 UI 无任何入口，添加后无法修改日期/分类。应在查看器底部菜单或长按网格弹出编辑表单（复用 AddPhotoSheet 组件），落库走 update。
    `lib/features/album/presentation/widgets/photo_viewer.dart`、`lib/features/album/presentation/widgets/add_photo_sheet.dart`

15. **✅ 设置页落地：昵称/togetherSince/隐私 + memoCount 死字段 + SettingsRepository 单例**
    「设置」卡为「即将上线 ⚙️」占位（profile_page.dart:287），settingsRepository.save 全工程无 UI 调用；AppSettings.memoCount 为过期占位字段（注释仍写「暂无 Memo 模型」，seed 写 0 但实际种了 3 条 memo）；SettingsRepository.save 直接 put 会插重复行。应新建设置页（编辑双方昵称 + 纪念日起始日期 showDatePicker + 隐私开关），save 先 findFirst 拷贝 id 再 put，并清理 memoCount 死字段重跑 build_runner。
    `lib/features/profile/presentation/profile_page.dart`、`lib/data/repositories/settings_repository.dart`、`lib/data/models/app_settings.dart`

16. **✅ 备忘录删除链路补齐：确认对话框 + 编辑页删除 + 未保存返回拦截**
    memo_page 列表长按删除直接执行无确认对话框（违反 CLAUDE.md 红线，且与其它模块不一致）；编辑页无删除按钮；编辑页无 PopScope 拦截未保存内容。应列表删除加 showConfirmDeleteDialog、编辑页加删除入口（确认+undo）、返回拦截确认。
    `lib/features/memo/presentation/memo_page.dart`、`lib/features/memo/presentation/memo_edit_page.dart`

17. **✅ 启用备忘录作者筛选**
    memoAuthorFilterProvider 已定义并接入 filteredMemosProvider，但全项目无任何 UI 使用（纯死代码）。应在搜索/标签栏旁加「全部/越/名」胶囊切换，情侣可只看自己/对方写的内容，并同步空状态文案。
    `lib/data/providers/data_providers.dart`、`lib/features/memo/presentation/memo_page.dart`

18. **✅ 修复备忘录编辑页空数据边界**
    `_loadMemo` 中 getById 返回 null（memo 已删）时 `_loaded` 恒 false 页面永久卡 CircularProgressIndicator；`_save` 编辑分支 getById 为 null 时既不提示也不保存直接 pop 静默丢内容。应在两种场景下提示「内容已不存在」并 pop。
    `lib/features/memo/presentation/memo_edit_page.dart`

19. **✅ 愿望列表完整化：查看全部页 + 已完成回看/取消 + 空态区分**
    列表 `.where((w) => !w.done).take(3)` 截断且「全部」为占位；愿望勾选完成即从列表消失无取消入口，误触不可逆；从未创建愿望时也显示「太棒了！所有愿望都已完成」误导。应新增全部愿望页（全部/进行中/已完成分类），提供已完成回看与取消勾选，并区分「无数据」与「全部完成」两种空态。
    `lib/features/wishes/presentation/wishes_page.dart`

20. **✅ 愿望编辑功能 + 完成庆祝**
    wishRepository.update 已实现但无任何 UI 调用，愿望创建后不可修改。应让 AddWishSheet 支持编辑模式（接收 Wish 入参回填），保存走 update；完成愿望时加庆祝提示并可选写入时间轴作为回忆里程碑。
    `lib/features/wishes/presentation/widgets/add_wish_sheet.dart`、`lib/data/repositories/wish_repository.dart`

### 数据
21. **✅ 在一起天数边界归一化**
    daysTogetherProvider 在 settings==null 时返回 0（显示「第 0 天」），togetherSince 在未来时返回负天数（显示「-N 天」）；起始当天显示「第 0 天」。应归一化：settings 缺失取种子默认、未来日期返回 0 并提示、起始日按预期显示第 1 天，首页与我的页统一兜底文案。
    `lib/data/providers/data_providers.dart`、`lib/features/home/presentation/home_page.dart`、`lib/features/profile/presentation/profile_page.dart`

22. **✅ 备忘录标签解析与筛选精确匹配归一化**
    标签正则 `#(\S+)`（memo_card.dart:165、data_providers.dart:345）会吞尾随标点甚至整句；筛选用 `content.contains('#$tag')`（:329）存在子串误命中（选「旅行」命中「#旅行计划」）。应抽取中文友好的标签边界正则到 core/utils 共享，筛选改为按独立标签集合精确匹配，统一高亮/提取/筛选三处逻辑。
    `lib/data/providers/data_providers.dart`、`lib/features/memo/presentation/widgets/memo_card.dart`

23. **✅ 异步操作错误处理与防重统一补齐**
    home `_handleCheckin` 无 try-catch（连打双弹 Snackbar）、wishes onToggle 未 await 且无错误处理（快速连点多翻转）、memo 快速记录 `_submit` 无 try-catch/无 `_submitting` 锁/无 mounted 检查。应按规范 8.2 统一补 try-catch + AppSnackbar 反馈 + 条目级防重锁。
    `lib/features/home/presentation/home_page.dart`、`lib/features/wishes/presentation/wishes_page.dart`、`lib/features/memo/presentation/widgets/quick_capture_bar.dart`

### 爬虫
24. **✅ 增量更新可靠性：分页抓全 + 章节定位插入**
    `_fetchChaptersFromToc` 最多抓 5 个 toc 分页，超过几百章的书只比对前 500 章，增量更新可能永远检测不到新章节；新章节一律 chapterIndex=existingChapters.length 尾部追加，源站中段插章/删章会顺序错乱。应改为「直到连续 N 页无新章节才停」，新章节按 sourceChapterId 在详情章节序列中定位插入。
    `lib/data/repositories/crawl_repository.dart`、`lib/data/crawler/biquge_crawler.dart`

25. **✅ 添加小说去重**
    Novel.sourceUrl 无唯一约束，addNovel 前不查重，同一本书可多次加入书架。应在 addNovel 前按 sourceUrl/sourceBookId 查重，已存在则提示并跳转详情。
    `lib/data/repositories/crawl_repository.dart`

### UI
26. **✅ PhotoViewer 空列表防护**
    photo_viewer.dart:68 `widget.initialIndex.clamp(0, _photos.length - 1)` 在空列表时 lower>upper 抛 ArgumentError。当前 UI 入口不可达但 PhotoViewer.show 为公开 API，应加空列表守卫/断言。
    `lib/features/album/presentation/widgets/photo_viewer.dart`

### 性能
27. **✅ 相册缩略图解码优化**
    相册网格与时间轴 Image.file 未设 cacheWidth/cacheHeight，每张以 1920px 原尺寸解码，照片量大时内存与解码开销显著。应为网格图增加 cacheWidth(300-400) 或改用 ResizeImage，全屏查看器保留原图。
    `lib/features/album/presentation/album_page.dart`、`lib/features/album/presentation/photo_timeline_page.dart`

---

## P2 — 体验提升

28. **✅ 全模块设计令牌整改（硬编码颜色/字号/圆角收敛）**
    多处硬编码违规：相册三处重复 6 组渐变数组（album_page/photo_timeline_page/add_photo_sheet）、photo_viewer 整屏 Colors.black/white 系列、wishes/memo/profile/home/add_timeline_sheet 内联 Color 与 copyWith(fontSize)、各 bottom sheet 魔法圆角、app_snackbar/confirm_dialog 的 circular(10/20)、novel 封面色板 `_coverPalette` 重复 AppColors 色值。应新增 AppColors.photoGradients 等令牌统一收敛，新颜色一律先入 AppColors，圆角用 radiusXxx。
    `lib/app/theme/app_colors.dart`、`lib/features/album/presentation/album_page.dart`、`lib/features/album/presentation/photo_timeline_page.dart`、`lib/features/novel/presentation/widgets/add_novel_sheet.dart`

29. **✅ 超长 Widget 文件拆分**
    photo_timeline_page.dart 641 行、profile_page.dart 359 行、album_page.dart 301 行均超红线 300 行。应按子组件拆分独立文件（时间轴 NavStrip/Section/Track、我的页 header/stats/music/function_cards、相册网格等），并在拆分时一并处理 `_syncSectionKeys` 在 build 中修改列表的副作用。
    `lib/features/album/presentation/photo_timeline_page.dart`、`lib/features/profile/presentation/profile_page.dart`

30. **✅ 打卡留言：CheckIn.note 每日情话 UI 化**
    CheckIn.note 字段与 checkInToday({note}) 参数均未被 UI 使用。打卡时可选输入每日情话，在打卡卡片/时光线展示，增强双人情感表达。
    `lib/data/models/check_in.dart`、`lib/data/repositories/checkin_repository.dart`

31. **✅ 种子数据口径修正**
    togetherSince=2025-10-16 晚于时间轴种子事件 2024-05-20/2024-08-08，「在一起」前就有纪念日；打卡种子含今天（i=0），首启即显示已打卡 128 天。应让 togetherSince 早于时间轴事件，打卡种子去掉今天，避免假数据观感。
    `lib/core/constants/seed_data.dart`

32. **✅ 相册/时间轴空状态补操作引导按钮**
    相册空状态与时间轴空状态均只有文案无按钮（违反规范 3.4）。应补「添加第一张照片」「添加第一条时光」按钮唤起对应表单。
    `lib/features/album/presentation/album_page.dart`、`lib/features/album/presentation/photo_timeline_page.dart`

33. **✅ AlbumPhoto 备注字段（情侣留言）**
    AlbumPhoto 模型无备注字段。应新增 memo/caption 字段（模型+build_runner+添加表单+查看器展示），支持情侣在照片下留言，呼应「备注/这一刻想说的话」。
    `lib/data/models/album_photo.dart`、`lib/features/album/presentation/widgets/photo_viewer.dart`

34. **✅ 照片时间轴健壮性 + 日期选择 firstDate 联动**
    时间轴 `_currentIndex` 在分组减少时未校正可能越界；isHighlight 只比月份不比年份会跨年误标纪念日；日期选择 firstDate 硬编码 2010。应 clamp 校正、按 togetherSince 具体年月日判定纪念日、firstDate 取 togetherSince 与 2010 较早者并允许未来 0-7 天容错。
    `lib/features/album/presentation/photo_timeline_page.dart`、`lib/features/album/presentation/widgets/add_photo_sheet.dart`、`lib/data/providers/data_providers.dart`

35. **✅ 启用 flutter_localizations + 清理未使用依赖**（2026-08-04 完成）
    pubspec 声明 flutter_localizations 但 MaterialApp 未配置 localizationsDelegates/supportedLocales，中文日期选择器等本地化未生效；go_router/shared_preferences/cached_network_image/uuid/intl 全 lib/ 无 import。应配置本地化（或将其中确实需要的能力落地后保留，其余移除）。
    `lib/app/app.dart`、`pubspec.yaml`

36. **✅ 「我的」页体验优化（小说卡真实数据/统计行跳转/音乐卡治理/昵称 ellipsis）**
    小说卡「共读 12 本」为硬编码假数据且不跳转 NovelPage；音乐卡「32 首·正在播放小幸运」假数据；统计行纯展示不可点；头部昵称无 maxLines/ellipsis 会溢出。应接入真实数据、统计行 onTap 跳转（复用 currentTabProvider）、音乐卡隐藏假数据或做真实歌单、昵称加 ellipsis。
    `lib/features/profile/presentation/profile_page.dart`

37. **✅ 阅读器 keepScreenOn 常亮生效**（2026-08-04 完成）
    keepScreenOn 仅持久化与设置面板切换，阅读器从不读取（无 Wakelock/SystemChrome）。应在阅读器 initState/dispose 按 readerSettings.keepScreenOn 保持/释放唤醒锁。
    `lib/data/models/reader_settings.dart`、`lib/features/novel/presentation/novel_reader_page.dart`

38. **✅ 爬取源/配置管理页 + 爬取日志展示**
    novelSourcesProvider/crawlConfigProvider/crawlLogsProvider 定义后无任何页面消费。应新增管理页展示/编辑爬取源与配置（含 prefetchChapters/请求间隔/超时/重试），并展示爬取日志供排查。
    `lib/data/providers/data_providers.dart`

39. **✅ AppHttpClient 生命周期治理**（2026-08-04 完成）
    每次爬取新建 AppHttpClient 且 close() 从不被调用（`_createCrawler` 每次 new），长期使用句柄/连接累积。应改为 provider 单例复用并在退出时 close，或爬取完成后显式 close。
    `lib/data/repositories/crawl_repository.dart`、`lib/core/network/app_http_client.dart`

40. **✅ 双人协作字段扩展（愿望 author/completedAt）**
    Wish 模型仅有 title/description/icon/done/createdAt，无法体现「谁添加/何时完成」。应新增 author(1/2) 与 completedAt，添加/完成时写入，UI 展示「你添加/对方添加、谁完成」；预留时间轴/打卡/相册 authorId 为未来双人视角统计铺路。
    `lib/data/models/wish.dart`

41. **✅ 备忘录列表懒加载**
    `_MemoList` 用非懒加载 ListView(children:) 一次性构建全部卡片，memo 多时卡顿。应改为 CustomScrollView + SliverList/SliverList.builder 按分组懒加载。
    `lib/features/memo/presentation/memo_page.dart`

42. **✅ 备忘录搜索体验修正**
    搜索关键词未 trim（尾随空格搜不到且误判搜索态）；空状态未细分「搜索/标签/作者无结果」；搜索结果仍显示「📌 置顶」分组无意义；清空按钮依赖父级重建耦合脆弱。应 trim 后存储、细分空态、搜索时隐藏置顶分组、清空按钮自身 setState。
    `lib/data/providers/data_providers.dart`、`lib/features/memo/presentation/widgets/memo_search_bar.dart`、`lib/features/memo/presentation/memo_page.dart`

43. **✅ 用户场景 widget 测试 + 建立 analyze 基线**
    在冒烟测试基础上补充用户场景 widget 测试（打卡成功/已打卡态、愿望 toggle 与删除撤销、备忘录快速记录与标签筛选、时光线添加/删除、设置页保存刷新），并建立 flutter analyze 零告警基线，纳入提交前检查（可配 pre-commit 钩子），防止回归。
    `test/widget_test.dart`、`pubspec.yaml`

44. **✅ CLAUDE.md 与实现同步**
    MainShell 已为 5 个 Tab（新增小说），CLAUDE.md 仍描述「4 个 Tab」；备忘录/小说模块目录与规范未更新。应同步文档（Tab 数、模块清单、爬虫规范、双人协作字段约定），保持规范是活的文档。
    `CLAUDE.md`、`lib/shared/layouts/main_shell.dart`

45. **✅ 版本发布流程规范化**
    已有 version/1.0.5/（APK + 更新日志.md）但流程人工随意。应制定发布清单：版本号 bump 规则（major.minor.patch+build）、更新日志模板（feature/fix/内部改进三段）、flutter build apk 脚本、归档目录命名（version/x.y.z/）、发布前跑 analyze + 全部测试 + 冒烟截图。
    `pubspec.yaml`、`version/1.0.5/更新日志.md`

---

## P3 — 未来想法

46. **✅ 双方头像真实化**
    情侣头像为装饰性渐变占位（`_CoupleAvatars` 无真实头像上传）。应支持从相册/相机选图保存为双方头像，home 头部与 profile 头部同步。
    `lib/features/home/presentation/home_page.dart`、`lib/features/profile/presentation/profile_page.dart`

47. **✅ 特殊节点问候 + 纪念日倒数**
    问候语扩展：在一起周年当天/情人节/生日/节假日自动切换特殊文案，支持提前 N 天预告纪念日；纪念日支持多日期（在一起/生日/自定义）与首页倒数卡片。
    `lib/core/utils/greeting.dart`

48. **✅ 音乐快捷入口补全（双人歌单/播放）**
    首页「音乐」快捷入口为「即将上线 🎵」占位。可做本地音乐选择/双人共享歌单录入与当前播放卡片，替换占位。
    `lib/features/home/presentation/home_page.dart`

49. **✅ 数据导出/备份 + schemaVersion 演进**
    为未来双人云同步/换机迁移留档：给 AppSettings 增加 schemaVersion 字段，提供 Isar 数据 JSON 导出/导入入口，防止误删丢失。
    `lib/data/models/app_settings.dart`

50. **✅ 小说共读增强**
    双人共读场景：书架/详情展示「TA 读到了第 X 章」双进度并排、整本读完标记、章末互评/弹幕式留言、阅读统计与连续共读天数、TA 在读章节高亮。
    `lib/features/novel/presentation/novel_page.dart`、`lib/features/novel/presentation/novel_reader_page.dart`

51. **✅ 单行集合强制唯一（ReaderSettings/CrawlConfig save 幂等）**
    AppSettings/ReaderSettings/CrawlConfig 均注释单例行，但 Repository 的 save/put 未强制唯一，写入新实例会插重复行、watch 只取 first 掩盖。应统一 getOrCreate 模式：先 findFirst 拷贝 id 再 put。
    `lib/data/repositories/reader_settings_repository.dart`、`lib/data/repositories/crawl_config_repository.dart`

52. **✅ 首页/时光线惰性渲染 + clockProvider 后台暂停**
    首页时光线全量渲染（配合全量页后首页限条数即可）；clockProvider 常驻每分钟一事件（IndexedStack 永不释放），考虑 App 切后台时暂停计时、回前台恢复。
    `lib/data/providers/data_providers.dart`、`lib/features/home/presentation/home_page.dart`

53. **✅ 双人同步（CloudBase）第一期**（2026-08-19 完成）
    CloudBase 免备案免费体验版：匿名登录 + 情侣码房间配对 + 5 类数据（愿望/备忘录/时光线/打卡/纪念日）全量对账同步（LWW 冲突解决 + 删除墓碑防复活）+ 60s 轮询。未配置云环境时静默降级保持纯本地。
    `lib/core/sync/`（sync_config / sync_models / sync_client / cloudbase_sync_client）、`lib/data/sync/`（sync_mapper / sync_engine / sync_providers）、`lib/features/profile/presentation/sync_pairing_page.dart`、docs/SYNC_SETUP.md

54. **✅ 双人同步（第二期）：悄悄话 + 相册照片同步**（2026-08-19 完成）
    新增悄悄话（SecretMessage 模型 + 聊天页 + 发送即同步 + 未读标记）与相册照片同步（AlbumPhoto 元数据走 pair_data 对账 + 云存储文件上传/下载，打开相册自动同步，删除同步云端文件）。同步类型扩展为 7 种。
    `lib/data/models/secret_message.dart`、`lib/features/secrets/`、`lib/data/sync/photo_sync_service.dart`、`lib/features/album/presentation/album_page.dart`、`lib/features/album/presentation/widgets/photo_viewer.dart`

55. **✅ 后端切换：CloudBase → LeanCloud 国际版（REST）**（2026-08-19 完成）
    CloudBase 免费环境误删无法重建，后端切换为 LeanCloud 国际版（免备案、3 万次 API/天免费）：`LeancloudSyncClient` 纯 Dart REST 实现（匿名用户 + Rooms/PairData 类 + 文件服务），移除 cloudbase_flutter 依赖，配置改为 LEAN_APP_ID / LEAN_APP_KEY。
    `lib/core/sync/leancloud_sync_client.dart`、`lib/core/sync/sync_config.dart`、`lib/data/sync/sync_providers.dart`、docs/SYNC_SETUP.md

56. **✅ 后端定稿：LeanCloud → 腾讯云 SCF + COS 自建云函数**（2026-08-19 完成）
    LeanCloud 注册不可用，最终后端改为自建云函数（腾讯云 Serverless + COS）：`serverless/index.js` 提供 rooms/pairdata/照片 REST 接口（COS 对象存储 + 签名 URL），Flutter 端 `ScfSyncClient` 纯 http 调用 API 网关；配置改为 SYNC_API_URL / SYNC_SECRET。免备案、公网异地可用、免费额度充足。
    `serverless/`、`lib/core/sync/scf_sync_client.dart`、`lib/core/sync/sync_config.dart`、`lib/data/sync/sync_providers.dart`、docs/SYNC_SETUP.md
