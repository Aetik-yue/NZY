import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/update_downloader.dart';
import '../data/update_installer.dart';
import '../data/update_repository.dart';
import '../domain/app_release.dart';

enum AppUpdateStatus {
  idle,
  checking,
  updateAvailable,
  upToDate,
  downloading,
  installing,
  failed,
}

class AppUpdateState {
  const AppUpdateState({
    this.status = AppUpdateStatus.idle,
    this.installedVersion,
    this.release,
    this.progress = 0,
    this.message,
  });

  final AppUpdateStatus status;
  final String? installedVersion;
  final AppRelease? release;
  final double progress;
  final String? message;

  bool get isBusy =>
      status == AppUpdateStatus.checking ||
      status == AppUpdateStatus.downloading ||
      status == AppUpdateStatus.installing;
}

final updateRepositoryProvider = Provider<UpdateRepository>((ref) {
  final repository = GitHubReleaseRepository();
  ref.onDispose(repository.close);
  return repository;
});

final appUpdateControllerProvider =
    StateNotifierProvider<AppUpdateController, AppUpdateState>((ref) {
  return AppUpdateController(
    ref.read(updateRepositoryProvider),
    downloader: HttpUpdateDownloader(),
    installer: AndroidUpdateInstaller(),
  );
});

class AppUpdateController extends StateNotifier<AppUpdateState> {
  AppUpdateController(
    this._repository, {
    required UpdateDownloader downloader,
    required UpdateInstaller installer,
    Future<String> Function()? installedVersionLoader,
  })  : _downloader = downloader,
        _installer = installer,
        _installedVersionLoader = installedVersionLoader ??
            (() async => (await PackageInfo.fromPlatform()).version),
        super(const AppUpdateState());

  static const _lastAutomaticCheckKey = 'app_update_last_automatic_check';
  static const _automaticCheckInterval = Duration(hours: 24);

  final UpdateRepository _repository;
  final UpdateDownloader _downloader;
  final UpdateInstaller _installer;
  final Future<String> Function() _installedVersionLoader;

  Future<void>? _downloadJob;
  bool _cancelRequested = false;
  File? _downloadedApk;
  String? _downloadedChecksum;

  /// 检查云端最新正式版本。自动检查每天最多一次，失败时静默。
  Future<AppRelease?> checkForUpdate({bool automatic = false}) async {
    if (state.isBusy) return null;

    final previousState = state;
    state = AppUpdateState(
      status: AppUpdateStatus.checking,
      installedVersion: state.installedVersion,
      release: state.release,
    );

    try {
      SharedPreferences? prefs;
      if (automatic) {
        prefs = await SharedPreferences.getInstance();
        final lastMillis = prefs.getInt(_lastAutomaticCheckKey);
        if (lastMillis != null) {
          final last = DateTime.fromMillisecondsSinceEpoch(lastMillis);
          if (DateTime.now().difference(last) < _automaticCheckInterval) {
            state = previousState;
            return null;
          }
        }
      }

      final installedVersion = await _installedVersionLoader();
      final release = await _repository.fetchLatestRelease();
      // 成功拿到版本信息后才消耗当天机会；离线启动不会导致 24 小时内不再重试。
      if (automatic && prefs != null) {
        await prefs.setInt(
          _lastAutomaticCheckKey,
          DateTime.now().millisecondsSinceEpoch,
        );
      }
      if (!mounted) return null;

      if (release.isNewerThan(installedVersion)) {
        state = AppUpdateState(
          status: AppUpdateStatus.updateAvailable,
          installedVersion: installedVersion,
          release: release,
          message: '发现新版本 v${release.versionName}',
        );
        return release;
      }

      state = AppUpdateState(
        status: AppUpdateStatus.upToDate,
        installedVersion: installedVersion,
        message: '当前已是最新版本 v$installedVersion',
      );
      return null;
    } catch (error) {
      if (!mounted) return null;
      state = AppUpdateState(
        status: automatic ? AppUpdateStatus.idle : AppUpdateStatus.failed,
        installedVersion: previousState.installedVersion,
        release: previousState.release,
        message: automatic ? null : _readableError(error),
      );
      return null;
    }
  }

  /// 下载、校验和调起安装分开；授权失败后可复用已校验的缓存包重试。
  Future<void> downloadAndInstall() {
    final release = state.release;
    if (release == null || state.isBusy || _downloadJob != null) {
      return Future.value();
    }
    _cancelRequested = false;
    state = AppUpdateState(
      status: AppUpdateStatus.downloading,
      installedVersion: state.installedVersion,
      release: release,
      message: '正在连接下载源…',
    );
    final job = _downloadAndInstall(release);
    final tracked = job.whenComplete(() => _downloadJob = null);
    _downloadJob = tracked;
    return tracked;
  }

