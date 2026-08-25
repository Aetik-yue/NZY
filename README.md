<h1 align="center">以越之名</h1>

<p align="center"><strong>把相伴的日子、共同的愿望与只属于两个人的故事，安放在一个私密空间里。</strong></p>

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white" alt="Flutter 3.x" />
  <img src="https://img.shields.io/badge/Dart-%5E3.5.4-0175C2?logo=dart&logoColor=white" alt="Dart ^3.5.4" />
  <img src="https://img.shields.io/badge/version-1.1.0-FF6B9D" alt="Version 1.1.0" />
  <img src="https://img.shields.io/badge/tests-173%20passed-A8C9A0" alt="173 tests passed" />
</p>

**以越之名**是一款使用 Flutter 开发的情侣生活记录 App。它以本地优先为原则：不配置服务器也能使用全部核心功能；需要异地双机共享时，可以选择部署腾讯云 SCF + COS 同步服务。

项目当前面向 Android 与 iOS，采用暖奶油粉主题、圆角卡片和胶囊式导航，覆盖记录、相册、愿望、共读、音乐、专注与情侣互动等场景。

## 为什么做这个 App

常见记录工具往往只解决一个问题：相册只存照片，待办只列任务，纪念日只做倒数。以越之名希望把这些彼此有关的瞬间放回同一个上下文中：今天的打卡可以成为连续陪伴，完成的愿望可以进入时光线，一张照片可以成为音乐播放时再次出现的回忆。

它有三个明确原则：

- **本地优先**：核心数据保存在设备上的 Isar 数据库中，未配置云服务时正常运行。
- **双人语境**：作者、完成者、情侣昵称、共同记录和私密留言都围绕两个人设计。
- **可选同步**：同步是增强能力，不是启动条件；用户自行持有云函数、对象存储和密钥。

## 功能一览

| 场景 | 已实现能力 |
| --- | --- |
| **时光首页** | 时段与特殊日期问候、相伴天数、每日打卡、连续天数、打卡历史、恋爱时间轴 |
| **纪念日** | 多纪念日管理、周年计算、下一个特别日期倒数 |
| **相册** | 本地照片导入、分类筛选、九宫格、照片时间轴、全屏查看、编辑与删除恢复 |
| **愿望清单** | 进行中/已完成筛选、进度统计、愿望编辑、完成者与完成时间、完成后写入时光线 |
| **待办与备忘录** | 快速记录、编辑、置顶、作者筛选、中文标签提取、搜索与日期分组 |
| **悄悄话** | 双人私密留言、发送同步、未读状态 |
| **小说共读** | 多源搜索、分类发现、书架、增量抓取、章节按需加载、滚动/翻页阅读器、预取与阅读进度 |
| **本地音乐** | 扫描设备曲库、播放控制、播放列表、循环/随机模式、迷你播放器、App 相册回忆轮播 |
| **番茄钟** | 专注/休息阶段、自定义时长、标签、会话记录与专注统计 |
| **情侣互动** | 双人轮答恋爱测试、每日固定缘分签与情侣小行动 |
| **小游戏与工具** | 打砖块、俄罗斯方块、秒表、随机数 |
| **双人同步** | 6 位情侣码配对，同步愿望、待办、时光、打卡、纪念日、悄悄话与相册；照片原图使用 COS |

### 最近完成

- 恋爱测试：双方轮流完成 8 道偏好题，隐藏交接答案，最后生成默契度和逐题反馈。
- 每日缘分签：按日期和情侣昵称稳定生成当天签文、缘分温度、幸运时刻与一件可执行的小行动。
- 同步安全加固：全局入口密钥之外增加每个房间的独立令牌，旧版弱鉴权房间安全停用。
- 同步初始化与数据库启动保护：数据库打开失败时保留原始错误，不用删除用户数据作为兜底。
- 迷你播放器手势：左右滑动越过阈值即可暂停并关闭，未达到阈值时平滑回弹。

完整版本内容见 [v1.1.0 更新日志](version/1.1.0/更新日志.md)。

## 快速开始

### 环境要求

- Flutter SDK 3.x；项目 Dart SDK 约束为 `^3.5.4`
- Android Studio 与可用的 Android SDK，或 macOS 上的 Xcode
- Android 真机/模拟器或 iOS 真机/模拟器

### 本地运行

```bash
git clone https://github.com/Aetik-yue/NZY.git
cd NZY/love_space
flutter pub get
flutter run
```

首次启动会创建本地 Isar 数据库并写入基础设置。没有同步配置时，App 会自动保持纯本地模式，不影响相册、愿望、小说、音乐或其他功能。

### 常用开发检查

```bash
cd love_space
dart format --set-exit-if-changed lib test
flutter analyze
flutter test
```

当前测试套件包含 **173 项测试**，覆盖核心日期逻辑、Repository、小说爬虫、同步引擎、音乐播放器、小游戏、番茄钟和主要页面交互。

云函数测试单独运行：

```bash
cd serverless
npm install
npm test
```

## 可选：启用双人同步

