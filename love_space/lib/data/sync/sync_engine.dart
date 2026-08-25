import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/sync/sync_client.dart';
import '../../core/sync/sync_config.dart';
import '../../core/sync/sync_models.dart';
import '../models/album_photo.dart';
import '../models/anniversary.dart';
import '../models/check_in.dart';
import '../models/memo.dart';
import '../models/secret_message.dart';
import '../models/timeline_event.dart';
import '../models/wish.dart';
import 'sync_mapper.dart';

/// 双人同步引擎
///
/// 职责：
/// 1. 房间配对（创建/加入/解绑），房间码即 roomId
/// 2. 定期轮询：云端全量对账（LWW 合并）→ 本机改动上传（cloudId 回填）
/// 3. 对账规则：
///    - 云端有、本地无 → 新增到本地
///    - 两边都有 → 比较 updatedAt，新者胜（LWW），覆盖本地
///    - 云端删除墓碑 → 删除本地对应记录，避免离线副本复活
/// 4. 未配置云环境（SCF + COS）或未配对时静默降级，App 保持纯本地可用
class SyncEngine {
  SyncEngine({required Isar isar, required CloudSyncClient client})
      : _isar = isar,
        _client = client;

  final Isar _isar;
  final CloudSyncClient _client;

  static const _kUidKey = 'sync_uid';
  static const _kRoomKey = 'sync_room';
  static const _kRoomTokenKey = 'sync_room_token';
  static const _kPendingDeleteKey = 'sync_pending_deletes';

  String? _roomId;
  String? _roomToken;
  String? _uid;
  bool _requiresSecureRepair = false;
  Timer? _timer;
  DateTime? _lastSyncAt;
  bool _syncing = false;

  /// 待删除云端文档 ID 队列（本机已物理删除，需在下次同步时删除云端，防复活）
  final Set<String> _pendingDeletes = {};
  Future<void> _pendingDeleteWrite = Future.value();

  /// 记录一条云端文档待删除（UI 物理删除本地前调用）
  void markDeleted(String cloudId) {
    _pendingDeletes.add(cloudId);
    unawaited(_savePendingDeletes());
  }

  /// 撤销尚未完成的删除；若墓碑已经上传，较新的本地时间戳会在下次同步恢复文档。
  void restoreDeleted(String cloudId) {
    _pendingDeletes.remove(cloudId);
    unawaited(_savePendingDeletes());
  }

  /// 最近一次同步时间（UI 展示）
  DateTime? get lastSyncAt => _lastSyncAt;

  /// 是否已配对
  bool get isPaired => _roomId != null && _roomToken != null;

  /// 旧版配对只有全局密钥，没有房间独立令牌，必须重新配对后才能恢复同步。
  bool get requiresSecureRepair => _requiresSecureRepair;

  /// 当前房间码
  String? get roomCode => _roomId;

  /// 当前用户 ID
  String? get uid => _uid;

  /// 是否已配置云环境
  bool get isConfigured => _client.isConfigured;

  /// 是否正在同步
  bool get isSyncing => _syncing;

