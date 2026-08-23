# 以越之名 · 情侣恋爱空间

<p align="center">
  <img src="https://img.shields.io/badge/Flutter-3.0+-02569B?logo=flutter&logoColor=white" alt="Flutter" />
  <img src="https://img.shields.io/badge/Dart-3.5+-0175C2?logo=dart&logoColor=white" alt="Dart" />
  <img src="https://img.shields.io/badge/Riverpod-2.5-00B4D8?logoColor=white" alt="Riverpod" />
  <img src="https://img.shields.io/badge/license-MIT-green" alt="MIT License" />
</p>

<p align="center"><b>记录你们的每一个瞬间，守护你们的每一份心愿。</b></p>

---

## ✨ 项目介绍

**以越之名**是一款为情侣打造的恋爱纪念应用。用粉嫩的渐变界面、胶囊式导航和卡片式布局，把相伴的天数、共同的相册、未完成的心愿，都安放在一个专属的二人空间里。

> 本项目使用 **Flutter** 构建，支持 **Android / iOS** 双端。

---

## 📱 功能模块

| 模块 | 说明 |
| :---: | --- |
| 🏠 **时光** | 问候区、相伴天数纪念日卡片、每日打卡、快捷入口、恋爱时间轴 |
| 📷 **相册** | 筛选标签、九宫格照片墙，记录每一个值得珍藏的画面 |
| ⭐ **愿望清单** | 进度卡片 + 愿望列表，把"一起做的事"一个个打上勾 |
| 📝 **待办与悄悄话** | 标签待办、优先级、双人留言与未读状态 |
| 📚 **小说阅读** | 多源搜索、书架、章节按需抓取、预取与分页阅读器 |
| 🎵 **音乐与专注** | 本地音乐播放、番茄钟与专注统计 |
| 🎮 **小游戏** | 打砖块、俄罗斯方块 |
| 🔄 **双人同步** | 腾讯云 SCF + COS 房间配对，同步时光、愿望、待办、相册和留言 |
| 👫 **我的** | 情侣信息、相伴统计、全部功能、同步与设置入口 |

---

## 🎨 设计语言

- **配色**：粉色 + 蜜桃渐变（`#FF6B8F → #FF8FB1`），辅以奶油白底
- **组件**：圆角卡片、悬浮胶囊导航、柔和投影
- **字体**：Google Fonts（中文优先）
- **图标**：Cupertino / Material rounded 风格

---

## 🛠 技术栈

| 类别 | 选型 |
| --- | --- |
| 框架 | Flutter 3.x / Dart 3.5+ |
| 状态管理 | [Riverpod](https://riverpod.dev/) `flutter_riverpod` |
| 本地存储 | Isar + shared_preferences |
| 网络与爬虫 | http + html + charset（GBK） |
| 媒体 | image_picker + just_audio + on_audio_query |
| 云同步 | 腾讯云 SCF + COS（Node.js 云函数） |

---

## 🚀 快速开始

### 环境要求

- Flutter SDK `^3.5.4`
- Dart SDK `^3.5.4`
- Android Studio / Xcode（对应平台）

### 安装运行

```bash
# 1. 进入项目目录
cd love_space

# 2. 安装依赖
flutter pub get

# 3. 运行（连接设备或启动模拟器后）
flutter run
```

### 构建发布

```bash
# Android APK（同步密钥不得写入仓库）
flutter build apk --release \
  --dart-define=SYNC_API_URL=你的云函数URL \
  --dart-define=SYNC_SECRET=你的随机密钥

# Android App Bundle
flutter build appbundle --release

# iOS
flutter build ios --release
```

---

## 📁 项目结构

```
love_space/
├── lib/
│   ├── main.dart                  # 应用入口
│   ├── app/
│   │   ├── app.dart               # MaterialApp 根节点
│   │   └── theme/                 # 颜色 / 文字样式 / 主题
│   ├── features/
│   │   ├── home/                  # 时光
│   │   ├── album/                 # 相册
│   │   ├── wishes/                # 愿望清单
│   │   ├── memo/                  # 待办 / 备忘录
│   │   ├── novel/                 # 小说书架 / 阅读器
│   │   ├── music/                 # 本地音乐
│   │   ├── games/                 # 小游戏
│   │   ├── secrets/               # 双人留言
│   │   └── profile/               # 我的 / 同步配对
│   ├── data/
│   │   ├── crawler/               # 多源小说爬虫
│   │   ├── database/              # Isar 初始化与种子数据
│   │   ├── repositories/          # 数据仓库
│   │   └── sync/                  # 双人同步引擎与照片同步
│   └── shared/
│       ├── layouts/main_shell.dart  # 主壳层 + 底部导航
│       └── widgets/               # 通用组件
├── android/                       # Android 工程
├── ios/                           # iOS 工程
├── test/                          # 测试
├── pubspec.yaml
└── README.md
serverless/                        # SCF + COS 同步云函数
version/                           # 各版本更新日志（APK 由 Release 分发）
```

双人同步的部署与打包参数见
[`love_space/docs/SYNC_SETUP.md`](love_space/docs/SYNC_SETUP.md)。正式发布前还需配置
自己的 Android release keystore；仓库默认不保存签名凭据。

---

## 🤝 贡献

欢迎提交 Issue 与 Pull Request。

1. Fork 本仓库
2. 创建你的功能分支 (`git checkout -b feature/xxx`)
3. 提交更改 (`git commit -m 'Add xxx'`)
4. 推送到分支 (`git push origin feature/xxx`)
5. 打开 Pull Request

---

## 📄 协议

[MIT](LICENSE) © 以越之名
