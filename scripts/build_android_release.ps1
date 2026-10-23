<#
.SYNOPSIS
  构建、校验并可选发布「以越之名」Android 更新包。

.DESCRIPTION
  版本号以 love_space/pubspec.yaml 的 `version: x.y.z+build` 为准。
  产物写入 version/<version>/：
    - YiYueZhiMing-v<version>.apk
    - YiYueZhiMing-v<version>.apk.sha256
    - latest.json（可选镜像使用的清单）
  使用 -Publish 时会调用 gh 创建 GitHub Release（公开仓库）。
  应用内更新要求新包与已安装版本使用相同签名证书。

.EXAMPLE
  powershell -File scripts/build_android_release.ps1 `
    -SyncApiUrl "https://xxx.tencentscf.com" `
    -SyncSecret "至少32位密钥" `
    -Publish

.EXAMPLE
  powershell -File scripts/build_android_release.ps1 -SkipBuild -Publish
#>
[CmdletBinding()]
param(
    [string]$SyncApiUrl = '',
    [string]$SyncSecret = '',
    [string]$UpdateBaseUrl = '',
    [string]$NotesFile = '',
    [string]$ApkPath = '',
    [switch]$SkipBuild,
    [switch]$Publish
)

$ErrorActionPreference = 'Stop'
$RepoRoot = Split-Path -Parent $PSScriptRoot
$AppRoot = Join-Path $RepoRoot 'love_space'
$FlutterApk = Join-Path $AppRoot 'build\app\outputs\flutter-apk\app-release.apk'
$GitHubRepo = 'Aetik-yue/NZY'

# gh release create 会把标签指向远程默认分支最新提交；未提交的改动不会进入标签。
if ($Publish) {
    $dirty = & git -C $RepoRoot status --porcelain
    if (-not [string]::IsNullOrWhiteSpace(($dirty -join ''))) {
        throw '发布前请先提交并推送当前改动，确保 GitHub Release 标签包含本次代码'
    }
    $branch = (& git -C $RepoRoot rev-parse --abbrev-ref HEAD).Trim()
    $localCommit = (& git -C $RepoRoot rev-parse HEAD).Trim()
    $remoteCommit = & git -C $RepoRoot rev-parse --verify --quiet "origin/$branch" 2>$null
    if ($LASTEXITCODE -eq 0 -and $localCommit -ne $remoteCommit.Trim()) {
        throw "当前分支 $branch 还有未推送的提交，请先 git push 再发布"
    }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Text)
    $encoding = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($Path, $Text, $encoding)
}

$pubspecPath = Join-Path $AppRoot 'pubspec.yaml'
if (-not (Test-Path $pubspecPath)) {
    throw "找不到 pubspec.yaml：$pubspecPath"
}
$pubspec = Get-Content -Raw -Encoding UTF8 $pubspecPath
if ($pubspec -notmatch '(?m)^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*$') {
    throw 'pubspec.yaml 的 version 必须写成 x.y.z+build 形式'
}
$version = $Matches[1]
$buildNumber = $Matches[2]
$tagName = "v$version"
$versionRoot = Join-Path $RepoRoot "version\$version"
$apkName = "YiYueZhiMing-$tagName.apk"
$releaseApk = Join-Path $versionRoot $apkName
$checksumFile = "$releaseApk.sha256"
$manifestFile = Join-Path $versionRoot 'latest.json'

if ([string]::IsNullOrWhiteSpace($NotesFile)) {
    $candidate = Join-Path $versionRoot '更新日志.md'
    if (Test-Path $candidate) { $NotesFile = $candidate }
}

New-Item -ItemType Directory -Force -Path $versionRoot | Out-Null

if (-not $SkipBuild -and [string]::IsNullOrWhiteSpace($SyncSecret)) {
    Write-Warning '未注入 SYNC_SECRET，本次构建会禁用双人同步。仅用于本地验证时可忽略。'
}

if (-not $SkipBuild) {
    $defines = @()
    if (-not [string]::IsNullOrWhiteSpace($SyncApiUrl)) {
        $defines += "--dart-define=SYNC_API_URL=$SyncApiUrl"
    }
    if (-not [string]::IsNullOrWhiteSpace($SyncSecret)) {
        $defines += "--dart-define=SYNC_SECRET=$SyncSecret"
    }
    if (-not [string]::IsNullOrWhiteSpace($UpdateBaseUrl)) {
        $defines += "--dart-define=UPDATE_BASE_URL=$UpdateBaseUrl"
    }

    Write-Host "构建 v$version+$buildNumber ..." -ForegroundColor Cyan
    Push-Location $AppRoot
    try {
        & flutter build apk --release @defines
        if ($LASTEXITCODE -ne 0) {
            throw "flutter build 失败（退出码 $LASTEXITCODE）"
        }
    } finally {
        Pop-Location
    }
    if (-not (Test-Path $FlutterApk)) {
        throw "找不到构建产物：$FlutterApk"
    }
    Copy-Item -Force $FlutterApk $releaseApk
} elseif (-not [string]::IsNullOrWhiteSpace($ApkPath)) {
    if (-not (Test-Path $ApkPath)) { throw "找不到 APK：$ApkPath" }
    $sourceApk = (Resolve-Path $ApkPath).Path
    if ($sourceApk -ne $releaseApk) {
        Copy-Item -Force $sourceApk $releaseApk
    }
} elseif (-not (Test-Path $releaseApk)) {
    throw "跳过构建时需提供 -ApkPath，或已存在 $releaseApk"
}

$item = Get-Item $releaseApk
$hash = (Get-FileHash -Algorithm SHA256 -Path $releaseApk).Hash.ToLowerInvariant()
Write-Utf8NoBom $checksumFile "$hash  $apkName`n"

