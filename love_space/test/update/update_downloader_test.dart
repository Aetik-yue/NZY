import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:love_space/features/update/data/update_downloader.dart';
import 'package:love_space/features/update/domain/app_release.dart';

void main() {
  late Directory tempDir;
  late List<int> bytes;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('love_update_test');
    bytes = List<int>.generate(8192, (index) => index % 251);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  AppRelease releaseWith({
    required String sha256,
    List<Uri> fallbackUrls = const [],
  }) {
    return AppRelease(
      version: AppRelease.parseVersion('1.4.0'),
      tagName: 'v1.4.0',
      releaseName: 'v1.4.0',
      notes: '',
      apkName: 'YiYueZhiMing-v1.4.0.apk',
      apkSize: bytes.length,
      sha256: sha256,
      apkUrl: Uri.parse('https://mirror.test/app.apk'),
      fallbackUrls: fallbackUrls,
      publishedAt: null,
    );
  }

  test('下载完成后按 SHA-256 校验并写入固定文件名', () async {
    final sha = sha256.convert(bytes).toString();
    final downloader = HttpUpdateDownloader(
      clientFactory: () => MockClient(
        (_) async => http.Response.bytes(bytes, 200),
      ),
      directory: () async => tempDir,
    );

    final file = await downloader.download(
      releaseWith(sha256: sha),
      (_) {},
    );

    expect(file.path, endsWith('love_updates/update.apk'));
    expect(await file.readAsBytes(), bytes);
  });

  test('校验失败时不保留已下载文件', () async {
    final downloader = HttpUpdateDownloader(
      clientFactory: () => MockClient(
        (_) async => http.Response.bytes(bytes, 200),
      ),
      directory: () async => tempDir,
    );

    await expectLater(
      downloader.download(releaseWith(sha256: 'b' * 64), (_) {}),
      throwsA(isA<UpdateDownloadException>()),
    );

    final folder = Directory('${tempDir.path}/love_updates');
    expect(await File('${folder.path}/update.apk').exists(), isFalse);
    expect(await File('${folder.path}/update.apk.part').exists(), isFalse);
  });

  test('主下载地址不可用时自动尝试备用地址', () async {
    final sha = sha256.convert(bytes).toString();
    final downloader = HttpUpdateDownloader(
      clientFactory: () => MockClient((request) async {
        if (request.url.host == 'mirror.test') {
          return http.Response('forbidden', 403);
        }
        return http.Response.bytes(bytes, 200);
      }),
      directory: () async => tempDir,
    );

    final file = await downloader.download(
      releaseWith(
        sha256: sha,
        fallbackUrls: [Uri.parse('https://github.test/app.apk')],
      ),
      (_) {},
    );

    expect(await file.readAsBytes(), bytes);
  });

  test('HTTP 错误保留状态码，便于控制器刷新地址', () async {
    final downloader = HttpUpdateDownloader(
      clientFactory: () => MockClient(
        (_) async => http.Response('forbidden', 403),
      ),
      directory: () async => tempDir,
    );

    await expectLater(
      downloader.download(releaseWith(sha256: 'c' * 64), (_) {}),
      throwsA(
        isA<UpdateDownloadHttpException>()
            .having((error) => error.statusCode, 'statusCode', 403),
      ),
    );
  });
}
