import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';
import 'app/app.dart';
import 'data/database/isar_provider.dart';
import 'data/database/seed_service.dart';
import 'data/repositories/novel_repository.dart';

/// 以越之名 · 情侣恋爱空间
/// 入口
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地数据库
  final dir = await getApplicationDocumentsDirectory();
  var isar = await _openIsarWithFallback(dir.path);

  // 首次启动写入种子数据
  await SeedService.seedIfEmpty(isar);

  // 每次启动恢复异常中断的爬取状态（进程被杀导致的卡死 crawling / 半成品）
  await NovelRepository(isar).recoverInterruptedCrawls();

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
      ],
      child: const LoveSpaceApp(),
    ),
  );

  // 注：Isar 实例会在进程退出时由 OS 回收。
  // 如需精确控制关闭时机，可在自定义 Provider 中使用 ref.onDispose 关闭 Isar 实例。
}

/// 打开 Isar；schema 变更导致旧库无法打开时删除重建
///
/// 开发期模型会随迭代变更（如字段替换），旧库 schema 不匹配会让
/// Isar.open 抛异常。此时删除旧的数据库文件重建，避免启动即崩溃
/// （数据丢失仅影响未发布版本，seed 会在下次启动自动补齐）。
Future<Isar> _openIsarWithFallback(String directory) async {
  try {
    return await Isar.open(isarSchemas, directory: directory);
  } catch (e) {
    debugPrint('[main] Isar 打开失败，删除旧库重建: $e');
    final dir = Directory(directory);
    if (dir.existsSync()) {
      for (final f in dir.listSync()) {
        if (f is File && f.path.contains('.isar')) {
          try {
            f.deleteSync();
          } catch (_) {}
        }
      }
    }
    return Isar.open(isarSchemas, directory: directory);
  }
}