同步后端位于 `serverless/`，使用腾讯云 SCF 承载 Node.js 云函数、COS 保存同步文档与照片对象。详细创建步骤、权限配置和常见问题请阅读 [双人同步部署指南](love_space/docs/SYNC_SETUP.md)。

部署完成后，在运行或构建时注入云函数地址和密钥：

```bash
flutter run --dart-define=SYNC_API_URL=你的云函数URL --dart-define=SYNC_SECRET=至少32位随机密钥
```

发布 Android APK：

```bash
flutter build apk --release --dart-define=SYNC_API_URL=你的云函数URL --dart-define=SYNC_SECRET=至少32位随机密钥
```

重要安全约束：

- `SYNC_SECRET` 必须至少 32 个字符，并与云函数环境变量保持一致。
- 密钥只能通过 `--dart-define` 注入，禁止写入源码、README 示例或 Git 历史。
- 创建或加入房间后，服务端还会为每台设备签发独立房间令牌。
- 从仅使用全局密钥的旧版本升级后，需要重新创建和加入房间；本地数据不会因此删除。
- 未满足安全配置时，同步入口显示未启用，其余功能继续以纯本地模式工作。

## 构建发布

```bash
# Android APK
cd love_space
flutter build apk --release

# Android App Bundle
flutter build appbundle --release

# iOS（需要 macOS + Xcode）
flutter build ios --release
```

如果发布包需要双人同步，请在对应构建命令后加入 `SYNC_API_URL` 和 `SYNC_SECRET` 两个 `--dart-define` 参数。仓库不保存 Android release keystore；正式发布前还需要配置自己的签名方案。历史已安装版本能否直接覆盖升级，取决于新包是否继续使用相同签名。

## 技术架构

| 层级 | 主要技术与职责 |
| --- | --- |
| **界面层** | Flutter Material 3、功能页面、共享组件、暖奶油粉设计令牌 |
| **状态层** | Riverpod Provider、StreamProvider、页面状态与依赖注入 |
| **数据层** | Repository 模式、Isar 本地数据库、shared_preferences 同步状态 |
| **内容层** | `http`、`html`、`charset`，用于小说发现、抓取与 GBK 内容解析 |
| **媒体层** | `image_picker`、`just_audio`、`on_audio_query` |
| **同步层** | 本地对账引擎、LWW 冲突处理、删除墓碑、照片上传/下载 |
| **云端** | 腾讯云 SCF、API 网关、COS、Node.js、`cos-nodejs-sdk-v5` |

核心数据流：

```text
Flutter 页面
    ↓ ref.watch / ref.read
Riverpod Provider
    ↓
Repository
    ↓
Isar 本地数据库
    ↓（启用同步时）
同步引擎 → SCF 云函数 → COS
```

## 项目结构

```text
.
├── love_space/                    # Flutter 客户端
│   ├── lib/
│   │   ├── app/                   # App 根节点、主题与设计令牌
│   │   ├── core/                  # 日期、网络、同步协议等跨层能力
│   │   ├── data/
│   │   │   ├── crawler/           # 小说爬虫与内容清洗
│   │   │   ├── database/          # Isar Schema、启动与种子数据
│   │   │   ├── models/            # Isar 数据模型
│   │   │   ├── providers/         # Riverpod Provider 集中定义
│   │   │   ├── repositories/      # 本地数据访问层
│   │   │   └── sync/              # 对账引擎与照片同步
│   │   ├── features/
│   │   │   ├── home/ album/ wishes/ anniversary/
│   │   │   ├── memo/ secrets/ profile/
│   │   │   ├── novel/ music/ pomodoro/
│   │   │   ├── couple_fun/ games/ tools/
│   │   │   └── ...
│   │   └── shared/                # 通用布局、组件与工具
│   ├── test/                      # 单元、Repository 与 Widget 测试
│   ├── android/                   # Android 工程
│   ├── ios/                       # iOS 工程
│   └── pubspec.yaml
├── serverless/                    # SCF + COS 同步云函数及测试
├── docs/                          # 功能设计与实施记录
├── version/                       # 各版本更新日志
├── CLAUDE.md                      # 项目架构与编码规范
└── README.md
```

## 进一步阅读

- [编码与架构规范](CLAUDE.md)
- [Flutter 端系统设计](love_space/docs/system_design.md)
- [双人同步部署指南](love_space/docs/SYNC_SETUP.md)
- [开发完成清单](love_space/DEVELOPMENT_CHECKLIST.md)
- [v1.1.0 更新日志](version/1.1.0/更新日志.md)

## 参与开发

1. Fork 仓库并从最新的 `main` 创建功能分支。
2. 遵守 [CLAUDE.md](CLAUDE.md) 中的分层、设计令牌和测试规范。
3. 修改前确认本地工作区没有会被覆盖的未提交文件。
4. 提交前运行 `dart format`、`flutter analyze` 和 `flutter test`。
5. 发起 Pull Request，并说明功能行为、数据结构变化和验证结果。

## 许可说明

仓库当前未附带开源许可证。除 GitHub 平台授予的浏览和 Fork 权限外，不应默认获得复制、分发或商业使用授权；如需复用，请先联系仓库所有者。