  Future<void> _downloadAndInstall(AppRelease release) async {
    var current = release;
    var refreshedSource = false;

    while (true) {
      try {
        final apk = await _obtainApk(current);
        if (!mounted || _cancelRequested) return;

        state = AppUpdateState(
          status: AppUpdateStatus.installing,
          installedVersion: state.installedVersion,
          release: current,
          progress: 1,
          message: '正在打开系统安装页…',
        );
        final opened = await _installer.install(apk);
        if (!mounted || _cancelRequested) return;
        state = AppUpdateState(
          status: AppUpdateStatus.updateAvailable,
          installedVersion: state.installedVersion,
          release: current,
          progress: 1,
          message: opened
              ? '请在系统页面确认安装；如果取消或安装未完成，返回后可点“重试安装”'
              : '请允许「以越之名」安装未知来源应用，返回后点“重试安装”',
        );
        return;
      } on UpdateDownloadHttpException catch (error) {
        // 下载地址是短时签名 URL：过期后重新向云函数申请一次。
        if (!refreshedSource &&
            (error.statusCode == 401 || error.statusCode == 403) &&
            !_cancelRequested) {
          refreshedSource = true;
          try {
            final latest = await _repository.fetchLatestRelease();
            if (!mounted || _cancelRequested) return;
            current = latest;
            state = AppUpdateState(
              status: AppUpdateStatus.downloading,
              installedVersion: state.installedVersion,
              release: current,
              message: '下载地址已刷新，正在重新下载…',
            );
            continue;
          } catch (refreshError) {
            if (mounted && !_cancelRequested) {
              _setFailure(_readableError(refreshError));
            }
            return;
          }
        }
        if (mounted && !_cancelRequested) _setFailure(error.message);
        return;
      } on UpdateDownloadCanceled {
        return;
      } catch (error) {
        if (mounted && !_cancelRequested) _setFailure(_readableError(error));
        return;
      }
    }
  }

  Future<File> _obtainApk(AppRelease release) async {
    final cached = _downloadedApk;
    if (cached != null &&
        _downloadedChecksum == release.sha256 &&
        await cached.exists()) {
      return cached;
    }

    if (!mounted || _cancelRequested) throw UpdateDownloadCanceled();
    final apk = await _downloader.download(release, (progress) {
      if (!mounted || _cancelRequested) return;
      final speed = progress.bytesPerSecond >= 1024 * 1024
          ? '${(progress.bytesPerSecond / (1024 * 1024)).toStringAsFixed(1)} MB/s'
          : '${(progress.bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
      state = AppUpdateState(
        status: AppUpdateStatus.downloading,
        installedVersion: state.installedVersion,
        release: release,
        progress: progress.fraction,
        message: progress.fraction >= 1
            ? '下载完成，正在校验安装包…'
            : '正在下载 ${(progress.fraction * 100).round()}% · $speed',
      );
    });
    _downloadedApk = apk;
    _downloadedChecksum = release.sha256;
    return apk;
  }

  bool get hasDownloadedApk =>
      _downloadedApk != null && _downloadedChecksum == state.release?.sha256;

  Future<void> cancelDownload() async {
    if (state.status != AppUpdateStatus.downloading) return;
    _cancelRequested = true;
    _downloader.cancel();
    await _downloadJob;
    if (!mounted) return;
    state = AppUpdateState(
      status: AppUpdateStatus.updateAvailable,
      installedVersion: state.installedVersion,
      release: state.release,
      message: '已取消下载',
    );
  }

  void _setFailure(String message) {
    state = AppUpdateState(
      status: AppUpdateStatus.failed,
      installedVersion: state.installedVersion,
      release: state.release,
      progress: state.progress,
      message: message,
    );
  }

  String _readableError(Object error) {
    if (error is UpdateDownloadException) return error.message;
    if (error is UpdateCheckException) return error.message;
    if (error is TimeoutException) return '连接超时，请检查网络后重试';
    if (error is http.ClientException) return '无法连接更新服务，请检查网络后重试';
    if (error is FormatException) return '无法识别版本号，请稍后重试';
    return error.toString().replaceFirst('Exception: ', '');
  }

  @override
  void dispose() {
    _cancelRequested = true;
    _downloader.cancel();
    super.dispose();
  }
}
