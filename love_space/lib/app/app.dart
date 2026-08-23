import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'theme/app_theme.dart';
import '../data/sync/sync_providers.dart';
import '../shared/layouts/main_shell.dart';

/// 应用根 Widget
class LoveSpaceApp extends ConsumerStatefulWidget {
  const LoveSpaceApp({super.key});

  @override
  ConsumerState<LoveSpaceApp> createState() => _LoveSpaceAppState();
}

class _LoveSpaceAppState extends ConsumerState<LoveSpaceApp> {
  @override
  void initState() {
    super.initState();
    // 只在应用根节点生命周期开始时初始化一次，避免父级 rebuild 重复同步。
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      try {
        unawaited(
          ref.read(syncEngineProvider).init().catchError(
                (Object e) => debugPrint('[App] 双人同步初始化跳过: $e'),
              ),
        );
      } catch (e) {
        debugPrint('[App] 双人同步初始化跳过: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '以越之名',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      // 中文本地化（日期选择器等系统组件显示中文）
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const MainShell(),
    );
  }
}
