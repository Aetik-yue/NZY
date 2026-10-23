import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:love_space/features/update/application/app_update_controller.dart';
import 'package:love_space/features/update/data/update_downloader.dart';
import 'package:love_space/features/update/data/update_installer.dart';
import 'package:love_space/features/update/data/update_repository.dart';
import 'package:love_space/features/update/domain/app_release.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _sha = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

AppRelease _release(String version) {
  return AppRelease(
    version: AppRelease.parseVersion(version),
    tagName: 'v$version',
    releaseName: 'v$version',
    notes: '更新说明',
    apkName: 'YiYueZhiMing-v$version.apk',
    apkSize: 1024,
    sha256: _sha,
    apkUrl: Uri.parse('https://github.test/app.apk'),
    publishedAt: null,
  );
}

class FakeRepository implements UpdateRepository {
  FakeRepository({this.release, this.error});

  AppRelease? release;
  Object? error;
  int calls = 0;

  @override
  Future<AppRelease> fetchLatestRelease() async {
    calls++;
    if (error != null) throw error!;
    return release!;
  }

  @override
  void close() {}
}

class FakeDownloader implements UpdateDownloader {
  FakeDownloader(this.file);

  final File file;
  int calls = 0;
  bool canceled = false;

  @override
  Future<File> download(
    AppRelease release,
    void Function(UpdateDownloadProgress progress) onProgress,
  ) async {
    calls++;
    onProgress(UpdateDownloadProgress(
      received: release.apkSize,
      total: release.apkSize,
      bytesPerSecond: 1024 * 1024,
    ));
    return file;
  }

  @override
  void cancel() {
    canceled = true;
  }
}

class FakeInstaller implements UpdateInstaller {
  FakeInstaller(this.result);

  bool result;
  int calls = 0;

  @override
  Future<bool> install(File apk) async {
    calls++;
    return result;
  }
}

void main() {
  late Directory tempDir;
  late File apk;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    tempDir = await Directory.systemTemp.createTemp('love_update_controller');
    apk = File('${tempDir.path}/update.apk');
    await apk.writeAsBytes([1, 2, 3]);
  });

  tearDown(() async {
    if (await tempDir.exists()) await tempDir.delete(recursive: true);
  });

  AppUpdateController controllerWith({
    required FakeRepository repository,
    required FakeDownloader downloader,
    required FakeInstaller installer,
    String installedVersion = '1.3.1',
  }) {
    final controller = AppUpdateController(
      repository,
      downloader: downloader,
      installer: installer,
      installedVersionLoader: () async => installedVersion,
    );
    addTearDown(controller.dispose);
    return controller;
  }

  test('发现更高版本时返回新版本并进入可更新状态', () async {
    final repository = FakeRepository(release: _release('1.4.0'));
    final controller = controllerWith(
      repository: repository,
      downloader: FakeDownloader(apk),
      installer: FakeInstaller(true),
    );

    final release = await controller.checkForUpdate();

    expect(release?.versionName, '1.4.0');
    expect(controller.state.status, AppUpdateStatus.updateAvailable);
    expect(controller.state.installedVersion, '1.3.1');
  });

  test('版本相同时认为已是最新版本', () async {
    final repository = FakeRepository(release: _release('1.3.1'));
    final controller = controllerWith(
      repository: repository,
      downloader: FakeDownloader(apk),
      installer: FakeInstaller(true),
    );

    final release = await controller.checkForUpdate();

    expect(release, isNull);
    expect(controller.state.status, AppUpdateStatus.upToDate);
  });

  test('自动检查在 24 小时内不重复请求更新源', () async {
    SharedPreferences.setMockInitialValues({
      'app_update_last_automatic_check': DateTime.now().millisecondsSinceEpoch,
    });
    final repository = FakeRepository(release: _release('1.4.0'));
    final controller = controllerWith(
      repository: repository,
      downloader: FakeDownloader(apk),
      installer: FakeInstaller(true),
    );

    final release = await controller.checkForUpdate(automatic: true);

    expect(release, isNull);
    expect(repository.calls, 0);
  });

  test('自动检查失败时静默，且不消耗当天检查机会', () async {
    final repository =
        FakeRepository(error: const UpdateCheckException('网络不可用'));
    final controller = controllerWith(
      repository: repository,
      downloader: FakeDownloader(apk),
      installer: FakeInstaller(true),
    );

    expect(await controller.checkForUpdate(automatic: true), isNull);
    expect(controller.state.status, AppUpdateStatus.idle);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getInt('app_update_last_automatic_check'), isNull);

    expect(await controller.checkForUpdate(), isNull);
    expect(controller.state.status, AppUpdateStatus.failed);
    expect(controller.state.message, '网络不可用');
  });

  test('下载后调起安装，授权失败时复用已校验安装包', () async {
    final repository = FakeRepository(release: _release('1.4.0'));
    final downloader = FakeDownloader(apk);
    final installer = FakeInstaller(true);
    final controller = controllerWith(
      repository: repository,
      downloader: downloader,
      installer: installer,
    );
    await controller.checkForUpdate();

    await controller.downloadAndInstall();

    expect(downloader.calls, 1);
    expect(installer.calls, 1);
    expect(controller.hasDownloadedApk, isTrue);
    expect(controller.state.status, AppUpdateStatus.updateAvailable);
    expect(controller.state.message, contains('确认安装'));

    installer.result = false;
    await controller.downloadAndInstall();

    expect(downloader.calls, 1);
    expect(installer.calls, 2);
    expect(controller.state.message, contains('未知来源'));
  });
}
