# 小说阅读器核心体验完善 · 设计文档

> 日期：2026-08-08
> 状态：待执行
> 范围：核心体验完善 + 代码拆分（863 行红线）

---

## 一、背景与目标

阅读器已具备骨干（双模式/自动翻章/进度/主题/字号行距/常亮/目录）。本次完善 5 项高价值低成本体验 + 代码拆分，消除切章卡顿、补齐导航与排版短板、修复红线。

## 二、范围（核心体验 + 拆分）

**做：**
1. **代码拆分**：`novel_reader_page.dart` 863 行 -> <300 行（抽子组件/控制器）+ `novel_detail_page.dart` 376 行拆分；修复 build 内副作用（_settings/_latestChapters 赋值 + addPostFrameCallback 移出 build）
2. **段距可调**：ReaderSettings 加 `paragraphSpacing`（默认 12，8-24），设置面板加滑块，正文按 `\n` 分段渲染 + 段间距 SizedBox，分页（paginateChapter）计入段距
3. **预取下一章**：post-frame 钩子抓当前章后异步预取 effectiveIndex+1 写回 DB（复用 _ensureChapterBodyReady，幂等守卫），消除切章 loading
4. **进度滑块**：底栏进度文本下方加 Slider（0..章数-1，divisions=章数），拖动结束跳章（onChangeEnd -> _goToChapter）
5. **哨兵页重试按钮**：ReaderChapterEndPage 失败态加 onRetry 回调 + 重试按钮（对齐 ReaderEmptyContent）
6. **翻页上一章衔接**：_previous() page==0 且非首章时回退上一章末页（预取上一章正文后 _goToChapter(index-1) 跳最后一页）

**不做（YAGNI/后置）：** 书签、亮度、自动滚动、阅读时长、字体选择、目录搜索、翻页动画、滚动懒加载、TTS/听书/下载/笔记。

## 三、模型改动

`ReaderSettings` 加 `late double paragraphSpacing`（默认 12.0，范围 8-24）-> 重跑 `dart run build_runner build --delete-conflicting-outputs`。Isar 新增字段向前兼容（老数据默认值）。

## 四、文件拆分方案

`novel_reader_page.dart`（863 行）按职责抽：
- `widgets/reader_scroll_mode.dart`：滚动模式构建（SingleChildScrollView+Column+追加+章内进度换算）
- `widgets/reader_page_mode.dart`：翻页模式构建（PageView+哨兵页+分页缓存）
- `reader_chapter_fetcher.dart`（或 mixin）：按需抓取+预取下一章+_ensureChapterBodyReady
- `reader_progress.dart`（或 mixin）：进度保存/恢复/_computeScrollProgress/_chapterBases
- 主文件保留：State 主体 + build 组装 + 设置/工具栏调用 + initState/dispose

`novel_detail_page.dart`（376 行）：抽详情体子 widget（封面卡/简介/章节列表/操作按钮）到 widgets/。

## 五、UI 改动

- **设置面板**（reader_settings_sheet.dart）：加段距 Slider（8-24，默认 12）
- **底栏**（reader_controls.dart ReaderBottomBar）：进度文本下加 Slider（跳章）
- **哨兵页**（reader_placeholders.dart ReaderChapterEndPage）：失败态加重试按钮
- **正文渲染**：滚动模式按 `\n` 分段，段间 SizedBox(height: paragraphSpacing)；翻页模式 paginateChapter 计入段距

## 六、测试
- 段距分页计入（paginateChapter 含段距的高度计算）
- 预取下一章（mock fetchChapterContent，断言 effectiveIndex+1 被抓取写回）
- 进度滑块跳章（onChangeEnd -> _goToChapter）
- 哨兵页重试（onRetry 触发重新抓取）
- 上一章衔接（page==0 回退上一章末页）

## 七、验证
- `flutter analyze` 零告警
- `flutter test` 全过
- `flutter build apk --debug` 成功
- 文件均 <300 行
