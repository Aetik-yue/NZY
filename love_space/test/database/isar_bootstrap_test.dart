import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:isar/isar.dart';

import 'package:love_space/data/database/isar_bootstrap.dart';

void main() {
  test('数据库打开失败时保留现有 Isar 文件并向上抛出异常', () async {
    final directory = await Directory.systemTemp.createTemp('isar_bootstrap_');
    addTearDown(() => directory.delete(recursive: true));
    final databaseFile = File('${directory.path}/default.isar');
    await databaseFile.writeAsString('user-data');

    await expectLater(
      openAppIsar(
        directory.path,
        opener: (_) => Future<Isar>.error(StateError('database locked')),
      ),
      throwsA(isA<StateError>()),
    );

    expect(databaseFile.existsSync(), isTrue);
    expect(await databaseFile.readAsString(), 'user-data');
  });
}
