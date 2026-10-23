import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('正式版 Android manifest 声明联网与安装 APK 权限', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');

    expect(manifest.existsSync(), isTrue);
    final contents = manifest.readAsStringSync();
    expect(contents, contains('android.permission.INTERNET'));
    expect(contents, contains('android.permission.REQUEST_INSTALL_PACKAGES'));
  });

  test('应用内更新通过 FileProvider 暴露私有缓存安装包', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');
    final filePaths = File('android/app/src/main/res/xml/filepaths.xml');

    expect(manifest.existsSync(), isTrue);
    expect(filePaths.existsSync(), isTrue);
    expect(manifest.readAsStringSync(), contains('.UpdateFileProvider'));
    expect(manifest.readAsStringSync(), contains('@xml/filepaths'));
    expect(filePaths.readAsStringSync(), contains('love_updates/'));
  });

  test('MainActivity 注册安装通道并检查未知来源授权', () {
    final activity = File(
      'android/app/src/main/kotlin/com/lovespace/love_space/MainActivity.kt',
    );

    expect(activity.existsSync(), isTrue);
    final contents = activity.readAsStringSync();
    expect(contents, contains('com.lovespace.love_space/update'));
    expect(contents, contains('canRequestPackageInstalls'));
    expect(contents, contains('love_updates/update.apk'));
  });
}