$notes = if (-not [string]::IsNullOrWhiteSpace($NotesFile)) {
    (Get-Content -Raw -Encoding UTF8 $NotesFile).Trim()
} else {
    "以越之名 $tagName"
}

$manifest = [ordered]@{
    version = $version
    tagName = $tagName
    name = "以越之名 $tagName"
    notes = $notes
    apkName = $apkName
    apkSize = $item.Length
    sha256 = $hash
    publishedAt = (Get-Date).ToUniversalTime().ToString('o')
}
$manifestJson = $manifest | ConvertTo-Json -Depth 5
Write-Utf8NoBom $manifestFile "$manifestJson`n"

Write-Host ''
Write-Host "APK      : $releaseApk"
Write-Host "大小     : $($item.Length) 字节"
Write-Host "SHA-256  : $hash"
Write-Host "校验文件 : $checksumFile"
Write-Host "镜像清单 : $manifestFile"
Write-Host ''

if ($Publish) {
    if (-not (Get-Command gh -ErrorAction SilentlyContinue)) {
        throw '未找到 gh CLI，请先安装并登录，或手动在 GitHub 创建 Release'
    }
    # “release not found” 是 gh 的 stderr 正常输出；交给 cmd 吞掉，
    # 避免 PowerShell 5.1 在 $ErrorActionPreference=Stop 下把它包装成错误中止脚本。
    $null = cmd /c "gh release view $tagName --repo $GitHubRepo 2>nul"
    if ($LASTEXITCODE -eq 0) {
        throw "GitHub Release $tagName 已存在，请先处理旧发布，避免覆盖已下载版本"
    }
    Write-Host "创建 GitHub Release $tagName ..." -ForegroundColor Cyan
    if (-not [string]::IsNullOrWhiteSpace($NotesFile)) {
        & gh release create $tagName $releaseApk $checksumFile `
            --repo $GitHubRepo `
            --title "以越之名 $tagName" `
            --notes-file $NotesFile
    } else {
        & gh release create $tagName $releaseApk $checksumFile `
            --repo $GitHubRepo `
            --title "以越之名 $tagName" `
            --notes "以越之名 $tagName"
    }
    if ($LASTEXITCODE -ne 0) {
        throw "gh release create 失败（退出码 $LASTEXITCODE）"
    }
    Write-Host "发布完成：https://github.com/$GitHubRepo/releases/tag/$tagName" -ForegroundColor Green
} else {
    Write-Host '未发布。确认无误后追加 -Publish，或手动上传 APK 与 .sha256 到 GitHub Release。' -ForegroundColor Yellow
}

if (-not [string]::IsNullOrWhiteSpace($UpdateBaseUrl)) {
    Write-Host ''
    Write-Host '镜像目录上传方式：' -ForegroundColor Cyan
    Write-Host "  $releaseApk -> <镜像根>/$tagName/$apkName"
    Write-Host "  $checksumFile -> <镜像根>/$tagName/$apkName.sha256"
    Write-Host "  $manifestFile -> <镜像根>/latest.json"
}
