import 'sync_models.dart';

/// 同步未配置（未注入 SCF URL/密钥）时抛出
class SyncNotConfiguredException implements Exception {
  const SyncNotConfiguredException();
  @override
  String toString() => '未配置同步服务（SYNC_API_URL / SYNC_SECRET）';
}

/// 同步服务返回的可判定 HTTP 错误。
class SyncServiceException implements Exception {
  const SyncServiceException(this.statusCode, this.message);

  final int statusCode;
  final String message;

  @override
  String toString() => '同步服务错误 $statusCode: $message';
}

/// 云同步客户端抽象
///
/// 封装云端的房间配对与数据读写，供 SyncEngine 调用。
/// 提供 [FakeCloudSyncClient] 用于单元测试；生产实现见
/// [ScfSyncClient]（core/sync/scf_sync_client.dart）。
abstract class CloudSyncClient {
  /// 初始化（登录匿名用户），幂等
  Future<void> init();

  /// 当前登录用户 ID（init 后可用）
  String? get uid;

  /// 是否已配置云环境（未配置则同步功能禁用）
  bool get isConfigured;

  /// 是否已完成初始化
  bool get isInitialized;

  /// 设置当前房间的独立访问令牌；数据与照片接口必须携带。
  void useRoomToken(String? token);

  /// 创建房间，返回仅当前成员持有的房间访问令牌。
  Future<String> createRoom(String code);

  /// 加入房间，返回仅当前成员持有的房间访问令牌。
  Future<String> joinRoom(String code, String memberUid);

  /// 拉取房间内全部数据文档（全量对账用）
  Future<List<PairDoc>> pullAll(String roomId);

  /// 上传文档（cloudId 为 null 走 add，否则 set 覆盖）
  ///
  /// 返回写入后的云端文档 ID。
  Future<String> pushDoc(PairDoc doc);

  /// 删除云端文档
  Future<void> deleteDoc(String cloudId, {String? roomId});

  /// 上传照片文件到云存储，返回文件路径
  Future<String> uploadPhoto(String cloudPath, List<int> bytes);

  /// 从云存储下载照片文件字节
  Future<List<int>> downloadPhoto(String cloudPath);

  /// 删除云存储照片文件
  Future<void> deletePhoto(String cloudPath);

  /// 释放资源（关闭连接等）
  void dispose() {}
}

/// 内存假实现（单元测试用）
class FakeCloudSyncClient implements CloudSyncClient {
  FakeCloudSyncClient();

  final String _uid = 'test-user';

  @override
  String? get uid => _uid;

  @override
  bool isConfigured = true;

  @override
  bool isInitialized = false;

  String? roomToken;

  final Map<String, Map<String, dynamic>> rooms = {};
  final List<PairDoc> docs = [];
  int _docSeq = 0;

  /// 模拟网络错误（测试用）
  bool failNextOperation = false;

  void _maybeThrow() {
    if (failNextOperation) {
      failNextOperation = false;
      throw Exception('模拟网络错误');
    }
  }

  @override
  void dispose() {}

  @override
  Future<void> init() async {
    _maybeThrow();
    isInitialized = true;
  }

  @override
  void useRoomToken(String? token) => roomToken = token;

  @override
  Future<String> createRoom(String code) async {
    _maybeThrow();
    if (rooms.containsKey(code)) {
      throw const SyncServiceException(409, 'room already exists');
    }
    final token = 'token-$code-$_uid';
    rooms[code] = {
      'code': code,
      'members': <String>[_uid],
      'createdAt': DateTime.now(),
    };
    roomToken = token;
    return token;
  }

  @override
  Future<String> joinRoom(String code, String memberUid) async {
    _maybeThrow();
    final room = rooms[code];
    if (room == null) {
      throw const SyncServiceException(404, 'room not found');
    }
    final members = (room['members'] as List).cast<String>();
    if (!members.contains(memberUid)) {
      if (members.length >= 2) {
        throw const SyncServiceException(409, 'room is full');
      }
      members.add(memberUid);
      room['members'] = members;
    }
    final token = 'token-$code-$memberUid';
    roomToken = token;
    return token;
  }

  @override
  Future<List<PairDoc>> pullAll(String roomId) async {
    _maybeThrow();
    return docs.where((d) => d.roomId == roomId).toList();
  }

  @override
  Future<String> pushDoc(PairDoc doc) async {
    _maybeThrow();
    if (doc.cloudId != null) {
      final idx = docs.indexWhere((d) => d.cloudId == doc.cloudId);
      if (idx >= 0) {
        docs[idx] = doc;
      } else {
        docs.add(doc);
      }
      return doc.cloudId!;
    }
    _docSeq++;
    final cloudId = 'cloud-$_docSeq';
    final saved = PairDoc(
      cloudId: cloudId,
      type: doc.type,
      roomId: doc.roomId,
      ownerId: doc.ownerId,
      data: doc.data,
      updatedAt: doc.updatedAt,
    );
    docs.add(saved);
    return cloudId;
  }

  @override
  Future<void> deleteDoc(String cloudId, {String? roomId}) async {
    _maybeThrow();
    final index = docs.indexWhere((d) => d.cloudId == cloudId);
    if (index < 0) return;
    final existing = docs[index];
    docs[index] = PairDoc(
      cloudId: existing.cloudId,
      type: existing.type,
      roomId: existing.roomId,
      ownerId: existing.ownerId,
      data: existing.data,
      updatedAt: DateTime.now(),
      deleted: true,
    );
  }

  /// 模拟云存储文件（测试用）
  final Map<String, List<int>> photoFiles = {};

  @override
  Future<String> uploadPhoto(String cloudPath, List<int> bytes) async {
    _maybeThrow();
    photoFiles[cloudPath] = bytes;
    return cloudPath;
  }

  @override
  Future<List<int>> downloadPhoto(String cloudPath) async {
    _maybeThrow();
    final bytes = photoFiles[cloudPath];
    if (bytes == null) throw Exception('云文件不存在: $cloudPath');
    return bytes;
  }

  @override
  Future<void> deletePhoto(String cloudPath) async {
    _maybeThrow();
    photoFiles.remove(cloudPath);
  }
}
