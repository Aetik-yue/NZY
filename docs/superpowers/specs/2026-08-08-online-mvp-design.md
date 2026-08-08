# 线上版 MVP 迁移方案 · 设计文档

> 日期：2026-08-08
> 状态：待用户审阅
> 范围：把纯离线情侣 app 迁移为「双人云同步」--MVP 先行，跑通「账号配对 + 待办/打卡云同步 + 实时订阅 + 离线优先」链路，验证后再扩展全模块
> BaaS：腾讯云开发 CloudBase（国内节点、Serverless 免费额度、Flutter SDK、不写后端、不租服务器）

---

## 一、背景与目标

当前纯离线 Isar 单机，author 1/2 是本地假标记，两人无法真实交互。目标：女朋友的手机和我的手机数据互通--我加的待办她立刻看到、她打卡我能收到。

**MVP 原则**：先拿 2 个高频协作模块（待办 + 打卡）跑通「配对→同步→冲突→实时」全链路，验证可行后再扩展到相册/愿望/时光线/番茄钟等。

## 二、MVP 范围

**做**：
1. 账号注册/登录 + 情侣配对码绑定（形成 couple 空间）
2. 待办（todo）云同步：增删改/完成状态两人互通
3. 打卡（checkin）云同步：她打卡我即时看到
4. 实时订阅：对方改动秒级推送
5. 离线优先：断网仍可操作，联网自动同步

**不做**（YAGNI，MVP 后扩展）：
- 其他模块同步（相册/愿望/时光线/音乐/番茄钟/纪念日/小说/打砖块）
- 媒体云存储（照片/音频仍本地）
- CRDT 高级冲突合并（用 last-write-wins）
- 多设备/多情侣空间
- 后台推送通知（app 在前台时实时，后台靠下次打开同步）

## 三、腾讯云开发 CloudBase 接入

### 3.1 前置（用户在腾讯云控制台操作，非代码）
1. 开通云开发 CloudBase，创建环境（获 `envId`）
2. 开启「用户身份认证」（手机号或匿名）
3. 创建云数据库集合：`couples` / `todos` / `checkins`（见 §5）
4. （可选）部署配对云函数 `pair`（见 §4）

### 3.2 Flutter SDK 接入
- `pubspec.yaml` 加 `cloudbase_ce`（社区版 Flutter SDK，或官方 `tcb_flutter`，执行时确认最新包名）
- `lib/core/network/cloudbase_provider.dart`：初始化 `CloudBase.initializeApp(envId)`，全局单例
- envId 等配置存 `lib/core/constants/cloud_config.dart`（.gitignore 忽略或用 `--dart-define` 注入，避免泄露）

## 四、账号 + 情侣配对

### 4.1 用户身份
- 首次启动：CloudBase 匿名登录（或手机号注册）获 `userId`
- `AppSettings` 加 `userId` / `coupleId` / `partnerUserId` 字段（本地 Isar 缓存登录态）

### 4.2 配对流程
1. A 在「设置-情侣配对」页点「生成配对码」-> 云函数 `pair(action:'create')` 生成 6 位码 + 写入 `couples` 集合 `{id, userA:userId, status:'pending', code, createdAt}`
2. A 把码告诉 B（线下/微信）
3. B 在配对页输入码 -> 云函数 `pair(action:'join', code)` -> 校验码有效 -> 更新 couples 文档 `userB:B.userId, status:'paired'` -> 返回 `coupleId`
4. 两人本地 AppSettings 存 `coupleId` + `partnerUserId`
5. 配对后所有数据按 `coupleId` 隔离

### 4.3 配对页 UI
- 未配对：「生成配对码」/「输入配对码」两个入口
- 已配对：显示对方 userId +「解除配对」（云函数清除 coupleId 关联）

## 五、数据模型（云端集合）

云端用 CloudBase 文档数据库（类 MongoDB）。每个文档加 `coupleId` 隔离 + `updatedAt` 用于同步冲突。

### 5.1 couples
```
{ _id, userA, userB, status, code?, createdAt }
```

### 5.2 todos（同步 Memo 待办）
```
{
  _id, coupleId,
  content, done, dueDate?, priority, author,  // 业务字段（沿用本地 Memo）
  isPinned, colorValue, tag?,  // 保留现有
  createdAt, updatedAt,        // 同步用
  deleted: false               // 软删（同步删除需标记，否则对方删了本地不知）
}
```

