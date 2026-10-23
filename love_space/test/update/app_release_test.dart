import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/features/update/domain/app_release.dart';

void main() {
  const sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('版本标签兼容 v 前缀并正确比较新旧版本', () {
    final release = AppRelease(
      version: AppRelease.parseVersion('v1.4.0'),
      tagName: 'v1.4.0',
      releaseName: 'v1.4.0',
      notes: '',
      apkName: 'YiYueZhiMing-v1.4.0.apk',
      apkSize: 1024,
      sha256: sha,
      apkUrl: Uri.parse('https://github.com/download.apk'),
      publishedAt: null,
    );

    expect(release.versionName, '1.4.0');
    expect(release.isNewerThan('1.3.1'), isTrue);
    expect(release.isNewerThan('1.4.0'), isFalse);
    expect(release.isNewerThan('1.3.1+131'), isTrue);
  });

  test('下载地址去重并保留镜像优先顺序', () {
    final release = AppRelease(
      version: AppRelease.parseVersion('1.4.0'),
      tagName: 'v1.4.0',
      releaseName: 'v1.4.0',
      notes: '',
      apkName: 'app.apk',
      apkSize: 1024,
      sha256: sha,
      apkUrl: Uri.parse('https://mirror.test/app.apk'),
      fallbackUrls: [
        Uri.parse('https://github.test/app.apk'),
        Uri.parse('https://mirror.test/app.apk'),
      ],
      publishedAt: null,
    );

    expect(release.downloadUrls, [
      Uri.parse('https://mirror.test/app.apk'),
      Uri.parse('https://github.test/app.apk'),
    ]);
  });

  test('无法识别的版本标签抛出 FormatException', () {
    expect(() => AppRelease.parseVersion('latest'), throwsFormatException);
  });

  test('更新日志展示时移除常用 Markdown 标记', () {
    final release = AppRelease(
      version: AppRelease.parseVersion('1.4.0'),
      tagName: 'v1.4.0',
      releaseName: 'v1.4.0',
      notes: '## 新版本\n\n- **重点** [说明](https://example.com)\n\n`代码`',
      apkName: 'app.apk',
      apkSize: 1024,
      sha256: sha,
      apkUrl: Uri.parse('https://github.test/app.apk'),
      publishedAt: null,
    );

    expect(release.displayNotes, '新版本\n\n• 重点 说明\n\n代码');
  });
}
