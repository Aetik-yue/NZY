import '../models/album_photo.dart';
import '../models/anniversary.dart';
import '../models/check_in.dart';
import '../models/memo.dart';
import '../models/secret_message.dart';
import '../models/timeline_event.dart';
import '../models/wish.dart';
import '../../core/sync/sync_models.dart';

/// 本地模型 <-> 云端业务数据 互转
///
/// 只转换业务字段；同步元数据（cloudId/updatedAt/ownerId）由 SyncEngine 统一维护。
class SyncMapper {
  SyncMapper._();

  /// 本地模型 -> 云端 data Map
  static Map<String, dynamic> toMap(Object model) {
    if (model is Wish) {
      return {
        'title': model.title,
        'description': model.description,
        'iconCodePoint': model.iconCodePoint,
        'done': model.done,
        'createdAt': model.createdAt,
      };
    }
    if (model is Memo) {
      return {
        'content': model.content,
        'author': model.author,
        'isPinned': model.isPinned,
        'colorValue': model.colorValue,
        'createdAt': model.createdAt,
        'updatedAt': model.updatedAt,
        'done': model.done,
        'dueDate': model.dueDate,
        'priority': model.priority.name,
      };
    }
    if (model is TimelineEvent) {
      return {
        'date': model.date,
        'title': model.title,
        'description': model.description,
        'dotColorValue': model.dotColorValue,
      };
    }
    if (model is CheckIn) {
      return {
        'date': model.date,
        'note': model.note,
      };
    }
    if (model is Anniversary) {
      return {
        'title': model.title,
        'date': model.date,
        'note': model.note,
        'colorValue': model.colorValue,
        'remindEnabled': model.remindEnabled,
        'remindDays': model.remindDays,
        'createdAt': model.createdAt,
      };
    }
    if (model is SecretMessage) {
      return {
        'content': model.content,
        'createdAt': model.createdAt,
      };
    }
    if (model is AlbumPhoto) {
      // filePath 为本机路径不参与云端同步；云端存 cloudPath（云存储文件路径）
      return {
        'date': model.date,
        'category': model.category.name,
        'gradientIndex': model.gradientIndex,
        'cloudPath': model.cloudPath,
      };
    }
    throw ArgumentError('不支持的同步模型: $model');
  }

  /// 云端 data Map -> 本地模型（不含同步元数据，由调用方补充）
  ///
  /// [id] 用于覆盖本地已有记录时保留本地 Isar 主键（避免新增重复行）。
  static Object fromMap(
    SyncDataType type,
    Map<String, dynamic> data, {
    int? id,
  }) {
    final model = switch (type) {
      SyncDataType.wish => Wish()
        ..title = data['title'] as String? ?? ''
        ..description = data['description'] as String? ?? ''
        ..iconCodePoint = (data['iconCodePoint'] as num?)?.toInt() ?? 0
        ..done = data['done'] as bool? ?? false
        ..createdAt = data['createdAt'] as DateTime? ??
            DateTime.fromMillisecondsSinceEpoch(0),
      SyncDataType.memo => Memo()
        ..content = data['content'] as String? ?? ''
        ..author = (data['author'] as num?)?.toInt() ?? 1
        ..isPinned = data['isPinned'] as bool? ?? false
        ..colorValue = (data['colorValue'] as num?)?.toInt() ?? 0xFFFF8FB1
        ..createdAt = data['createdAt'] as DateTime? ??
            DateTime.fromMillisecondsSinceEpoch(0)
        ..updatedAt = data['updatedAt'] as DateTime?
        ..done = data['done'] as bool? ?? false
        ..dueDate = data['dueDate'] as DateTime?
        ..priority = TodoPriority.values
                .asNameMap()[data['priority'] as String? ?? 'none'] ??
            TodoPriority.none,
      SyncDataType.timeline => TimelineEvent()
        ..date =
            data['date'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0)
        ..title = data['title'] as String? ?? ''
        ..description = data['description'] as String? ?? ''
        ..dotColorValue =
            (data['dotColorValue'] as num?)?.toInt() ?? 0xFFFF6B9D,
      SyncDataType.checkin => CheckIn()
        ..date =
            data['date'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0)
        ..note = data['note'] as String?,
      SyncDataType.anniversary => Anniversary()
        ..title = data['title'] as String? ?? ''
        ..date =
            data['date'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0)
        ..note = data['note'] as String? ?? ''
        ..colorValue = (data['colorValue'] as num?)?.toInt() ?? 0xFFFF6B9D
        ..remindEnabled = data['remindEnabled'] as bool? ?? false
        ..remindDays = (data['remindDays'] as num?)?.toInt() ?? 3
        ..createdAt = data['createdAt'] as DateTime? ??
            DateTime.fromMillisecondsSinceEpoch(0),
      SyncDataType.message => SecretMessage()
        ..content = data['content'] as String? ?? ''
        ..createdAt = data['createdAt'] as DateTime? ??
            DateTime.fromMillisecondsSinceEpoch(0),
      SyncDataType.photo => AlbumPhoto()
        ..date =
            data['date'] as DateTime? ?? DateTime.fromMillisecondsSinceEpoch(0)
        ..category = PhotoCategory.values
                .asNameMap()[data['category'] as String? ?? 'daily'] ??
            PhotoCategory.daily
        ..gradientIndex = (data['gradientIndex'] as num?)?.toInt() ?? 0
        ..cloudPath = data['cloudPath'] as String?,
    };
    if (id != null) {
      (model as dynamic).id = id;
    }
    return model;
  }

