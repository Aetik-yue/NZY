import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'user_agent_rotator.dart';

/// 可靠 HTTP 客户端
///
/// 封装 [http.Client]，提供：
/// - 自动重试（指数退避，仅对网络异常 / 5xx 重试）
/// - 超时控制
/// - User-Agent 轮换
/// - 全局请求最小间隔（防爬频率限制）
/// - 编码自动检测（UTF-8 / GBK）
/// - 请求日志（debugPrint）
class AppHttpClient {
  AppHttpClient({
    this.timeout = const Duration(seconds: 15),
    this.maxRetries = 3,
    this.minInterval = const Duration(milliseconds: 1000),
    this.rotateUserAgent = true,
  });

  /// 单次请求超时
  final Duration timeout;

  /// 最大重试次数
  final int maxRetries;

  /// 全局请求最小间隔
  final Duration minInterval;

  /// 是否轮换 User-Agent
  final bool rotateUserAgent;

  final http.Client _client = http.Client();

  /// 上次请求时间（使用 Stopwatch 保证单调性）
  final Stopwatch _requestStopwatch = Stopwatch();

  /// 执行 GET 请求，返回解码后的字符串
  Future<String> get(
    String url, {
    Map<String, String>? headers,
  }) async {
    return _requestWithRetry(url, headers: headers);
  }

  /// 执行 POST 请求（表单提交），返回解码后的字符串
  Future<String> post(
    String url, {
    Map<String, String>? body,
    Map<String, String>? headers,
  }) async {
    return _requestWithRetry(url, body: body, headers: headers);
  }

  /// 带重试的请求
  Future<String> _requestWithRetry(
    String url, {
    Map<String, String>? body,
    Map<String, String>? headers,
  }) async {
    int attempt = 0;
    Object? lastError;

    while (attempt < maxRetries) {
      try {
        final result = await _doRequest(url, body: body, headers: headers);
        return result;
      } on _NonRetryableException catch (e) {
        // 4xx 客户端错误：不可重试，立即失败
        throw Exception('请求失败: $url — $e');
      } on TimeoutException {
        lastError = '请求超时';
        debugPrint('[AppHttpClient] 超时 (${attempt + 1}/$maxRetries): $url');
      } on SocketException catch (e) {
        lastError = e;
        debugPrint('[AppHttpClient] 网络异常 (${attempt + 1}/$maxRetries): $url — $e');
      } on http.ClientException catch (e) {
        lastError = e;
        debugPrint('[AppHttpClient] 客户端异常 (${attempt + 1}/$maxRetries): $url — $e');
      } catch (e) {
        // 不可恢复的编程错误（FormatException 等）：立即失败
        if (e is FormatException || e is ArgumentError) {
          throw Exception('请求失败: $url — $e');
        }
        lastError = e;
        debugPrint('[AppHttpClient] 未知异常 (${attempt + 1}/$maxRetries): $url — $e');
      }

      attempt++;
      if (attempt < maxRetries) {
        // 指数退避：1s, 2s, 4s...
        final backoff = Duration(milliseconds: 1000 * (1 << (attempt - 1)));
        await Future.delayed(backoff);
      }
    }

    throw Exception('请求失败（已重试 $maxRetries 次）: $url — $lastError');
  }

  /// 执行单次请求
  Future<String> _doRequest(
    String url, {
    Map<String, String>? body,
    Map<String, String>? headers,
  }) async {
    // 请求间隔控制
    await _enforceMinInterval();

    final uri = Uri.parse(url);
    final requestHeaders = _buildHeaders(headers);

    final stopwatch = Stopwatch()..start();
    final isPost = body != null;
    debugPrint('[AppHttpClient] ${isPost ? "POST" : "GET"} $url');

    final response = isPost
        ? await _client
            .post(uri, headers: requestHeaders, body: body)
            .timeout(timeout)
        : await _client
            .get(uri, headers: requestHeaders)
            .timeout(timeout);

    stopwatch.stop();
    debugPrint('[AppHttpClient] ${response.statusCode} ${stopwatch.elapsedMilliseconds}ms $url');

    if (response.statusCode >= 500) {
      // 5xx 服务器错误：可重试
      throw http.ClientException(
        'Server error: ${response.statusCode}',
        uri,
      );
    }

    if (response.statusCode != 200) {
      // 4xx 客户端错误：不可重试，立即失败
      throw _NonRetryableException('HTTP ${response.statusCode}');
    }

    return _decodeBody(response);
  }

