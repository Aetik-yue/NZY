import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'sync_client.dart';
import 'sync_config.dart';
import 'sync_models.dart';

/// 腾讯云 SCF 云函数同步客户端
///
/// 通过 API 网关调用部署在云函数中的 REST 接口，数据存于 COS：
/// - 匿名 uid（客户端本地生成并持久化，与 SyncEngine 的 sync_uid 一致）
/// - `/rooms` 房间、`/pairdata` 统一数据文档、`/photos` 照片文件
///
/// 鉴权：请求头 X-Sync-Secret 携带部署时设置的 SYNC_SECRET。
class ScfSyncClient implements CloudSyncClient {
  ScfSyncClient({
    http.Client? httpClient,
    String? apiBaseUrl,
    String? syncSecret,
  })  : _apiBaseUrl = (apiBaseUrl ?? SyncConfig.apiBaseUrl)
            .replaceFirst(RegExp(r'/+$'), ''),
        _syncSecret = syncSecret ?? SyncConfig.syncSecret,
        _httpClient = httpClient ?? http.Client(),
        _ownsHttpClient = httpClient == null;

  static const _kUidKey = 'sync_uid';
  static const _requestTimeout = Duration(seconds: 15);

  final http.Client _httpClient;
  final bool _ownsHttpClient;
  final String _apiBaseUrl;
  final String _syncSecret;

  String? _uid;
  bool _initialized = false;

  @override
  bool get isConfigured => _apiBaseUrl.isNotEmpty && _syncSecret.isNotEmpty;

  @override
  bool get isInitialized => _initialized;

  @override
  String? get uid => _uid;

  @override
  void dispose() {
    if (_ownsHttpClient) _httpClient.close();
  }

  Map<String, String> _headers({bool json = true, bool b64 = false}) => {
        'X-Sync-Secret': _syncSecret,
        if (json) 'Content-Type': 'application/json',
        if (b64) 'X-Body-Encoding': 'base64',
      };

  /// 请求体 base64 编码：避免网关对 UTF-8 字节的转码损坏中文（base64 为纯 ASCII）
  String _encodeBody(Map<String, dynamic> body) =>
      base64Encode(utf8.encode(jsonEncode(body)));

  Uri _uri(String path, [Map<String, String>? query]) {
    var u = Uri.parse('$_apiBaseUrl$path');
    if (query != null && query.isNotEmpty) {
      u = u.replace(queryParameters: query);
    }
    return u;
  }

