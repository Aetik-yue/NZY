import 'dart:io';

import 'package:flutter/services.dart';

abstract class UpdateInstaller {
  /// 返回 true 表示已打开系统安装页；false 表示先打开了「安装未知应用」授权页，
  /// 用户授权后可以复用已校验的安装包重试。
  Future<bool> install(File apk);
}

/// 通过 MainActivity 注册的 MethodChannel 调起 Android 系统安装器。
class AndroidUpdateInstaller implements UpdateInstaller {
  static const channel = MethodChannel('com.lovespace.love_space/update');

  @override
  Future<bool> install(File apk) async =>
      await channel.invokeMethod<bool>('installApk', {'path': apk.path}) ??
      false;
}
