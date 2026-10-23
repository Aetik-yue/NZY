import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:pub_semver/pub_semver.dart';

import '../domain/app_release.dart';

/// 更新源返回无效数据、未发布版本或校验信息缺失时抛出的可展示异常。
class UpdateCheckException implements Exception {
  const UpdateCheckException(this.message);

  final String message;

  @override
  String toString() => message;
}

abstract class UpdateRepository {
  Future<AppRelease> fetchLatestRelease();

  void close();
}

/// 从公开 GitHub Release 读取最新 Android APK 与其 SHA-256。
///
/// 可通过 `--dart-define=UPDATE_BASE_URL=https://.../` 配置一个静态镜像目录，
/// 镜像内放置 `latest.json` 和 `vX.Y.Z/` 安装包；镜像不可用时自动回退 GitHub。
class GitHubReleaseRepository implements UpdateRepository {
  GitHubReleaseRepository({
    http.Client? httpClient,
    String updateBaseUrl = const String.fromEnvironment('UPDATE_BASE_URL'),
  })  : _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null,
        _mirrorBase = _parseMirrorBase(updateBaseUrl);

  static const repositoryUrl = 'https://github.com/Aetik-yue/NZY';
  static const _latestReleaseApi =
      'https://api.github.com/repos/Aetik-yue/NZY/releases/latest';
  static const _userAgent = 'LoveSpace-Android-Updater';

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final Uri? _mirrorBase;

  @override
  Future<AppRelease> fetchLatestRelease() async {
    final mirror = _mirrorBase;
    if (mirror != null) {
      try {
        return await _fetchMirror(mirror);
      } on Exception {
        // 镜像未配置完成、离线或清单损坏时继续使用 GitHub。
      }
    }
    return _fetchGitHub();
  }

  Future<AppRelease> _fetchGitHub() async {
    final http.Response response;
    try {
      response = await _httpClient.get(
        Uri.parse(_latestReleaseApi),
        headers: const {
          'Accept': 'application/vnd.github+json',
          'X-GitHub-Api-Version': '2022-11-28',
          'User-Agent': _userAgent,
        },
      ).timeout(const Duration(seconds: 15));
    } on http.ClientException {
      throw const UpdateCheckException('无法连接 GitHub，请检查网络后重试');
    }

    if (response.statusCode == 404) {
      throw const UpdateCheckException('暂时还没有可用的正式版本');
    }
    if (response.statusCode == 403) {
      throw const UpdateCheckException('GitHub 更新服务暂时受限，请稍后重试');
    }
    if (response.statusCode != 200) {
      throw UpdateCheckException(
        'GitHub 返回异常状态（${response.statusCode}），请稍后重试',
      );
    }

    final decoded = _decodeObject(response.bodyBytes);
    if (decoded['draft'] == true || decoded['prerelease'] == true) {
      throw const UpdateCheckException('更新源未提供正式版本');
    }

    final tagName = _requiredString(decoded, 'tag_name');
    final assets = _assets(decoded['assets']);
    final apk = _selectApk(assets, tagName);
    final checksum = apk.sha256 ?? await _fetchChecksum(assets, apk.name);

    return AppRelease(
      version: _parseVersion(tagName),
      tagName: tagName,
      releaseName: _optionalString(decoded['name']) ?? tagName,
      notes: _optionalString(decoded['body'])?.trim() ?? '',
      pageUrl: _optionalHttpsUri(_optionalString(decoded['html_url'])),
      apkName: apk.name,
      apkSize: apk.size,
      sha256: checksum,
      apkUrl: apk.url,
      publishedAt:
          DateTime.tryParse(_optionalString(decoded['published_at']) ?? ''),
    );
  }

  /// 读取静态镜像的 `latest.json`，安装包路径固定为 `vX.Y.Z/文件名`。
  Future<AppRelease> _fetchMirror(Uri base) async {
    final response = await _httpClient.get(
      base.resolve('latest.json'),
      headers: const {'Accept': 'application/json', 'User-Agent': _userAgent},
    ).timeout(const Duration(seconds: 5));
    if (response.statusCode != 200) {
      throw UpdateCheckException('镜像返回异常状态（${response.statusCode}）');
    }
    final decoded = _decodeObject(response.bodyBytes);
    final tagName = _requiredString(decoded, 'tagName');
    final apkName = _requiredString(decoded, 'apkName');
    if (apkName.contains('/') || apkName.contains(r'\')) {
      throw const UpdateCheckException('镜像中的安装包名称无效');
    }
    final apkUrl = base.resolve(
      '${Uri.encodeComponent(tagName)}/${Uri.encodeComponent(apkName)}',
    );
    final fallback = Uri.parse(
      '$repositoryUrl/releases/download/'
      '${Uri.encodeComponent(tagName)}/${Uri.encodeComponent(apkName)}',
    );

    return AppRelease(
      version: _parseVersion(tagName),
      tagName: tagName,
      releaseName: _optionalString(decoded['name']) ?? tagName,
      notes: _optionalString(decoded['notes'])?.trim() ?? '',
      pageUrl: Uri.parse('$repositoryUrl/releases/tag/$tagName'),
      apkName: apkName,
      apkSize: _requiredInt(decoded, 'apkSize'),
      sha256: _requiredSha256(decoded),
      apkUrl: apkUrl,
      fallbackUrls: [fallback],
      publishedAt:
          DateTime.tryParse(_optionalString(decoded['publishedAt']) ?? ''),
    );
  }

  Future<String> _fetchChecksum(
      List<_ReleaseAsset> assets, String apkName) async {
    final target = '$apkName.sha256'.toLowerCase();
    _ReleaseAsset? checksumAsset;
    for (final asset in assets) {
      if (asset.name.toLowerCase() == target) {
        checksumAsset = asset;
        break;
      }
    }
    if (checksumAsset == null) {
      const checksumNames = {'sha256sums', 'sha256sums.txt', 'checksums.txt'};
      for (final asset in assets) {
        if (checksumNames.contains(asset.name.toLowerCase())) {
          checksumAsset = asset;
          break;
        }
      }
    }
    if (checksumAsset == null) {
      throw const UpdateCheckException('最新版本缺少 SHA-256 校验文件');
    }

    final response = await _httpClient.get(
      checksumAsset.url,
      headers: const {'User-Agent': _userAgent},
    ).timeout(const Duration(seconds: 15));
    if (response.statusCode != 200) {
      throw UpdateCheckException('无法获取安装包校验值（${response.statusCode}）');
    }
    if (response.bodyBytes.length > 64 * 1024) {
      throw const UpdateCheckException('安装包校验文件过大');
    }

    final content = utf8.decode(response.bodyBytes).trim();
    final bareHash = RegExp(r'^[a-fA-F0-9]{64}$');
    if (bareHash.hasMatch(content)) return content.toLowerCase();

    final namedHash = RegExp(r'^([a-fA-F0-9]{64})\s+\*?(.+)$');
    for (final line in const LineSplitter().convert(content)) {
      final match = namedHash.firstMatch(line.trim());
      if (match != null && match.group(2) == apkName) {
        return match.group(1)!.toLowerCase();
      }
    }
    throw const UpdateCheckException('安装包的 SHA-256 校验值无效或未匹配当前 APK');
  }

  @override
  void close() {
    if (_ownsHttpClient) _httpClient.close();
  }
}

class _ReleaseAsset {
  const _ReleaseAsset({
    required this.name,
    required this.url,
    required this.size,
    this.sha256,
  });

