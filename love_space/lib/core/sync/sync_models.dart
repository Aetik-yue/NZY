/// 同步数据类型
enum SyncDataType {
  wish,
  memo,
  timeline,
  checkin,
  anniversary,
  message,
  photo,
}

extension SyncDataTypeX on SyncDataType {
  /// 云端 type 键
  String get key => switch (this) {
        SyncDataType.wish => 'wish',
        SyncDataType.memo => 'memo',
        SyncDataType.timeline => 'timeline',
        SyncDataType.checkin => 'checkin',
        SyncDataType.anniversary => 'anniversary',
        SyncDataType.message => 'message',
        SyncDataType.photo => 'photo',
      };

  /// 从云端 type 键还原
  static SyncDataType fromKey(String key) => switch (key) {
        'memo' => SyncDataType.memo,
        'timeline' => SyncDataType.timeline,
        'checkin' => SyncDataType.checkin,
        'anniversary' => SyncDataType.anniversary,
        'message' => SyncDataType.message,
        'photo' => SyncDataType.photo,
        _ => SyncDataType.wish,
      };
}

/// 云端统一数据文档（PairData 文档的 Dart 表示）
class PairDoc {
  /// 云端文档 ID；null = 尚未上传（将走 add）
  final String? cloudId;

  final SyncDataType type;

  /// 房间码（同一房间内成员共享数据）
  final String roomId;

  /// 创建者用户 ID
  final String ownerId;

  /// 业务数据（具体字段由 SyncMapper 与本地模型互转）
  final Map<String, dynamic> data;

  /// 最后修改时间（LWW 冲突解决依据）
  final DateTime updatedAt;

  /// 删除墓碑。云端保留墓碑，确保任一设备删除后不会被另一端旧副本复活。
  final bool deleted;

  const PairDoc({
    this.cloudId,
    required this.type,
    required this.roomId,
    required this.ownerId,
    required this.data,
    required this.updatedAt,
    this.deleted = false,
  });

  /// 转为云端写入的文档 Map（不含 _id）
  Map<String, dynamic> toCloudMap() => {
        'roomId': roomId,
        'type': type.key,
        'ownerId': ownerId,
        'data': data,
        'updatedAt': updatedAt,
        'deleted': deleted,
      };

  /// 从云端文档 Map（含 _id）还原
  factory PairDoc.fromCloudMap(Map<String, dynamic> m) {
    return PairDoc(
      cloudId: m['_id']?.toString() ?? m['id']?.toString(),
      type: SyncDataTypeX.fromKey((m['type'] as String?) ?? 'wish'),
      roomId: (m['roomId'] as String?) ?? '',
      ownerId: (m['ownerId'] as String?) ?? '',
      data: Map<String, dynamic>.from((m['data'] as Map?) ?? const {}),
      updatedAt: (m['updatedAt'] as DateTime?) ??
          DateTime.fromMillisecondsSinceEpoch(0),
      deleted: m['deleted'] as bool? ?? false,
    );
  }
}