  /// 将 DateTime 等不可 JSON 序列化的值转为可序列化表示
  dynamic _toJsonable(dynamic v) {
    if (v is DateTime) return v.toIso8601String();
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _toJsonable(val)));
    }
    if (v is List) return v.map(_toJsonable).toList();
    return v;
  }

  /// 将 JSON 值还原（ISO 日期字符串 -> DateTime）
  dynamic _fromJsonable(dynamic v) {
    if (v is String) {
      final dt = DateTime.tryParse(v);
      if (dt != null && v.contains('T')) return dt;
      return v;
    }
    if (v is Map) {
      return v.map((k, val) => MapEntry(k.toString(), _fromJsonable(val)));
    }
    if (v is List) return v.map(_fromJsonable).toList();
    return v;
  }

  Object? _parse(http.Response res) {
    Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(res.bodyBytes));
    } catch (_) {
      decoded = null;
    }
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return decoded;
    }
    final message = decoded is Map ? decoded['error'] : null;
    throw Exception(
      '同步服务错误 ${res.statusCode}: ${message ?? '响应格式异常'}',
    );
  }

  Map<String, dynamic> _parseMap(http.Response res) {
    final value = _parse(res);
    if (value is Map) return Map<String, dynamic>.from(value);
    throw Exception('同步服务响应格式异常');
  }

  @override
  Future<void> init() async {
    if (!isConfigured) throw const SyncNotConfiguredException();
    if (_initialized) return;
    // uid 复用 SyncEngine 的持久化 key，保证两端身份稳定
    final prefs = await SharedPreferences.getInstance();
    _uid = prefs.getString(_kUidKey);
    if (_uid == null || _uid!.isEmpty) {
      _uid = _randomHexUuid();
      await prefs.setString(_kUidKey, _uid!);
    }
    _initialized = true;
  }

  // ──────── 房间 ────────

  @override
  Future<Map<String, dynamic>?> getRoom(String code) async {
    final res = await _httpClient
        .get(
          _uri('/rooms', {'code': code}),
          headers: _headers(),
        )
        .timeout(_requestTimeout);
    final parsed = _parse(res);
    if (parsed == null) return null;
    if (parsed is! Map) throw Exception('房间查询响应格式异常');
    final data = Map<String, dynamic>.from(parsed);
    if (data.containsKey('room')) {
      final room = data['room'];
      if (room == null) return null;
      if (room is! Map) throw Exception('房间查询响应格式异常');
      return Map<String, dynamic>.from(room);
    }
    return data;
  }

  @override
  Future<void> createRoom(String code) async {
    final res = await _httpClient
        .post(
          _uri('/rooms'),
          headers: _headers(json: false, b64: true),
          body: _encodeBody({
            'code': code,
            'members': <String>[_uid!],
            'createdAt': DateTime.now().toIso8601String(),
          }),
        )
        .timeout(_requestTimeout);
    _parseMap(res);
  }

  @override
  Future<void> addRoomMember(String code, String memberUid) async {
    final res = await _httpClient
        .put(
          _uri('/rooms/$code'),
          headers: _headers(json: false, b64: true),
          body: _encodeBody({
            'members': <String>[memberUid]
          }),
        )
        .timeout(_requestTimeout);
    _parseMap(res);
  }

  // ──────── 数据文档 ────────

  @override
  Future<List<PairDoc>> pullAll(String roomId) async {
    final res = await _httpClient
        .get(
          _uri('/pairdata', {'roomId': roomId}),
          headers: _headers(),
        )
        .timeout(_requestTimeout);
    final data = _parseMap(res);
    final docs = (data['docs'] as List?) ?? const [];
    return docs.map((e) {
      final raw = _fromJsonable(e) as Map<String, dynamic>;
      // 云端主键字段为 cloudId，映射为 PairDoc 的 _id 语义
      raw['_id'] = raw['cloudId'];
      return PairDoc.fromCloudMap(raw);
    }).toList();
  }

  @override
  Future<String> pushDoc(PairDoc doc) async {
    final body = _toJsonable(doc.toCloudMap());
    if (doc.cloudId == null) {
      final res = await _httpClient
          .post(
            _uri('/pairdata'),
            headers: _headers(json: false, b64: true),
            body: _encodeBody(body),
          )
          .timeout(_requestTimeout);
      final data = _parseMap(res);
      final cloudId = data['cloudId'] as String?;
      if (cloudId == null || cloudId.isEmpty) {
        throw Exception('同步服务未返回 cloudId');
      }
      return cloudId;
    }
    final res = await _httpClient
        .put(
          _uri('/pairdata/${doc.cloudId}'),
          headers: _headers(json: false, b64: true),
          body: _encodeBody(body),
        )
        .timeout(_requestTimeout);
    _parseMap(res);
    return doc.cloudId!;
  }

  @override
  Future<void> deleteDoc(String cloudId, {String? roomId}) async {
    final res = await _httpClient
        .delete(
          _uri(
              '/pairdata/$cloudId', roomId != null ? {'roomId': roomId} : null),
          headers: _headers(json: false),
        )
        .timeout(_requestTimeout);
    _parseMap(res);
  }

  // ──────── 照片文件 ────────

  @override
  Future<String> uploadPhoto(String cloudName, List<int> bytes) async {
    // 函数 URL 无 isBase64Encoded 标记，客户端显式 base64 编码 + enc=base64 标记
    final res = await _httpClient
        .post(
          _uri('/photos', {
            'name': cloudName,
            'contentType': 'image/jpeg',
            'enc': 'base64',
          }),
          headers: {
            'X-Sync-Secret': _syncSecret,
            'Content-Type': 'text/plain',
          },
          body: base64Encode(bytes),
        )
        .timeout(_requestTimeout);
    final data = _parseMap(res);
    final name = data['name'] as String?;
    if (name == null || name.isEmpty) {
      throw Exception('上传照片失败: $cloudName');
    }
    // 云端元数据保存稳定对象名；下载时再向函数申请短时签名 URL。
    return name;
  }

  @override
  Future<List<int>> downloadPhoto(String cloudPath) async {
    Uri downloadUri;
    if (cloudPath.startsWith('http://') || cloudPath.startsWith('https://')) {
      // 兼容已保存旧版签名 URL 的本地数据。
      downloadUri = Uri.parse(cloudPath);
    } else {
      final signRes = await _httpClient
          .get(
            _uri('/photos', {'name': cloudPath}),
            headers: _headers(),
          )
          .timeout(_requestTimeout);
      final signedUrl = _parseMap(signRes)['url'] as String?;
      if (signedUrl == null || signedUrl.isEmpty) {
        throw Exception('获取照片下载地址失败: $cloudPath');
      }
      downloadUri = Uri.parse(signedUrl);
    }
    final res = await _httpClient.get(downloadUri).timeout(_requestTimeout);
    if (res.statusCode != 200) {
      throw Exception('下载照片失败 ${res.statusCode}');
    }
    return res.bodyBytes;
  }

  @override
  Future<void> deletePhoto(String cloudPath) async {
    final name =
        cloudPath.startsWith('http://') || cloudPath.startsWith('https://')
            ? Uri.parse(cloudPath).pathSegments.last
            : cloudPath.split('/').last;
    final res = await _httpClient
        .delete(
          _uri('/photos', {'name': name}),
          headers: _headers(json: false),
        )
        .timeout(_requestTimeout);
    _parseMap(res);
  }

  static String _randomHexUuid() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }
}
