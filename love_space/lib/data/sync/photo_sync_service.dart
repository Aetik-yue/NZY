import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/sync/sync_client.dart';
import '../../core/sync/sync_models.dart';
import '../models/album_photo.dart';
import 'sync_engine.dart';
import 'sync_mapper.dart';

/// 相册照片文件同步服务
///
/// 元数据（日期/分类/cloudId）由 SyncEngine 对账同步；本服务负责**照片文件**的
/// 上传/下载：本地新增照片上传到云存储，对方照片下载保存到本地相册目录。
class PhotoSyncService {
  PhotoSyncService({
    required Isar isar,
    required CloudSyncClient client,
    required SyncEngine engine,
  })  : _isar = isar,
        _client = client,
        _engine = engine;

  final Isar _isar;
  final CloudSyncClient _client;
  final SyncEngine _engine;

  bool _syncing = false;

  /// 触发一次照片同步（上传本地新照片 + 下载对方照片）
  Future<void> syncPhotos() async {
    if (_syncing || !_engine.isPaired || !_client.isConfigured) return;
    _syncing = true;
    try {
      // 先确保元数据已同步（本地新照片拿到 cloudId）
      await _engine.syncOnce();
      await _uploadLocalPhotos();
      await _downloadRemotePhotos();
    } catch (e) {
      debugPrint('[PhotoSync] 照片同步失败: $e');
    } finally {
      _syncing = false;
    }
  }

  /// 删除云端照片文件（照片删除时调用，同步删除对方侧的文件）
  Future<void> deleteRemoteFile(String cloudPath) {
    return _client.deletePhoto(cloudPath);
  }

  /// 上传本地尚未上传的照片（cloudId 已回填但 cloudPath 为空）
  Future<void> _uploadLocalPhotos() async {
    final photos = await _isar.albumPhotos.where().findAll();
    for (final photo in photos) {
      final cloudId = photo.cloudId;
      final filePath = photo.filePath;
      if (cloudId == null || photo.cloudPath != null || filePath == null) {
        continue;
      }
      final file = File(filePath);
      if (!await file.exists()) continue;
      final bytes = await file.readAsBytes();
      // 云端对象名不包含路径分隔符。
      final cloudName = '${_engine.roomCode}-$cloudId.jpg';
      final cloudPath = await _client.uploadPhoto(cloudName, bytes);
      // 回填稳定对象名，并推进时间戳，确保另一端会应用 cloudPath 变化。
      photo.cloudPath = cloudPath;
      photo.updatedAt = DateTime.now();
      await _isar.writeTxn(() async => _isar.albumPhotos.put(photo));
      // 更新云端元数据（写入 cloudPath 供对方下载）
      await _client.pushDoc(PairDoc(
        cloudId: cloudId,
        type: SyncDataType.photo,
        roomId: _engine.roomCode!,
        ownerId: photo.ownerId ?? _engine.uid ?? '',
        data: SyncMapper.toMap(photo),
        updatedAt: photo.updatedAt!,
      ));
    }
  }

  /// 下载对方照片（cloudPath 存在但本地文件缺失）
  Future<void> _downloadRemotePhotos() async {
    final photos = await _isar.albumPhotos.where().findAll();
    final dir =
        Directory('${(await getApplicationDocumentsDirectory()).path}/photos');
    if (!await dir.exists()) await dir.create(recursive: true);

    for (final photo in photos) {
      final cloudPath = photo.cloudPath;
      if (cloudPath == null) continue;
      // 本地已有文件则跳过
      if (photo.filePath != null && await File(photo.filePath!).exists()) {
        continue;
      }
      try {
        final bytes = await _client.downloadPhoto(cloudPath);
        final parsed = Uri.tryParse(cloudPath);
        final fileName = parsed != null && parsed.pathSegments.isNotEmpty
            ? parsed.pathSegments.last
            : cloudPath.split('/').last;
        final localFile = File('${dir.path}/$fileName');
        await localFile.writeAsBytes(bytes, flush: true);
        photo.filePath = localFile.path;
        await _isar.writeTxn(() async => _isar.albumPhotos.put(photo));
      } catch (e) {
        debugPrint('[PhotoSync] 下载照片失败: $cloudPath $e');
      }
    }
  }
}
