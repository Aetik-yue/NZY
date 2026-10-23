import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:love_space/features/update/data/update_repository.dart';

void main() {
  const sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
  const apkName = 'YiYueZhiMing-v1.4.0.apk';

  http.Response jsonResponse(Object value) {
    return http.Response.bytes(
      utf8.encode(jsonEncode(value)),
      200,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }

  Map<String, dynamic> releaseJson({
    bool withDigest = true,
    bool withChecksumAsset = false,
  }) {
    return {
      'tag_name': 'v1.4.0',
      'name': '以越之名 v1.4.0',
      'body': '应用内自动更新',
      'html_url': 'https://github.com/Aetik-yue/NZY/releases/tag/v1.4.0',
      'published_at': '2026-10-22T08:00:00Z',
      'draft': false,
      'prerelease': false,
      'assets': [
        {
          'name': apkName,
          'browser_download_url':
              'https://github.com/Aetik-yue/NZY/releases/download/v1.4.0/$apkName',
          'size': 12345,
          if (withDigest) 'digest': 'sha256:$sha',
        },
        if (withChecksumAsset)
          {
            'name': '$apkName.sha256',
            'browser_download_url':
                'https://github.com/Aetik-yue/NZY/releases/download/v1.4.0/$apkName.sha256',
            'size': 96,
          },
      ],
    };
  }

  test('从 GitHub Release 读取版本、APK 与 SHA-256', () async {
    final repository = GitHubReleaseRepository(
      httpClient: MockClient((request) async {
        expect(request.url.host, 'api.github.com');
        expect(request.url.path, '/repos/Aetik-yue/NZY/releases/latest');
        expect(request.headers['Accept'], 'application/vnd.github+json');
        return jsonResponse(releaseJson());
      }),
    );

    final release = await repository.fetchLatestRelease();

    expect(release.versionName, '1.4.0');
    expect(release.tagName, 'v1.4.0');
    expect(release.apkName, apkName);
    expect(release.apkSize, 12345);
    expect(release.sha256, sha);
    expect(release.notes, '应用内自动更新');
    expect(release.apkUrl.path, endsWith(apkName));
    expect(release.pageUrl?.path, '/Aetik-yue/NZY/releases/tag/v1.4.0');
  });

  test('GitHub 未提供 digest 时读取同名 .sha256 资源', () async {
    final repository = GitHubReleaseRepository(
      httpClient: MockClient((request) async {
        if (request.url.host == 'api.github.com') {
          return jsonResponse(releaseJson(
            withDigest: false,
            withChecksumAsset: true,
          ));
        }
        if (request.url.path.endsWith('.sha256')) {
          return http.Response('$sha  $apkName\n', 200);
        }
        return http.Response('not found', 404);
      }),
    );

    final release = await repository.fetchLatestRelease();

    expect(release.sha256, sha);
  });

  test('缺少校验文件时拒绝更新', () async {
    final repository = GitHubReleaseRepository(
      httpClient: MockClient(
        (_) async => jsonResponse(releaseJson(withDigest: false)),
      ),
    );

    await expectLater(
      repository.fetchLatestRelease(),
      throwsA(
        isA<UpdateCheckException>().having(
          (error) => error.message,
          'message',
          contains('SHA-256'),
        ),
      ),
    );
  });

  test('镜像优先，下载失败时保留 GitHub 备用地址', () async {
    final repository = GitHubReleaseRepository(
      updateBaseUrl: 'https://mirror.test/app/',
      httpClient: MockClient((request) async {
        if (request.url.host == 'mirror.test') {
          return jsonResponse({
            'tagName': 'v1.4.0',
            'apkName': apkName,
            'apkSize': 12345,
            'sha256': sha,
            'notes': '镜像更新说明',
          });
        }
        return http.Response('unexpected', 500);
      }),
    );

    final release = await repository.fetchLatestRelease();

    expect(
        release.apkUrl.toString(), 'https://mirror.test/app/v1.4.0/$apkName');
    expect(release.fallbackUrls.single.toString(),
        'https://github.com/Aetik-yue/NZY/releases/download/v1.4.0/$apkName');
    expect(release.notes, '镜像更新说明');
  });

  test('镜像不可用时回退 GitHub', () async {
    var mirrorCalled = false;
    final repository = GitHubReleaseRepository(
      updateBaseUrl: 'https://mirror.test/app/',
      httpClient: MockClient((request) async {
        if (request.url.host == 'mirror.test') {
          mirrorCalled = true;
          return http.Response('offline', 503);
        }
        return jsonResponse(releaseJson());
      }),
    );

    final release = await repository.fetchLatestRelease();

    expect(mirrorCalled, isTrue);
    expect(release.apkUrl.host, 'github.com');
  });

  test('GitHub 404 提示尚无正式版本', () async {
    final repository = GitHubReleaseRepository(
      httpClient: MockClient((_) async => http.Response('not found', 404)),
    );

    await expectLater(
      repository.fetchLatestRelease(),
      throwsA(
        isA<UpdateCheckException>().having(
          (error) => error.message,
          'message',
          contains('没有可用'),
        ),
      ),
    );
  });
}
