import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:love_space/core/sync/scf_sync_client.dart';
import 'package:love_space/core/sync/sync_models.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'sync_uid': 'test-user'});
  });

  ScfSyncClient clientWith(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    return ScfSyncClient(
      httpClient: MockClient(handler),
      apiBaseUrl: 'https://sync.test',
      syncSecret: 'test-secret',
    );
  }

  test('房间不存在的 null 响应可正常解析', () async {
    final client = clientWith((request) async {
      expect(request.headers['X-Sync-Secret'], 'test-secret');
      return http.Response('null', 200);
    });
    await client.init();

    expect(await client.getRoom('ABC234'), isNull);
  });

  test('房间不存在的包装响应可正常解析，并规范 URL 尾斜杠', () async {
    final client = ScfSyncClient(
      apiBaseUrl: 'https://sync.example.test/',
      syncSecret: 'test-secret',
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://sync.example.test/rooms?code=ABC234',
        );
        return http.Response(jsonEncode({'room': null}), 200);
      }),
    );
    await client.init();

    expect(await client.getRoom('ABC234'), isNull);
  });

  test('创建房间会校验非 2xx 响应，不再静默成功', () async {
    final client = clientWith(
      (_) async =>
          http.Response(jsonEncode({'error': 'room already exists'}), 409),
    );
    await client.init();

    await expectLater(client.createRoom('ABC234'), throwsException);
  });

  test('更新文档会校验响应并保留原 cloudId', () async {
    final client = clientWith((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, '/pairdata/cloud-1');
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    await client.init();

    final cloudId = await client.pushDoc(PairDoc(
      cloudId: 'cloud-1',
      type: SyncDataType.wish,
      roomId: 'ABC234',
      ownerId: 'test-user',
      data: const {'title': '一起看海'},
      updatedAt: DateTime(2026, 8, 23),
    ));

    expect(cloudId, 'cloud-1');
  });

  test('照片保存稳定对象名，下载时向后端刷新签名 URL', () async {
    const name = 'ABC234-cloud-1.jpg';
    var signedUrlRequested = false;
    final client = clientWith((request) async {
      if (request.method == 'POST') {
        return http.Response(jsonEncode({'name': name}), 200);
      }
      if (request.url.host == 'sync.test') {
        signedUrlRequested = true;
        expect(request.url.queryParameters['name'], name);
        return http.Response(
          jsonEncode({'url': 'https://cos.test/photo?signature=fresh'}),
          200,
        );
      }
      expect(request.url.host, 'cos.test');
      return http.Response.bytes(<int>[1, 2, 3], 200);
    });
    await client.init();

    final cloudPath = await client.uploadPhoto(name, <int>[1, 2, 3]);
    expect(cloudPath, name);
    expect(await client.downloadPhoto(cloudPath), <int>[1, 2, 3]);
    expect(signedUrlRequested, isTrue);
  });
}
