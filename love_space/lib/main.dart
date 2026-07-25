import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'app/app.dart';
import 'data/database/isar_provider.dart';
import 'data/database/seed_service.dart';

/// 以越之名 · 情侣恋爱空间
/// 入口
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地数据库
  final dir = await getApplicationDocumentsDirectory();
  final isar = await Isar.open(isarSchemas, directory: dir.path);

  // 首次启动写入种子数据
  await SeedService.seedIfEmpty(isar);

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
      ],
      child: const LoveSpaceApp(),
    ),
  );
}
