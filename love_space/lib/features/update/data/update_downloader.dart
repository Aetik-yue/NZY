import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import '../domain/app_release.dart';

class UpdateDownloadCanceled implements Exception {}

class UpdateDownloadException implements Exception {
  const UpdateDownloadException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// 下载地址失效时保留 HTTP 状态码，便于控制器刷新签名地址后重试。
class UpdateDownloadHttpException extends UpdateDownloadException {
  const UpdateDownloadHttpException(super.message, this.statusCode);

  final int statusCode;
}

class UpdateDownloadProgress {
  const UpdateDownloadProgress({
    required this.received,
    required this.total,
    required this.bytesPerSecond,
  });

  final int received;
  final int total;
  final double bytesPerSecond;

  double get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : 0.0;
}

abstract class UpdateDownloader {
  Future<File> download(
    AppRelease release,
    void Function(UpdateDownloadProgress progress) onProgress,
  );

  void cancel();
}

/// 下载到应用私有缓存，校验 SHA-256 后保留固定文件名供系统安装器读取。
class HttpUpdateDownloader implements UpdateDownloader {
  HttpUpdateDownloader({
    http.Client Function()? clientFactory,
    Future<Directory> Function()? directory,
    this.connectionTimeout = const Duration(seconds: 20),
    this.stallTimeout = const Duration(seconds: 30),
  })  : _clientFactory = clientFactory ?? http.Client.new,
        _directory = directory ?? getTemporaryDirectory;

  /// 固定文件名，同时与 Android FileProvider 的缓存路径保持一致。
  static const folderName = 'love_updates';
  static const apkFileName = 'update.apk';

  final http.Client Function() _clientFactory;
  final Future<Directory> Function() _directory;
  final Duration connectionTimeout;
  final Duration stallTimeout;

  http.Client? _activeClient;
  bool _canceled = false;

  @override
  void cancel() {
    _canceled = true;
    _activeClient?.close();
  }

  void _checkCanceled() {
    if (_canceled) throw UpdateDownloadCanceled();
  }

  @override
  Future<File> download(
    AppRelease release,
    void Function(UpdateDownloadProgress progress) onProgress,
  ) async {
    _canceled = false;
    final directory = await _directory();
    _checkCanceled();
    final folder = Directory('${directory.path}/$folderName');
    await folder.create(recursive: true);
    final partial = File('${folder.path}/$apkFileName.part');
    final verified = File('${folder.path}/$apkFileName');

    final urls = release.downloadUrls;
    UpdateDownloadException? lastError;

    for (var index = 0; index < urls.length; index++) {
      _checkCanceled();
      final client = _clientFactory();
      _activeClient = client;
      RandomAccessFile? output;
      try {
        onProgress(UpdateDownloadProgress(
          received: 0,
          total: release.apkSize,
          bytesPerSecond: 0,
        ));
        final response = await client
            .send(
              http.Request('GET', urls[index])
                ..headers['User-Agent'] = 'LoveSpace-Android-Updater',
            )
            .timeout(connectionTimeout);
        _checkCanceled();
        if (response.statusCode != 200) {
          throw UpdateDownloadHttpException(
            '下载源暂不可用',
            response.statusCode,
          );
        }

        final total = release.apkSize > 0
            ? release.apkSize
            : (response.contentLength ?? 0);
        var received = 0;
        var lastReport = 0;
        final stopwatch = Stopwatch()..start();
        output = await partial.open(mode: FileMode.write);

        await for (final bytes in response.stream
            .where((chunk) => chunk.isNotEmpty)
            .timeout(stallTimeout)) {
          _checkCanceled();
          received += bytes.length;
          if (total > 0 && received > total) {
            throw const UpdateDownloadException('安装包大小与版本信息不一致');
          }
          await output.writeFrom(bytes);

          final elapsed = stopwatch.elapsedMilliseconds;
          if (elapsed - lastReport >= 250 || received == total) {
            onProgress(UpdateDownloadProgress(
              received: received,
              total: total,
              bytesPerSecond: elapsed > 0 ? received * 1000 / elapsed : 0,
            ));
            lastReport = elapsed;
          }
        }

        await output.close();
        output = null;
        _checkCanceled();
        if (received == 0 || (total > 0 && received != total)) {
          throw const UpdateDownloadException('安装包未下载完整，请重试');
        }

        final digest = await sha256.bind(partial.openRead()).first;
        _checkCanceled();
        if (digest.toString().toLowerCase() != release.sha256) {
          throw const UpdateDownloadException('安装包完整性校验失败，已停止安装');
        }

        if (await verified.exists()) await verified.delete();
        await partial.rename(verified.path);
        return verified;
      } on UpdateDownloadHttpException catch (error) {
        _checkCanceled();
        lastError = error;
      } on TimeoutException {
        _checkCanceled();
        lastError = const UpdateDownloadException(
          '下载连接超时或长时间无进展，请稍后重试',
        );
      } on UpdateDownloadCanceled {
        rethrow;
      } on UpdateDownloadException catch (error) {
        _checkCanceled();
        lastError = error;
      } on Exception {
        _checkCanceled();
        lastError = const UpdateDownloadException(
          '安装包下载失败，请检查网络后重试',
        );
      } finally {
        client.close();
        _activeClient = null;
        await output?.close();
        if (await partial.exists()) await partial.delete();
      }
    }

    throw lastError ?? const UpdateDownloadException('安装包下载失败，请检查网络后重试');
  }
}