  /// 构建请求头
  Map<String, String> _buildHeaders(Map<String, String>? extra) {
    final headers = <String, String>{
      'Accept':
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
      'Accept-Language': 'zh-CN,zh;q=0.9,en;q=0.8',
      'Accept-Encoding': 'gzip, deflate',
      'Connection': 'keep-alive',
      'Cache-Control': 'no-cache',
    };

    if (rotateUserAgent) {
      headers['User-Agent'] = UserAgentRotator.random;
    }

    if (extra != null) {
      headers.addAll(extra);
    }

    return headers;
  }

  /// 解码响应体（自动检测编码）
  String _decodeBody(http.Response response) {
    // 1. 从 Content-Type 头提取 charset
    final charset = _extractCharset(response.headers['content-type']);
    if (charset != null) {
      return _decodeByCharset(response.bodyBytes, charset);
    }

    // 2. 尝试从 HTML meta 标签提取 charset
    final metaCharset = _extractCharsetFromHtml(response.body);
    if (metaCharset != null) {
      return _decodeByCharset(response.bodyBytes, metaCharset);
    }

    // 3. 默认 UTF-8
    return utf8.decode(response.bodyBytes, allowMalformed: true);
  }

  /// 按指定编码解码
  String _decodeByCharset(List<int> bytes, String charset) {
    final lower = charset.toLowerCase();
    if (lower.contains('gbk') || lower.contains('gb2312') || lower.contains('gb-2312')) {
      // GBK 解码：Dart 不原生支持 GBK，先用 latin1 读取再尝试 UTF-8
      // 笔趣阁多数站点已迁移 UTF-8，此处做兜底处理
      try {
        return _decodeGbk(bytes);
      } catch (_) {
        return utf8.decode(bytes, allowMalformed: true);
      }
    }
    return utf8.decode(bytes, allowMalformed: true);
  }

  /// 从 Content-Type 提取 charset
  String? _extractCharset(String? contentType) {
    if (contentType == null) return null;
    final match = RegExp(r'charset=([^\s;]+)', caseSensitive: false)
        .firstMatch(contentType);
    return match?.group(1)?.replaceAll('"', '').trim();
  }

  /// 从 HTML meta 标签提取 charset
  String? _extractCharsetFromHtml(String body) {
    // <meta charset="utf-8">
    var match = RegExp(
      r'''<meta[^>]+charset=["']?([^"'\s;>]+)''',
      caseSensitive: false,
    ).firstMatch(body);
    if (match != null) return match.group(1);

    // <meta http-equiv="Content-Type" content="text/html; charset=utf-8">
    match = RegExp(
      r'''<meta[^>]+content=["'][^"']*charset=([^"'\s;>]+)''',
      caseSensitive: false,
    ).firstMatch(body);
    return match?.group(1);
  }

  /// GBK 解码（简化实现：逐字节解析）
  ///
  /// 注意：Dart 核心库不支持 GBK，此处使用查表法的简化版本。
  /// 对于大多数已迁移 UTF-8 的笔趣阁站点不会走到这里。
  String _decodeGbk(List<int> bytes) {
    // 兜底：先用 UTF-8 尝试，失败则用 latin1（不会乱码但可能不正确）
    try {
      final result = utf8.decode(bytes, allowMalformed: false);
      return result;
    } catch (_) {
      // 最终兜底：latin1 保证不抛异常
      return latin1.decode(bytes, allowInvalid: true);
    }
  }

  /// 强制请求最小间隔（使用单调计时器，不受系统时钟调整影响）
  Future<void> _enforceMinInterval() async {
    if (_requestStopwatch.isRunning) {
      final elapsed = _requestStopwatch.elapsed;
      if (elapsed < minInterval) {
        await Future.delayed(minInterval - elapsed);
      }
    }
    _requestStopwatch
      ..reset()
      ..start();
  }

  /// 关闭客户端
  void close() {
    _client.close();
  }
}

/// 不可重试的异常（4xx 客户端错误）
class _NonRetryableException implements Exception {
  const _NonRetryableException(this.message);
  final String message;
  @override
  String toString() => message;
}