### 5.3 checkins（同步打卡）
```
{
  _id, coupleId,
  date, author, note?,         // 业务字段
  createdAt, updatedAt,
  deleted: false
}
```

## 六、同步架构（离线优先）

核心：**本地 Isar 仍是唯一数据源（UI 只读本地），云端是同步层**。写操作「先本地后云端」，读操作「本地即时 + 云端订阅刷新本地」。

### 6.1 SyncService（新增 `lib/data/sync/sync_service.dart`）
- `push(localChange)`：本地写后，把变更推到云端集合（upsert by 业务 id）
- `pull(collection)`：订阅云端集合变化（watch coupleId），收到变更写入本地 Isar
- `syncQueue`：断网时写操作入队，联网后 flush
- 冲突：`updatedAt` 比较，云端新则覆盖本地，本地新则 push 覆盖云端（last-write-wins）

### 6.2 Repository 改造（以 MemoRepository 为例）
- `add/update/toggleDone/delete`：先写本地 Isar（UI 即时刷新）-> 调 `syncService.push(todo)` 异步同步云端（失败入队）
- `watchAll`：仍 watch 本地 Isar（UI 不变）+ SyncService 启动时 `pull('todos')` 订阅云端 -> 云端变更写入本地 Isar -> 流自动刷新

### 6.3 数据流
```
A 手机 add todo -> 写本地 Isar -> syncService.push 云端
                                        ↓ CloudBase watch 推送
B 手机 syncService.pull -> 写本地 Isar -> watchAll 流刷新 -> UI 更新
```

## 七、实时订阅

- CloudBase `db.collection('todos').where('coupleId','==',cid).watch()` 订阅
- 收到 changeEvent（add/update/delete）-> 映射到本地 Isar 增删改
- app 前台时 watch 活跃；后台时 watch 断开，下次前台 `pull` 全量校准（用 `updatedAt > lastSyncAt` 增量查）

## 八、冲突处理

- 每个文档 `updatedAt`（毫秒时间戳）
- push 时若云端 `updatedAt > 本地 updatedAt`（对方先改了）-> 用云端版本覆盖本地（A 的编辑丢失，last-write-wins）
- MVP 接受 LWW（情侣场景同时编辑同一条概率低）；未来可加字段级合并或提示冲突

## 九、改造影响

### 9.1 新增
- `lib/core/network/cloudbase_provider.dart`（CloudBase 初始化单例）
- `lib/data/sync/sync_service.dart`（同步层）
- `lib/data/sync/sync_queue.dart`（离线队列）
- `lib/features/couple/presentation/pair_page.dart`（配对页）
- 云函数 `pair`（create/join，部署到 CloudBase）

### 9.2 修改
- `AppSettings` 模型加 userId/coupleId/partnerUserId
- `MemoRepository` / `CheckinRepository`：写操作加 syncService.push，初始化加 syncService.pull 订阅
- `data_providers.dart`：加 syncServiceProvider（依赖 cloudbase + Isar）
- 「设置」页加入口「情侣配对」
- 首次启动引导：未配对则引导到配对页

### 9.3 不变
- UI 层基本不变（仍 watch 本地 Isar provider）
- 本地 Isar 模型字段不变（加可选 `cloudId`/`updatedAt`/`deleted` 同步元数据字段）

## 十、安全 / 权限

- CloudBase 数据库权限规则：`couples/todos/checkins` 仅允许 `doc.coupleId == user.coupleId` 的用户读写（在云函数或安全规则配置）
- 配对码云函数校验，防伪造
- envId 等密钥不硬编码（`--dart-define` 或 .gitignore 配置文件）

## 十一、测试 / 验证

- SyncService 单测：push/pull/冲突 LWW/离线队列 flush（mock CloudBase）
- 配对流程：两模拟用户 create+join
- 集成：两台真机/模拟器，A 加待办 B 秒见，B 打卡 A 秒见，断网操作联网后同步
- 现有 87 测试不回归（本地 Isar 逻辑不变）

## 十二、后续扩展（MVP 验证后）

按优先级逐模块接 SyncService：愿望 -> 时光线 -> 相册（含云存储）-> 音乐 -> 番茄钟 -> 纪念日。媒体（照片/音频）接 CloudBase 云存储。

---

## 成本预估
- CloudBase 免费额度：数据库 2GB、存储 5GB、云函数 4万次/月--情侣两人数据量（几百条文本+几十打卡）远低于免费，**长期 0 成本**
- 超额后按量计费几元/月
