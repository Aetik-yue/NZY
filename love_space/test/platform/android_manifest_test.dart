import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('正式版 Android manifest 声明联网权限', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml');

    expect(manifest.existsSync(), isTrue);
    expect(
      manifest.readAsStringSync(),
      contains('android.permission.INTERNET'),
    );
  });
}
