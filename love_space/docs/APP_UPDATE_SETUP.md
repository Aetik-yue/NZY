# 应用内更新配置与发布

以越之名 v1.4.0 起支持 Android 应用内更新：打开应用时自动检查公开 GitHub Release，发现新版本后弹窗，下载 APK、校验 SHA-256，再调起 Android 系统安装器。

> 第一次启用必须手动安装一次 v1.4.0 或更高版本；之后的版本才能自动更新。

## 工作方式

```text
应用启动（每天最多一次）
    ↓
GitHub Releases API（可选静态镜像优先）
    ↓ 有更高版本
更新弹窗 → 下载 APK → SHA-256 校验 → 系统安装页 → 用户确认覆盖安装
```

- 更新源：`https://api.github.com/repos/Aetik-yue/NZY/releases/latest`
- 仅检查正式 Release，自动忽略 draft / prerelease
- 自动检查每 24 小时最多一次；也可以在「我的 → 设置 → 应用更新」手动检查
- 下载地址是 GitHub Release 资产（公开仓库），无需在 App 内保存任何 Token
- 安装包保存在应用私有缓存 `love_updates/update.apk`，通过 FileProvider 交给系统安装器
- Android 8.0 及以上首次安装需要允许「以越之名」安装未知来源应用；授权后返回 App 点「重试安装」即可，无需重新下载

## 发布新版本

### 1. 修改版本号和更新日志

```yaml
# love_space/pubspec.yaml
version: 1.4.1+141
```

在 `version/1.4.1/更新日志.md` 写入本次更新内容。应用弹窗会展示 GitHub Release 的说明，因此发布时把这份日志作为 Release 说明。

### 2. 构建并生成校验文件

在仓库根目录运行：

```powershell
powershell -File scripts/build_android_release.ps1 `
  -SyncApiUrl "你的云函数URL" `
  -SyncSecret "至少32位同步密钥"
```

也可以使用 Android Studio 的 Flutter build 流程，但必须自己生成 SHA-256 文件。脚本会：

1. 读取 `pubspec.yaml` 的版本号；
2. 执行 `flutter build apk --release`；
3. 把 APK 复制为 `version/<版本>/YiYueZhiMing-v<版本>.apk`；
4. 生成同目录的 `.apk.sha256` 和可选的 `latest.json`；
5. 打印 APK 大小与 SHA-256。

如果已有构建好的 APK：

```powershell
powershell -File scripts/build_android_release.ps1 -SkipBuild `
  -ApkPath "build\app\outputs\flutter-apk\app-release.apk"
```

### 3. 创建 GitHub Release

先提交并推送版本改动，再运行：

```powershell
powershell -File scripts/build_android_release.ps1 `
  -SyncApiUrl "你的云函数URL" `
  -SyncSecret "至少32位同步密钥" `
  -Publish
```

脚本会调用 `gh release create`，创建标签 `vX.Y.Z` 并上传：

- `YiYueZhiMing-vX.Y.Z.apk`
- `YiYueZhiMing-vX.Y.Z.apk.sha256`

仓库必须保持 **public**，否则手机端无法匿名读取 Release。

手动发布也可以：在 GitHub 创建 Release，Tag 使用 `vX.Y.Z`，上传 APK 和同名 `.sha256` 文件，并把 `version/X.Y.Z/更新日志.md` 粘贴为 Release 说明。

### 资产命名规则

客户端按以下顺序选择 APK：

1. `YiYueZhiMing-vX.Y.Z.apk`
2. `YiYueZhiMing-vX.Y.Z-android.apk`
3. Release 中的其他任意 `.apk`

校验值来源：

1. GitHub 资产自带的 `digest: sha256:...`（如果 GitHub 返回）
2. 同名 `APK文件名.sha256`
3. `SHA256SUMS` / `sha256sums.txt` / `checksums.txt`

`.sha256` 文件支持单独一行哈希，或 `哈希  文件名` 两种格式。

### 签名要求

新 APK 必须与手机上已安装版本使用 **同一个签名证书**，否则 Android 会拒绝覆盖安装（提示签名不一致）。当前 `android/app/build.gradle` 使用 `signingConfigs.debug`；如果换电脑构建，请保证 debug keystore 一致，或改为固定的 release keystore 后继续使用同一份证书。

同时 `applicationId` 必须保持 `com.lovespace.love_space`，版本号必须递增。

## 可选：静态镜像

国内网络访问 GitHub API 不稳定时，可以给安装包配一个 HTTPS 静态目录，并在构建时注入镜像地址：

```powershell
powershell -File scripts/build_android_release.ps1 `
  -UpdateBaseUrl "https://你的镜像域名/app/"
```

镜像布局：

```text
https://你的镜像域名/app/
  latest.json
  vX.Y.Z/
    YiYueZhiMing-vX.Y.Z.apk
    YiYueZhiMing-vX.Y.Z.apk.sha256
```

`latest.json` 由发布脚本生成在 `version/X.Y.Z/latest.json`，格式：

```json
{
  "version": "1.5.0",
  "tagName": "v1.5.0",
  "name": "以越之名 v1.5.0",
  "notes": "更新说明",
  "apkName": "YiYueZhiMing-v1.5.0.apk",
  "apkSize": 67355394,
  "sha256": "....",
  "publishedAt": "2026-10-22T08:00:00Z"
}
```

先上传 APK 和 `.sha256`，最后替换 `latest.json`。客户端会先尝试镜像（5 秒超时），镜像不可用或清单位于异常时自动回退 GitHub；下载时镜像失败也会自动改用 GitHub 资产地址。

## 安全提示

- GitHub Release 资产是公开可下载的。APK 中包含构建时注入的 `SYNC_SECRET`，因此不要把带正式密钥的安装包上传到公开仓库或公开网盘；更新包应只通过 GitHub Release 或自建镜像分发。
- 如果仓库从私有切换为公开，旧 Release 中的 APK 也会变为公开。建议轮换 `SYNC_SECRET` 并重新部署云函数，再重新构建新版本；旧安装包中的密钥随即失效。
- 每个配对房间仍有服务端签发的独立令牌，轮换全局密钥不会删除本地数据，但旧版本需要重新创建和加入房间。
- `scripts/build_android_release.ps1` 生成的 APK、`.sha256` 和 `latest.json` 已在 `.gitignore` 中排除，避免误提交。

## 常见问题

**启动后没有弹更新**

- 确认手机上的版本低于 GitHub 最新 Release 的 `tag_name`；
- 自动检查 24 小时一次，可在设置页手动触发；
- 确认仓库仍是 public，且 Release 不是 draft / prerelease；
- 国内网络可能访问不了 `api.github.com`，配置静态镜像或检查网络。

**下载完成但无法安装**

- 首次需要允许「安装未知来源应用」；
- 新包签名必须与旧包一致；
- 确认 `applicationId` 没有改变。

**提示缺少 SHA-256 校验文件**

Release 中必须上传 `APK文件名.sha256`，或让 GitHub 返回资产 digest。

**手动检查提示无法连接 GitHub**

GitHub API 在部分网络环境下不可达。可以配置 `UPDATE_BASE_URL` 静态镜像，或更换网络后重试。
