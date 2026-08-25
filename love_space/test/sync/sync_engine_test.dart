// SyncEngine 单元测试（Fake 客户端 + 内存 Isar）
//
// Isar 原生库在 flutter test 环境（如 Windows 未注册 Flutter 插件）不可用时跳过；
// 在配置正确的 CI/桌面构建中真实执行。
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:love_space/core/sync/sync_client.dart';
import 'package:love_space/core/sync/sync_models.dart';
import 'package:love_space/data/models/album_photo.dart';
import 'package:love_space/data/models/anniversary.dart';
import 'package:love_space/data/models/check_in.dart';
import 'package:love_space/data/models/memo.dart';
import 'package:love_space/data/models/secret_message.dart';
import 'package:love_space/data/models/timeline_event.dart';
import 'package:love_space/data/models/wish.dart';
import 'package:love_space/data/sync/sync_engine.dart';

Future<Isar> _openIsar(String directory) {
  return Isar.open(
    [
      WishSchema,
      MemoSchema,
      TimelineEventSchema,
      CheckInSchema,
      AnniversarySchema,
      SecretMessageSchema,
      AlbumPhotoSchema,
    ],
    directory: directory,
    name: 'sync_engine_test',
  );
}

void main() {
  late Isar isar;
  late Directory testDirectory;
  var isarOpened = false;

  setUpAll(() async {
    await Isar.initializeIsarCore(download: true);
    testDirectory = await Directory.systemTemp.createTemp('love_space_sync_');
  });

  setUp(() async {
    isarOpened = false;
    try {
      isar = await _openIsar(testDirectory.path);
      isarOpened = true;
      SharedPreferences.setMockInitialValues({});
    } catch (_) {
      isarOpened = false;
    }
  });

  tearDown(() async {
    if (isarOpened) await isar.close(deleteFromDisk: true);
  });

  tearDownAll(() async {
    if (await testDirectory.exists()) {
      await testDirectory.delete(recursive: true);
    }
  });

  test('创建房间后本机数据上传并回填 cloudId', () async {
    if (!isarOpened) {
      markTestSkipped('Isar 原生库不可用，跳过同步引擎测试');
      return;
    }
    final client = FakeCloudSyncClient();
    final engine = SyncEngine(isar: isar, client: client);

    // 本地先有数据
    await isar.writeTxn(() async {
      await isar.wishs.put(Wish()
        ..title = '一起看海'
        ..description = ''
        ..iconCodePoint = 0xe90b
        ..done = false
        ..createdAt = DateTime.now());
      await isar.memos.put(Memo()
        ..content = '今晚一起吃饭 #计划'
        ..author = 1
        ..isPinned = false
        ..colorValue = 0xFFFF8FB1
        ..createdAt = DateTime.now());
    });

    final code = await engine.createRoom();
    expect(code.length, 6);
    expect(engine.isPaired, isTrue);
    expect(engine.roomCode, code);

    // 云端已有数据
    expect(client.docs.length, 2);
    // 本地 cloudId 已回填
    final wish = await isar.wishs.where().findFirst();
    expect(wish, isNotNull);
    expect(wish!.cloudId, isNotNull);
    expect(wish.ownerId, 'test-user');
  });

  test('加入房间后云端数据合并进本地（LWW 新者胜）', () async {
    if (!isarOpened) {
      markTestSkipped('Isar 原生库不可用，跳过同步引擎测试');
      return;
    }
    final client = FakeCloudSyncClient();
    client.rooms['ABC123'] = {
      'code': 'ABC123',
      'members': <String>['partner'],
    };
    // 预置云端数据（对方创建，更新时间较新）
    final remoteTime = DateTime.now();
    client.docs.add(PairDoc(
      cloudId: 'cloud-a',
      type: SyncDataType.wish,
      roomId: 'ABC123',
      ownerId: 'partner',
      data: {
        'title': '一起去迪士尼',
        'description': '提前订票',
        'iconCodePoint': 0xe90b,
        'done': false,
        'createdAt': remoteTime,
      },
      updatedAt: remoteTime,
    ));

    final engine = SyncEngine(isar: isar, client: client);
    await engine.joinRoom('ABC123');

    final wishes = await isar.wishs.where().findAll();
    expect(wishes, hasLength(1));
    expect(wishes.first.title, '一起去迪士尼');
    expect(wishes.first.cloudId, 'cloud-a');
    expect(wishes.first.ownerId, 'partner');
  });

  test('对方删除数据后本地同步删除', () async {
    if (!isarOpened) {
      markTestSkipped('Isar 原生库不可用，跳过同步引擎测试');
      return;
    }
    final client = FakeCloudSyncClient();
    final engine = SyncEngine(isar: isar, client: client);

    // 本地已有对方数据（cloudId 非空、ownerId 非本机）
    await isar.writeTxn(() async {
      await isar.wishs.put(Wish()
        ..title = '待删除'
        ..description = ''
        ..iconCodePoint = 0
        ..done = false
        ..createdAt = DateTime.now()
        ..cloudId = 'cloud-removed'
        ..ownerId = 'partner'
        ..updatedAt = DateTime.now());
    });

    // 云端删除墓碑（对方已删除）
    client.docs.add(PairDoc(
      cloudId: 'cloud-removed',
      type: SyncDataType.wish,
      roomId: 'ABC234',
      ownerId: 'partner',
      data: const {},
      updatedAt: DateTime.now(),
      deleted: true,
    ));
    client.rooms['ABC234'] = {
      'code': 'ABC234',
      'members': <String>['partner'],
    };
    await engine.joinRoom('ABC234');

    final wishes = await isar.wishs.where().findAll();
    expect(wishes, isEmpty);
  });

  test('本机删除会写入云端墓碑且不会因对账复活', () async {
    if (!isarOpened) {
      markTestSkipped('Isar 原生库不可用，跳过同步引擎测试');
      return;
    }
    final client = FakeCloudSyncClient();
    final engine = SyncEngine(isar: isar, client: client);

    // 本机数据已上传
    await isar.writeTxn(() async {
      await isar.wishs.put(Wish()
        ..title = '本地已删'
        ..description = ''
        ..iconCodePoint = 0
        ..done = false
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now());
    });
    await engine.createRoom();
    // 云端已有（cloudId 回填）
    final wish = await isar.wishs.where().findFirst();
    expect(wish!.cloudId, isNotNull);

    // 本地删除（模拟用户删除后物理移除）
    await isar.writeTxn(() async {
      await isar.wishs.delete(wish.id);
    });
    engine.markDeleted(wish.cloudId!);
    await engine.syncOnce();

    final after = await isar.wishs.where().findAll();
    expect(after, isEmpty);
    expect(client.docs.singleWhere((d) => d.cloudId == wish.cloudId).deleted,
        isTrue);
  });

  test('应用重启后的首次同步先拉后推，不会用旧本地副本覆盖云端新版', () async {
    if (!isarOpened) {
      markTestSkipped('Isar 原生库不可用，跳过同步引擎测试');
      return;
    }
    final client = FakeCloudSyncClient();
    final oldTime = DateTime(2026, 8, 20);
    final newTime = DateTime(2026, 8, 21);
    client.rooms['ABC234'] = {
      'code': 'ABC234',
      'members': <String>['test-user'],
    };
    client.docs.add(PairDoc(
      cloudId: 'cloud-restart',
      type: SyncDataType.wish,
      roomId: 'ABC234',
      ownerId: 'test-user',
      data: {
        'title': '云端新版',
        'description': '',
        'iconCodePoint': 0,
        'done': false,
        'createdAt': oldTime,
      },
      updatedAt: newTime,
    ));
    await isar.writeTxn(() async {
      await isar.wishs.put(Wish()
        ..title = '本地旧版'
        ..description = ''
        ..iconCodePoint = 0
        ..done = false
        ..createdAt = oldTime
        ..cloudId = 'cloud-restart'
        ..ownerId = 'test-user'
        ..updatedAt = oldTime);
    });
    SharedPreferences.setMockInitialValues({
      'sync_room': 'ABC234',
      'sync_room_token': 'token-ABC234-test-user',
      'sync_uid': 'test-user',
    });

    final engine = SyncEngine(isar: isar, client: client);
    await engine.init();

    expect((await isar.wishs.where().findFirst())!.title, '云端新版');
    expect(client.docs.single.data['title'], '云端新版');
  });

  test('旧版无房间令牌的配对会暂停同步并要求安全重配', () async {
    if (!isarOpened) {
      markTestSkipped('Isar 原生库不可用，跳过同步引擎测试');
      return;
    }
    final client = FakeCloudSyncClient();
    SharedPreferences.setMockInitialValues({
      'sync_room': 'ABC234',
      'sync_uid': 'test-user',
    });

    final engine = SyncEngine(isar: isar, client: client);
    await engine.init();

    expect(engine.isPaired, isFalse);
    expect(engine.requiresSecureRepair, isTrue);
    expect(client.isInitialized, isFalse);
  });

  test('加入房间时匹配双方相同种子数据，不重复新增和上传', () async {
    if (!isarOpened) {
      markTestSkipped('Isar 原生库不可用，跳过同步引擎测试');
      return;
    }
    final client = FakeCloudSyncClient();
    final date = DateTime(2026, 5, 20);
    client.rooms['ABC234'] = {
      'code': 'ABC234',
      'members': <String>['partner'],
    };
    client.docs.add(PairDoc(
      cloudId: 'timeline-seed',
      type: SyncDataType.timeline,
      roomId: 'ABC234',
      ownerId: 'partner',
      data: {
        'date': date,
        'title': '第一次旅行',
        'description': '一起看海',
        'dotColorValue': 0xFFFF8FB1,
      },
      updatedAt: date,
    ));
    await isar.writeTxn(() async {
      await isar.timelineEvents.put(TimelineEvent()
        ..date = date
        ..title = '第一次旅行'
        ..description = '一起看海'
        ..dotColorValue = 0xFFFF8FB1);
    });

    await SyncEngine(isar: isar, client: client).joinRoom('ABC234');

    final local = await isar.timelineEvents.where().findAll();
    expect(local, hasLength(1));
    expect(local.single.cloudId, 'timeline-seed');
    expect(client.docs, hasLength(1));
  });

  test('悄悄话消息同步：本地发送上传、对方消息合并', () async {
    if (!isarOpened) {
      markTestSkipped('Isar 原生库不可用，跳过同步引擎测试');
      return;
    }
    final client = FakeCloudSyncClient();
    final engine = SyncEngine(isar: isar, client: client);

    // 本地先发一条
    await isar.writeTxn(() async {
      await isar.secretMessages.put(SecretMessage()
        ..content = '想你了 💕'
        ..createdAt = DateTime.now()
        ..updatedAt = DateTime.now());
    });

    final code = await engine.createRoom();
    expect(
        client.docs.where((d) => d.type == SyncDataType.message), hasLength(1));

    // 对方消息进入云端
    final msgTime = DateTime.now();
    client.docs.add(PairDoc(
      cloudId: 'msg-1',
      type: SyncDataType.message,
      roomId: code,
      ownerId: 'partner',
      data: {'content': '我也想你', 'createdAt': msgTime},
      updatedAt: msgTime,
    ));

    await engine.syncOnce();
    final all = await isar.secretMessages.where().findAll();
    expect(all, hasLength(2));
    expect(all.map((m) => m.content), contains('我也想你'));
    expect(all.firstWhere((m) => m.content == '我也想你').ownerId, 'partner');
  });

  test('照片元数据同步：对方照片元数据合并到本地', () async {
    if (!isarOpened) {
      markTestSkipped('Isar 原生库不可用，跳过同步引擎测试');
      return;
    }
    final client = FakeCloudSyncClient();
    client.rooms['XYZ789'] = {
      'code': 'XYZ789',
      'members': <String>['partner'],
    };

    // 对方照片元数据在云端（含 cloudPath）
    final photoTime = DateTime.now();
    client.docs.add(PairDoc(
      cloudId: 'photo-1',
      type: SyncDataType.photo,
      roomId: 'XYZ789',
      ownerId: 'partner',
      data: {
        'date': DateTime(2026, 5, 20),
        'category': 'travel',
        'gradientIndex': 1,
        'cloudPath': 'photos/XYZ789/photo-1.jpg',
      },
      updatedAt: photoTime,
    ));

    final engine2 = SyncEngine(isar: isar, client: client);
    await engine2.joinRoom('XYZ789');

    final photos = await isar.albumPhotos.where().findAll();
    expect(photos, hasLength(1));
    expect(photos.first.cloudId, 'photo-1');
    expect(photos.first.cloudPath, 'photos/XYZ789/photo-1.jpg');
    expect(photos.first.category, PhotoCategory.travel);
  });
}
