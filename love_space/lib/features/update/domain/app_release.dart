import 'package:pub_semver/pub_semver.dart';

/// 云端发布的一个正式版本。
///
/// 客户端下载后必须用 [sha256] 校验，校验通过才允许交给系统安装器。
class AppRelease {
  const AppRelease({
    required this.version,
    required this.tagName,
    required this.releaseName,
    required this.notes,
    required this.apkName,
    required this.apkSize,
    required this.sha256,
    required this.apkUrl,
    this.fallbackUrls = const [],
    this.pageUrl,
    required this.publishedAt,
  });

  final Version version;
  final String tagName;
  final String releaseName;
  final String notes;
  final String apkName;
  final int apkSize;
  final String sha256;
  final Uri apkUrl;
  final List<Uri> fallbackUrls;
  final Uri? pageUrl;
  final DateTime? publishedAt;

  String get versionName => version.toString();

  /// 弹窗使用纯文本展示更新日志，去掉常用的 Markdown 标记但保留段落与列表。
  String get displayNotes {
    var text = notes;
    text = text.replaceAllMapped(
      RegExp(r'!\[([^\]]*)\]\([^)]*\)'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAllMapped(
      RegExp(r'\[([^\]]+)\]\([^)]*\)'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAll(
      RegExp(r'^[ \t]{0,3}#{1,6}[ \t]*', multiLine: true),
      '',
    );
    text = text.replaceAll(
      RegExp(r'^[ \t]*[-*+][ \t]+', multiLine: true),
      '• ',
    );
    text = text.replaceAllMapped(
      RegExp(r'`([^`]*)`'),
      (match) => match.group(1) ?? '',
    );
    text = text.replaceAll('**', '').replaceAll('__', '');
    text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
    return text.trim();
  }

  /// GitHub 标签约定为 `vX.Y.Z`，同时兼容没有 `v` 的标签。
  static Version parseVersion(String value) {
    final normalized = value.trim().replaceFirst(RegExp(r'^[vV]'), '');
    try {
      return Version.parse(normalized);
    } on FormatException {
      throw FormatException('无法识别版本号：$value');
    }
  }

  bool isNewerThan(String installedVersion) =>
      version > parseVersion(installedVersion);

  /// 镜像地址优先，失败后按顺序尝试备用地址。
  List<Uri> get downloadUrls => <Uri>{apkUrl, ...fallbackUrls}.toList();
}
