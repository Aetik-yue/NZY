import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'app/app.dart';
import 'data/database/isar_bootstrap.dart';
import 'data/database/isar_provider.dart';
import 'data/database/seed_service.dart';
import 'data/repositories/novel_repository.dart';
import 'features/music/providers/just_audio_backend.dart';
import 'features/music/providers/music_player_provider.dart';

/// 以越之名 · 情侣恋爱空间
/// 入口
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 初始化本地数据库
  final dir = await getApplicationDocumentsDirectory();
  final isar = await openAppIsar(dir.path);

  // 首次启动写入种子数据
  await SeedService.seedIfEmpty(isar);

  // 每次启动恢复异常中断的爬取状态（进程被杀导致的卡死 crawling / 半成品）
  await NovelRepository(isar).recoverInterruptedCrawls();

  runApp(
    ProviderScope(
      overrides: [
        isarProvider.overrideWithValue(isar),
        // 音乐播放后端：just_audio 实例，ref.onDispose 确保 ProviderScope 重建时释放
        audioBackendProvider.overrideWith((ref) {
          final backend = JustAudioBackend()..init();
          ref.onDispose(backend.dispose);
          return backend;
        }),
      ],
      child: const LoveSpaceApp(),
    ),
  );

  // 注：Isar 实例会在进程退出时由 OS 回收。
  // 如需精确控制关闭时机，可在自定义 Provider 中使用 ref.onDispose 关闭 Isar 实例。
}
