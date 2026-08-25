import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/sync/scf_sync_client.dart';
import '../../core/sync/sync_client.dart';
import '../database/isar_provider.dart';
import 'photo_sync_service.dart';
import 'sync_engine.dart';

/// 云同步客户端（生产实现为腾讯云 SCF + COS；测试可 override 为 FakeCloudSyncClient）
final cloudSyncClientProvider = Provider<CloudSyncClient>((ref) {
  final client = ScfSyncClient();
  ref.onDispose(client.dispose);
  return client;
});

/// 双人同步引擎（应用生命周期内单例）
final syncEngineProvider = Provider<SyncEngine>((ref) {
  final engine = SyncEngine(
    isar: ref.watch(isarProvider),
    client: ref.watch(cloudSyncClientProvider),
  );
  ref.onDispose(engine.dispose);
  return engine;
});

/// 相册照片文件同步服务（依赖引擎，打开相册页时触发）
final photoSyncServiceProvider = Provider<PhotoSyncService>((ref) {
  return PhotoSyncService(
    isar: ref.watch(isarProvider),
    client: ref.watch(cloudSyncClientProvider),
    engine: ref.watch(syncEngineProvider),
  );
});

/// 配对状态（可监听：是否配对 / 房间码 / 最后同步时间 / 是否同步中）
final syncStatusProvider = StreamProvider<SyncStatus>((ref) {
  final engine = ref.watch(syncEngineProvider);
  return Stream.periodic(const Duration(seconds: 1), (_) {
    return SyncStatus(
      isConfigured: engine.isConfigured,
      isPaired: engine.isPaired,
      requiresSecureRepair: engine.requiresSecureRepair,
      roomCode: engine.roomCode,
      lastSyncAt: engine.lastSyncAt,
      isSyncing: engine.isSyncing,
      uid: engine.uid,
    );
  }).distinct();
});

/// 同步状态快照（不可变数据类，驱动 UI）
class SyncStatus {
  final bool isConfigured;
  final bool isPaired;
  final bool requiresSecureRepair;
  final String? roomCode;
  final DateTime? lastSyncAt;
  final bool isSyncing;
  final String? uid;

  const SyncStatus({
    required this.isConfigured,
    required this.isPaired,
    this.requiresSecureRepair = false,
    this.roomCode,
    this.lastSyncAt,
    required this.isSyncing,
    this.uid,
  });

  SyncStatus copyWith({
    bool? isConfigured,
    bool? isPaired,
    bool? requiresSecureRepair,
    String? roomCode,
    DateTime? lastSyncAt,
    bool? isSyncing,
    String? uid,
  }) =>
      SyncStatus(
        isConfigured: isConfigured ?? this.isConfigured,
        isPaired: isPaired ?? this.isPaired,
        requiresSecureRepair: requiresSecureRepair ?? this.requiresSecureRepair,
        roomCode: roomCode ?? this.roomCode,
        lastSyncAt: lastSyncAt ?? this.lastSyncAt,
        isSyncing: isSyncing ?? this.isSyncing,
        uid: uid ?? this.uid,
      );

  @override
  bool operator ==(Object other) =>
      other is SyncStatus &&
      other.isConfigured == isConfigured &&
      other.isPaired == isPaired &&
      other.requiresSecureRepair == requiresSecureRepair &&
      other.roomCode == roomCode &&
      other.lastSyncAt == lastSyncAt &&
      other.isSyncing == isSyncing &&
      other.uid == uid;

  @override
  int get hashCode => Object.hash(
        isConfigured,
        isPaired,
        requiresSecureRepair,
        roomCode,
        lastSyncAt,
        isSyncing,
        uid,
      );
}
