import 'package:isar/isar.dart';
import '../models/check_in.dart';
import '../../core/utils/date_utils.dart';

/// 打卡数据仓库
class CheckinRepository {
  CheckinRepository(this._isar);
  final Isar _isar;

  /// 查询所有打卡记录
  Future<List<CheckIn>> getAll() => _isar.checkIns.where().findAll();

  /// 监听所有打卡记录（实时流）
  Stream<List<CheckIn>> watchAll() =>
      _isar.checkIns.where().watch(fireImmediately: true);

  /// 今天是否已打卡
  Future<bool> hasCheckedInToday() async {
    final today = DateUtilsX.today();
    final count = await _isar.checkIns.where().dateEqualTo(today).count();
    return count > 0;
  }

  /// 今日打卡（幂等：已打卡则不重复插入）
  Future<void> checkInToday({String? note}) => _isar.writeTxn(() async {
        if (await hasCheckedInToday()) return;
        await _isar.checkIns.put(CheckIn()
          ..date = DateUtilsX.today()
          ..note = note
          ..updatedAt = DateTime.now());
      });

  /// 删除打卡（用于撤销）
  Future<void> delete(Id id) =>
      _isar.writeTxn(() async => _isar.checkIns.delete(id));
}
