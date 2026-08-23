# 双人同步 · 部署指南（腾讯云 SCF + COS）

双人同步后端为**自建云函数（腾讯云 Serverless）**，数据存 COS。公网可达、免备案、
免费额度内运行（云函数 40 万次调用/月 + COS 免费额度），适合异地双机同步。

> ⚠️ 本方案替代已不可用的 CloudBase / LeanCloud。云函数源码见 `serverless/`。

## 部署步骤（一次性，约 15 分钟）

### 1. 创建 COS 存储桶

1. 打开 [腾讯云 COS 控制台](https://console.cloud.tencent.com/cos) → 「创建存储桶」
2. 名称随意（如 `love-space-sync`），地域选**离你近的**（如 `ap-guangzhou` 广州）
3. 访问权限：**私有读写**（数据仅通过云函数签名 URL 访问）
4. 记录：**桶名称**（如 `love-space-sync-1250000000`）和**地域**（如 `ap-guangzhou`）

### 2. 创建云函数

1. 打开 [云函数 SCF 控制台](https://console.cloud.tencent.com/scf) → 「函数服务」→「新建」
2. 运行环境：**Node.js 16.13**；函数名（如 `love-sync`）；地域与 COS 一致
3. 「函数代码」→ 选择「本地上传 zip」→ 上传 `serverless/` 目录打包的 zip
   （内含 `index.js` + `package.json`；控制台会自动安装 `cos-nodejs-sdk-v5` 依赖）
   > 打包方法：在 `serverless/` 目录执行 `npm install` 后，将 `index.js`、`package.json`、`node_modules` 一起压缩为 zip
4. 「环境配置」→ 环境变量：
   | 键 | 值 |
   |---|---|
   | `COS_BUCKET` | 步骤 1 的桶名称 |
   | `COS_REGION` | 步骤 1 的地域 |
   | `SYNC_SECRET` | 至少 32 位的随机密钥，两端 App 需保持一致；不要写进 Git 仓库 |
5. 「权限配置」→ 运行角色选「SCF_QcsRole」（如无则创建，需授予 COS 读写权限）
6. 创建完成

### 3. 创建 API 网关触发器

1. 进入刚创建的函数 → 「触发管理」→「创建触发器」
2. 触发方式：**API 网关触发**
3. API 服务：新建 API 服务 → 路径 `/` → 请求方法 **ANY** → 发布环境 **发布**
4. 创建后复制 **访问路径 URL**（形如 `https://service-xxxx-xxxxx.gz.apigw.tencentcs.com/release/`）

### 4. 配置 Flutter 端

运行/打包时注入（两端一致）：
```bash
flutter run --dart-define=SYNC_API_URL=https://service-xxxx-xxxxx.gz.apigw.tencentcs.com/release \
            --dart-define=SYNC_SECRET=你的随机密钥
flutter build apk --dart-define=SYNC_API_URL=... --dart-define=SYNC_SECRET=...
```

同步密钥没有源码默认值；发布包必须用 `--dart-define` 注入。云函数在未配置
`SYNC_SECRET` 时会拒绝全部请求，避免误部署成无鉴权接口。

## 使用流程

1. 打开 App →「我的」→「双人同步」
2. 一方点「创建房间」→ 生成 6 位情侣码
3. 另一方输码「加入」→ 绑定成功
4. 数据每 60 秒自动同步；悄悄话发送后即时同步；相册打开时同步照片

## 常见问题

- **两端必须在同一网络吗？** 不需要——云函数在公网，异地/不同 WiFi 均可同步（前提是服务器常在线）
- **费用？** 云函数免费额度 40 万次调用/月；COS 新用户 6 个月免费（50GB 存储 + 10GB 流量），之后约 0.1 元/GB/月，个人照片量级几乎可忽略
- **密钥泄露？** `SYNC_SECRET` 仅防陌生人随意读写；泄露后改环境变量 + 两端 dart-define 即可
- **未配置会怎样？** App 正常运行，同步入口显示「未启用」，其余功能 100% 本地可用
