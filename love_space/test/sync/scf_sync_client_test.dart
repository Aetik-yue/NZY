import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:love_space/core/sync/scf_sync_client.dart';
import 'package:love_space/core/sync/sync_client.dart';
import 'package:love_space/core/sync/sync_models.dart';

void main() {
  const testSecret = 'test-secret-with-at-least-32-bytes';

  setUp(() {
    SharedPreferences.setMockInitialValues({'sync_uid': 'test-user'});
  });

  ScfSyncClient clientWith(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    return ScfSyncClient(
      httpClient: MockClient(handler),
      apiBaseUrl: 'https://sync.test',
      syncSecret: testSecret,
    );
  }

  test('创建房间接收独立令牌，配对接口不发送旧房间令牌', () async {
    final client = clientWith((request) async {
      expect(request.headers['X-Sync-Secret'], testSecret);
      expect(request.headers['X-Room-Token'], isNull);
      return http.Response(jsonEncode({'roomToken': 'a' * 43}), 201);
    });
    await client.init();
    client.useRoomToken('old-token');

    expect(await client.createRoom('ABC234'), 'a' * 43);
  });

  test('加入房间接收独立令牌，并规范 URL 尾斜杠', () async {
    final client = ScfSyncClient(
      apiBaseUrl: 'https://sync.example.test/',
      syncSecret: testSecret,
      httpClient: MockClient((request) async {
        expect(
          request.url.toString(),
          'https://sync.example.test/rooms/ABC234',
        );
        expect(request.headers['X-Room-Token'], isNull);
        return http.Response(jsonEncode({'roomToken': 'b' * 43}), 200);
      }),
    );
    await client.init();

    expect(await client.joinRoom('ABC234', 'test-user'), 'b' * 43);
  });

  test('创建房间会保留非 2xx 状态码，供碰撞重试判断', () async {
    final client = clientWith(
      (_) async =>
          http.Response(jsonEncode({'error': 'room already exists'}), 409),
    );
    await client.init();

    await expectLater(
      client.createRoom('ABC234'),
      throwsA(
        isA<SyncServiceException>()
            .having((e) => e.statusCode, 'statusCode', 409),
      ),
    );
  });

  test('房间数据请求携带独立令牌并保留原 cloudId', () async {
    final client = clientWith((request) async {
      expect(request.method, 'PUT');
      expect(request.url.path, '/pairdata/cloud-1');
      expect(request.headers['X-Room-Token'], 'c' * 43);
      return http.Response(jsonEncode({'ok': true}), 200);
    });
    await client.init();
    client.useRoomToken('c' * 43);

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

  test('照片请求携带独立令牌，下载时向后端刷新签名 URL', () async {
    const name = 'ABC234-cloud-1.jpg';
    var signedUrlRequested = false;
    final client = clientWith((request) async {
      if (request.method == 'POST') {
        expect(request.headers['X-Room-Token'], 'd' * 43);
        return http.Response(jsonEncode({'name': name}), 200);
      }
      if (request.url.host == 'sync.test') {
        signedUrlRequested = true;
        expect(request.headers['X-Room-Token'], 'd' * 43);
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
    client.useRoomToken('d' * 43);

    final cloudPath = await client.uploadPhoto(name, <int>[1, 2, 3]);
    expect(cloudPath, name);
    expect(await client.downloadPhoto(cloudPath), <int>[1, 2, 3]);
    expect(signedUrlRequested, isTrue);
  });
}
