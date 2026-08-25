import 'package:isar/isar.dart';

import 'isar_provider.dart';

typedef AppIsarOpener = Future<Isar> Function(String directory);

/// 打开应用数据库。
///
/// 打开失败时必须把异常交给上层处理，绝不能把未知的 I/O、锁冲突或磁盘
/// 故障误判为 schema 不兼容并删除用户数据。真正的 schema 迁移应通过显式、
/// 可测试的迁移流程完成。
Future<Isar> openAppIsar(
  String directory, {
  AppIsarOpener? opener,
}) {
  return (opener ?? _open)(directory);
}

Future<Isar> _open(String directory) {
  return Isar.open(isarSchemas, directory: directory);
}