  /// 恢复持久化状态并恢复轮询（应用启动时调用）
  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _uid = prefs.getString(_kUidKey);
    _roomId = prefs.getString(_kRoomKey);
    _roomToken = prefs.getString(_kRoomTokenKey);
    _requiresSecureRepair = _roomId != null &&
        _roomId!.isNotEmpty &&
        (_roomToken == null || _roomToken!.isEmpty);
    if (_roomToken != null && _roomToken!.isNotEmpty) {
      _client.useRoomToken(_roomToken);
    }
    final pending = prefs.getStringList(_kPendingDeleteKey);
    if (pending != null) {
      _pendingDeletes
        ..clear()
        ..addAll(pending);
    }
    if (isPaired && isConfigured) {
      await _connect();
    }
  }

  Future<void> _connect() async {
    await _client.init();
    _uid = _client.uid;
    await _saveState();
    start();
    await syncOnce();
  }

  /// 创建房间：生成 6 位情侣码并建立云端房间
  Future<String> createRoom() async {
    await _client.init();
    _uid = _client.uid;
    String? code;
    String? roomToken;
    // 服务端原子拒绝同码覆盖；极低概率碰撞时只对 409 自动换码重试。
    for (var attempt = 0; attempt < 10; attempt++) {
      final candidate = _generateCode();
      try {
        roomToken = await _client.createRoom(candidate);
        code = candidate;
        break;
      } on SyncServiceException catch (e) {
        if (e.statusCode != 409) rethrow;
      }
    }
    if (code == null || roomToken == null) {
      throw Exception('生成情侣码失败，请重试');
    }
    await _prepareSecureRepairIfNeeded();
    _roomId = code;
    _roomToken = roomToken;
    _client.useRoomToken(roomToken);
    _requiresSecureRepair = false;
    await _saveState();
    start();
    await syncOnce();
    return code;
  }

  /// 加入房间：输入情侣码绑定
  Future<void> joinRoom(String code) async {
    final normalized = code.trim().toUpperCase();
    if (normalized.length != SyncConfig.roomCodeLength) {
      throw Exception('请输入 ${SyncConfig.roomCodeLength} 位情侣码');
    }
    await _client.init();
    _uid = _client.uid;
    final roomToken = await _client.joinRoom(normalized, _uid!);
    await _prepareSecureRepairIfNeeded();
    _roomId = normalized;
    _roomToken = roomToken;
    _client.useRoomToken(roomToken);
    _requiresSecureRepair = false;
    await _saveState();
    start();
    await syncOnce();
  }

  /// 解绑：停止同步并清除本机同步元数据（云端数据保留，对方仍可见）
  Future<void> leaveRoom() async {
    stop();
    await _clearLocalSyncMeta();
    _roomId = null;
    _roomToken = null;
    _client.useRoomToken(null);
    _requiresSecureRepair = false;
    _pendingDeletes.clear();
    await _saveState();
  }

  /// 启动轮询
  void start() {
    if (_timer != null || !isPaired) return;
    _timer = Timer.periodic(SyncConfig.syncInterval, (_) => syncOnce());
  }

  /// 停止轮询
  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  /// 释放资源（应用退出时调用）
  void dispose() {
    stop();
  }

  /// 手动触发一次同步（删除墓碑 + 拉取对账 + 上传）
  Future<void> syncOnce() async {
    if (_syncing) return;
    if (!isPaired || !isConfigured) return;
    _syncing = true;
    final syncStartedAt = DateTime.now();
    try {
      // 删除先落云端墓碑，再先拉后推：避免应用重启后把离线期间对方更新的
      // 新版本，用本机旧副本覆盖掉。
      await _flushPendingDeletes();
      await _pullAndReconcile();
      await _pushLocal();
      // 使用开始时间作为水位，确保同步过程中发生的本地编辑下轮仍会上传。
      _lastSyncAt = syncStartedAt;
    } catch (e) {
      debugPrint('[SyncEngine] 同步失败: $e');
    } finally {
      _syncing = false;
    }
  }

  /// 安全协议升级时，旧云端房间被封存。清除本机旧 cloudId 后，现有本地数据
  /// 会作为新文档上传到新房间，不会携带旧房间的删除队列或对象关联。
  Future<void> _prepareSecureRepairIfNeeded() async {
    if (!_requiresSecureRepair) return;
    await _clearLocalSyncMeta();
    _pendingDeletes.clear();
    await _savePendingDeletes();
  }

  // ──────── 上传（本机改动 → 云端） ────────

  Future<void> _flushPendingDeletes() async {
    if (_pendingDeletes.isNotEmpty) {
      final failed = <String>{};
      for (final cloudId in _pendingDeletes) {
        try {
          await _client.deleteDoc(cloudId, roomId: _roomId);
        } catch (e) {
          debugPrint('[SyncEngine] 删除云端文档失败: $cloudId $e');
          failed.add(cloudId);
        }
      }
      _pendingDeletes
        ..clear()
        ..addAll(failed);
      await _savePendingDeletes();
    }
  }

  Future<void> _pushLocal() async {
    await _pushType(SyncDataType.wish,
        () async => (await _isar.wishs.where().findAll()).cast<Object>());
    await _pushType(SyncDataType.memo,
        () async => (await _isar.memos.where().findAll()).cast<Object>());
    await _pushType(
        SyncDataType.timeline,
        () async =>
            (await _isar.timelineEvents.where().findAll()).cast<Object>());
    await _pushType(SyncDataType.checkin,
        () async => (await _isar.checkIns.where().findAll()).cast<Object>());
    await _pushType(
        SyncDataType.anniversary,
        () async =>
            (await _isar.anniversarys.where().findAll()).cast<Object>());
    await _pushType(
        SyncDataType.message,
        () async =>
            (await _isar.secretMessages.where().findAll()).cast<Object>());
    await _pushType(SyncDataType.photo,
        () async => (await _isar.albumPhotos.where().findAll()).cast<Object>());
  }

  Future<void> _pushType(
    SyncDataType type,
    Future<List<Object>> Function() load,
  ) async {
    final items = await load();
    for (final item in items) {
      final cloudId = SyncMapper.cloudIdOf(item);
      final updatedAt = SyncMapper.updatedAtOf(item);
      // 新增（无 cloudId）或本同步周期内有本地改动时才上传，
      // 避免用旧时间覆盖对方的更新（LWW 保序）
      final isNew = cloudId == null;
      final changedLocally = updatedAt != null &&
          (_lastSyncAt == null || updatedAt.isAfter(_lastSyncAt!));
      if (!isNew && !changedLocally) continue;

      final docUpdatedAt = updatedAt ?? DateTime.now();
      final doc = PairDoc(
        cloudId: cloudId,
        type: type,
        roomId: _roomId!,
        ownerId: SyncMapper.ownerIdOf(item) ?? _uid!,
        data: SyncMapper.toMap(item),
        updatedAt: docUpdatedAt,
      );
      final newCloudId = await _client.pushDoc(doc);
      if (isNew) {
        // 回填云端 ID 与归属
        SyncMapper.applySyncMeta(
          item,
          cloudId: newCloudId,
          ownerId: _uid!,
          updatedAt: docUpdatedAt,
        );
        await _putBack(type, item);
      }
    }
  }

  // ──────── 拉取 + 对账（云端 → 本地） ────────

  Future<void> _pullAndReconcile() async {
    final docs = await _client.pullAll(_roomId!);
    final byType = <SyncDataType, List<PairDoc>>{};
    for (final d in docs) {
      byType.putIfAbsent(d.type, () => []).add(d);
    }
    await _reconcileType(
        SyncDataType.wish, byType[SyncDataType.wish] ?? const []);
    await _reconcileType(
        SyncDataType.memo, byType[SyncDataType.memo] ?? const []);
    await _reconcileType(
        SyncDataType.timeline, byType[SyncDataType.timeline] ?? const []);
    await _reconcileType(
        SyncDataType.checkin, byType[SyncDataType.checkin] ?? const []);
    await _reconcileType(
        SyncDataType.anniversary, byType[SyncDataType.anniversary] ?? const []);
    await _reconcileType(
        SyncDataType.message, byType[SyncDataType.message] ?? const []);
    await _reconcileType(
        SyncDataType.photo, byType[SyncDataType.photo] ?? const []);
  }

  Future<void> _reconcileType(
    SyncDataType type,
    List<PairDoc> cloudDocs,
  ) async {
    final localItems = await _loadLocal(type);
    final localByCloudId = <String, Object>{
      for (final item in localItems)
        if (SyncMapper.cloudIdOf(item) != null)
          SyncMapper.cloudIdOf(item)!: item,
    };

    final unlinkedLocal =
        localItems.where((item) => SyncMapper.cloudIdOf(item) == null).toList();

    // 云端有 → 删除墓碑、新增、种子数据匹配或 LWW 合并。
    for (final doc in cloudDocs) {
      final cloudId = doc.cloudId;
      if (cloudId == null || cloudId.isEmpty) continue;
      final local = localByCloudId[doc.cloudId];
      if (doc.deleted) {
        final localUpdatedAt =
            local == null ? null : SyncMapper.updatedAtOf(local);
        final restoredLocally =
            localUpdatedAt != null && localUpdatedAt.isAfter(doc.updatedAt);
        if (local != null && !restoredLocally) {
          await _deleteLocal(type, local);
        }
        continue;
      }
      if (local == null) {
        Object? matched;
        for (final candidate in unlinkedLocal) {
          if (SyncMapper.hasSameIdentity(candidate, doc.data)) {
            matched = candidate;
            break;
          }
        }
        if (matched != null) unlinkedLocal.remove(matched);

        final model = SyncMapper.fromMap(
          type,
          doc.data,
          id: matched == null ? null : _localId(matched),
        );
        if (matched != null) {
          SyncMapper.copyLocalOnlyFields(matched, model);
        }
        SyncMapper.applySyncMeta(
          model,
          cloudId: doc.cloudId,
          updatedAt: doc.updatedAt,
          ownerId: doc.ownerId,
        );
        await _putBack(type, model);
      } else {
        final localUpdatedAt = SyncMapper.updatedAtOf(local);
        final cloudIsNewer =
            localUpdatedAt == null || doc.updatedAt.isAfter(localUpdatedAt);
        if (cloudIsNewer) {
          // 仅云端严格更新时覆盖。时间相等时保留 read/filePath 等本机字段。
          final model = SyncMapper.fromMap(type, doc.data, id: _localId(local));
          SyncMapper.copyLocalOnlyFields(local, model);
          SyncMapper.applySyncMeta(
            model,
            cloudId: doc.cloudId,
            updatedAt: doc.updatedAt,
            ownerId: doc.ownerId,
          );
          await _putBack(type, model);
        }
      }
    }
  }

  // ──────── Isar 集合读写（按类型分发） ────────

  Future<List<Object>> _loadLocal(SyncDataType type) async {
    switch (type) {
      case SyncDataType.wish:
        return (await _isar.wishs.where().findAll()).cast<Object>();
      case SyncDataType.memo:
        return (await _isar.memos.where().findAll()).cast<Object>();
      case SyncDataType.timeline:
        return (await _isar.timelineEvents.where().findAll()).cast<Object>();
      case SyncDataType.checkin:
        return (await _isar.checkIns.where().findAll()).cast<Object>();
      case SyncDataType.anniversary:
        return (await _isar.anniversarys.where().findAll()).cast<Object>();
      case SyncDataType.message:
        return (await _isar.secretMessages.where().findAll()).cast<Object>();
      case SyncDataType.photo:
        return (await _isar.albumPhotos.where().findAll()).cast<Object>();
    }
  }

  Future<void> _putBack(SyncDataType type, Object model) async {
    switch (type) {
      case SyncDataType.wish:
        await _isar.writeTxn(() async => _isar.wishs.put(model as Wish));
      case SyncDataType.memo:
        await _isar.writeTxn(() async => _isar.memos.put(model as Memo));
      case SyncDataType.timeline:
        await _isar.writeTxn(
            () async => _isar.timelineEvents.put(model as TimelineEvent));
      case SyncDataType.checkin:
        await _isar.writeTxn(() async => _isar.checkIns.put(model as CheckIn));
      case SyncDataType.anniversary:
        await _isar
            .writeTxn(() async => _isar.anniversarys.put(model as Anniversary));
      case SyncDataType.message:
        await _isar.writeTxn(
            () async => _isar.secretMessages.put(model as SecretMessage));
      case SyncDataType.photo:
        await _isar
            .writeTxn(() async => _isar.albumPhotos.put(model as AlbumPhoto));
    }
  }

  Future<void> _deleteLocal(SyncDataType type, Object model) async {
    final id = _localId(model);
    switch (type) {
      case SyncDataType.wish:
        await _isar.writeTxn(() async => _isar.wishs.delete(id));
      case SyncDataType.memo:
        await _isar.writeTxn(() async => _isar.memos.delete(id));
      case SyncDataType.timeline:
        await _isar.writeTxn(() async => _isar.timelineEvents.delete(id));
      case SyncDataType.checkin:
        await _isar.writeTxn(() async => _isar.checkIns.delete(id));
      case SyncDataType.anniversary:
        await _isar.writeTxn(() async => _isar.anniversarys.delete(id));
      case SyncDataType.message:
        await _isar.writeTxn(() async => _isar.secretMessages.delete(id));
      case SyncDataType.photo:
        await _isar.writeTxn(() async => _isar.albumPhotos.delete(id));
    }
  }

  int _localId(Object model) => switch (model) {
        Wish(:final id) => id,
        Memo(:final id) => id,
        TimelineEvent(:final id) => id,
        CheckIn(:final id) => id,
        Anniversary(:final id) => id,
        SecretMessage(:final id) => id,
        AlbumPhoto(:final id) => id,
        _ => 0,
      };

  // ──────── 状态持久化 ────────

  Future<void> _saveState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kUidKey, _uid ?? '');
    if (_roomId != null) {
      await prefs.setString(_kRoomKey, _roomId!);
    } else {
      await prefs.remove(_kRoomKey);
    }
    if (_roomToken != null && _roomToken!.isNotEmpty) {
      await prefs.setString(_kRoomTokenKey, _roomToken!);
    } else {
      await prefs.remove(_kRoomTokenKey);
    }
    await _savePendingDeletes();
  }

  Future<void> _savePendingDeletes() async {
    final snapshot = List<String>.from(_pendingDeletes);
    _pendingDeleteWrite = _pendingDeleteWrite
        .catchError((Object e) => debugPrint('[SyncEngine] 保存删除队列失败: $e'))
        .then((_) async {
      final prefs = await SharedPreferences.getInstance();
      if (snapshot.isEmpty) {
        await prefs.remove(_kPendingDeleteKey);
      } else {
        await prefs.setStringList(_kPendingDeleteKey, snapshot);
      }
    });
    await _pendingDeleteWrite;
  }

  /// 解绑时清除本机数据的云端关联（cloudId/ownerId），数据回到纯本地
  Future<void> _clearLocalSyncMeta() async {
    await _clearTypeMeta(SyncDataType.wish,
        () async => (await _isar.wishs.where().findAll()).cast<Object>());
    await _clearTypeMeta(SyncDataType.memo,
        () async => (await _isar.memos.where().findAll()).cast<Object>());
    await _clearTypeMeta(
        SyncDataType.timeline,
        () async =>
            (await _isar.timelineEvents.where().findAll()).cast<Object>());
    await _clearTypeMeta(SyncDataType.checkin,
        () async => (await _isar.checkIns.where().findAll()).cast<Object>());
    await _clearTypeMeta(
        SyncDataType.anniversary,
        () async =>
            (await _isar.anniversarys.where().findAll()).cast<Object>());
    await _clearTypeMeta(
        SyncDataType.message,
        () async =>
            (await _isar.secretMessages.where().findAll()).cast<Object>());
    await _clearTypeMeta(SyncDataType.photo,
        () async => (await _isar.albumPhotos.where().findAll()).cast<Object>());
  }

  Future<void> _clearTypeMeta(
    SyncDataType type,
    Future<List<Object>> Function() load,
  ) async {
    final items = await load();
    for (final item in items) {
      final hasCloud = SyncMapper.cloudIdOf(item) != null;
      final hasOwner = SyncMapper.ownerIdOf(item) != null;
      if (hasCloud || hasOwner) {
        SyncMapper.clearSyncMeta(item);
        await _putBack(type, item);
      }
    }
  }

  /// 生成 6 位情侣码（大写字母 + 数字，去易混淆字符）
  static String _generateCode() {
    const chars = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
    final random = Random.secure();
    final buf = StringBuffer();
    for (var i = 0; i < SyncConfig.roomCodeLength; i++) {
      buf.write(chars[random.nextInt(chars.length)]);
    }
    return buf.toString();
  }
}