  final String name;
  final Uri url;
  final int size;
  final String? sha256;
}

List<_ReleaseAsset> _assets(Object? value) {
  if (value is! List) {
    throw const UpdateCheckException('版本中没有可下载的文件');
  }
  return value.whereType<Map>().map((asset) {
    final map = Map<String, dynamic>.from(asset);
    return _ReleaseAsset(
      name: _requiredString(map, 'name'),
      url: _requiredHttpsUri(map, 'browser_download_url'),
      size: map['size'] is int ? map['size'] as int : 0,
      sha256: _parseDigest(map['digest']),
    );
  }).toList(growable: false);
}

_ReleaseAsset _selectApk(List<_ReleaseAsset> assets, String tag) {
  final candidates = assets
      .where((asset) =>
          asset.name.toLowerCase().endsWith('.apk') &&
          !asset.name.contains('/') &&
          !asset.name.contains(r'\'))
      .toList();
  if (candidates.isEmpty) {
    throw const UpdateCheckException('最新版本中没有 Android APK');
  }

  final preferred = [
    'YiYueZhiMing-$tag.apk',
    'YiYueZhiMing-$tag-android.apk',
  ];
  for (final name in preferred) {
    for (final candidate in candidates) {
      if (candidate.name == name) return candidate;
    }
  }
  candidates.sort((a, b) {
    final aPreferred = a.name.toLowerCase().contains('android') ? 0 : 1;
    final bPreferred = b.name.toLowerCase().contains('android') ? 0 : 1;
    return aPreferred.compareTo(bPreferred);
  });
  return candidates.first;
}

String? _parseDigest(Object? value) {
  if (value is! String) return null;
  return RegExp(r'^sha256:([a-fA-F0-9]{64})$')
      .firstMatch(value)
      ?.group(1)
      ?.toLowerCase();
}

Uri? _parseMirrorBase(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null ||
      uri.scheme != 'https' ||
      uri.host.isEmpty ||
      uri.hasQuery ||
      uri.hasFragment ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return uri.replace(
    path: uri.path.endsWith('/') ? uri.path : '${uri.path}/',
  );
}

Map<String, dynamic> _decodeObject(List<int> bytes) {
  final Object? decoded;
  try {
    decoded = jsonDecode(utf8.decode(bytes));
  } on FormatException {
    throw const UpdateCheckException('版本信息格式不正确');
  }
  if (decoded is! Map) {
    throw const UpdateCheckException('版本信息格式不正确');
  }
  return Map<String, dynamic>.from(decoded);
}

String _requiredString(Map<String, dynamic> json, String key) {
  final value = _optionalString(json[key]);
  if (value == null || value.isEmpty) {
    throw const UpdateCheckException('版本信息缺少必要字段');
  }
  return value;
}

int _requiredInt(Map<String, dynamic> json, String key) {
  final value = json[key];
  if (value is! int || value <= 0) {
    throw const UpdateCheckException('版本信息缺少有效大小');
  }
  return value;
}

String _requiredSha256(Map<String, dynamic> json) {
  final value = json['sha256'];
  if (value is! String || !RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(value)) {
    throw const UpdateCheckException('版本信息缺少有效校验值');
  }
  return value.toLowerCase();
}

String? _optionalString(Object? value) => value is String ? value : null;

Uri _requiredHttpsUri(Map<String, dynamic> json, String key) {
  final uri = _optionalHttpsUri(_optionalString(json[key]));
  if (uri == null) {
    throw const UpdateCheckException('版本下载地址不安全或无效');
  }
  return uri;
}

Uri? _optionalHttpsUri(String? value) {
  if (value == null || value.isEmpty) return null;
  final uri = Uri.tryParse(value);
  if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) return null;
  return uri;
}

Version _parseVersion(String tagName) {
  try {
    return AppRelease.parseVersion(tagName);
  } on FormatException {
    throw UpdateCheckException('无法识别版本标签：$tagName');
  }
}