  /// 判断一条尚未关联云端 ID 的本地记录，是否与云端文档代表同一业务数据。
  ///
  /// 配对双方通常都带有同一批种子数据；若不先匹配，加入房间时会把这些记录
  /// 再上传一遍形成重复项。这里只使用各类型稳定且足够区分的业务键。
  static bool hasSameIdentity(Object local, Map<String, dynamic> data) {
    return switch (local) {
      Wish w => w.title == (data['title'] as String? ?? '') &&
          _sameDate(w.createdAt, data['createdAt']),
      Memo m => m.content == (data['content'] as String? ?? '') &&
          m.author == ((data['author'] as num?)?.toInt() ?? 1),
      TimelineEvent e => e.title == (data['title'] as String? ?? '') &&
          _sameDate(e.date, data['date']),
      CheckIn c => _sameDate(c.date, data['date']),
      Anniversary a => a.title == (data['title'] as String? ?? '') &&
          _sameDate(a.date, data['date']),
      SecretMessage m => m.content == (data['content'] as String? ?? '') &&
          _sameDate(m.createdAt, data['createdAt']),
      // 照片没有足够稳定的内容摘要，不能仅凭日期/分类猜测为同一张。
      AlbumPhoto _ => false,
      _ => false,
    };
  }

  /// 云端覆盖模型时保留只存在于本机的字段。
  static void copyLocalOnlyFields(Object local, Object replacement) {
    switch ((local, replacement)) {
      case (SecretMessage old, SecretMessage next):
        next.read = old.read;
      case (AlbumPhoto old, AlbumPhoto next):
        next.filePath = old.filePath;
    }
  }

  static bool _sameDate(DateTime local, Object? remote) =>
      remote is DateTime && local.isAtSameMomentAs(remote);

  /// 读取本地模型的同步元数据
  static String? cloudIdOf(Object m) => switch (m) {
        Wish(:final cloudId) => cloudId,
        Memo(:final cloudId) => cloudId,
        TimelineEvent(:final cloudId) => cloudId,
        CheckIn(:final cloudId) => cloudId,
        Anniversary(:final cloudId) => cloudId,
        SecretMessage(:final cloudId) => cloudId,
        AlbumPhoto(:final cloudId) => cloudId,
        _ => null,
      };

  static DateTime? updatedAtOf(Object m) => switch (m) {
        Wish(:final updatedAt) => updatedAt,
        Memo(:final updatedAt) => updatedAt,
        TimelineEvent(:final updatedAt) => updatedAt,
        CheckIn(:final updatedAt) => updatedAt,
        Anniversary(:final updatedAt) => updatedAt,
        SecretMessage(:final updatedAt) => updatedAt,
        AlbumPhoto(:final updatedAt) => updatedAt,
        _ => null,
      };

  static String? ownerIdOf(Object m) => switch (m) {
        Wish(:final ownerId) => ownerId,
        Memo(:final ownerId) => ownerId,
        TimelineEvent(:final ownerId) => ownerId,
        CheckIn(:final ownerId) => ownerId,
        Anniversary(:final ownerId) => ownerId,
        SecretMessage(:final ownerId) => ownerId,
        AlbumPhoto(:final ownerId) => ownerId,
        _ => null,
      };

  /// 写入同步元数据（可变模型直接赋值）
  static void applySyncMeta(
    Object m, {
    String? cloudId,
    DateTime? updatedAt,
    String? ownerId,
  }) {
    switch (m) {
      case Wish w:
        if (cloudId != null) w.cloudId = cloudId;
        if (updatedAt != null) w.updatedAt = updatedAt;
        if (ownerId != null) w.ownerId = ownerId;
      case Memo w:
        if (cloudId != null) w.cloudId = cloudId;
        if (updatedAt != null) w.updatedAt = updatedAt;
        if (ownerId != null) w.ownerId = ownerId;
      case TimelineEvent w:
        if (cloudId != null) w.cloudId = cloudId;
        if (updatedAt != null) w.updatedAt = updatedAt;
        if (ownerId != null) w.ownerId = ownerId;
      case CheckIn w:
        if (cloudId != null) w.cloudId = cloudId;
        if (updatedAt != null) w.updatedAt = updatedAt;
        if (ownerId != null) w.ownerId = ownerId;
      case Anniversary w:
        if (cloudId != null) w.cloudId = cloudId;
        if (updatedAt != null) w.updatedAt = updatedAt;
        if (ownerId != null) w.ownerId = ownerId;
      case SecretMessage w:
        if (cloudId != null) w.cloudId = cloudId;
        if (updatedAt != null) w.updatedAt = updatedAt;
        if (ownerId != null) w.ownerId = ownerId;
      case AlbumPhoto w:
        if (cloudId != null) w.cloudId = cloudId;
        if (updatedAt != null) w.updatedAt = updatedAt;
        if (ownerId != null) w.ownerId = ownerId;
    }
  }

  /// 清除同步元数据（解绑房间时调用，数据回到纯本地）
  static void clearSyncMeta(Object m) {
    switch (m) {
      case Wish w:
        w.cloudId = null;
        w.ownerId = null;
      case Memo w:
        w.cloudId = null;
        w.ownerId = null;
      case TimelineEvent w:
        w.cloudId = null;
        w.ownerId = null;
      case CheckIn w:
        w.cloudId = null;
        w.ownerId = null;
      case Anniversary w:
        w.cloudId = null;
        w.ownerId = null;
      case SecretMessage w:
        w.cloudId = null;
        w.ownerId = null;
      case AlbumPhoto w:
        w.cloudId = null;
        w.ownerId = null;
        w.cloudPath = null;
    }
  }
}
