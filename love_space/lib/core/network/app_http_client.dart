import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:charset/charset.dart';
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
    this.minInterval = const Duration(milliseconds: 500),
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
  ///
  /// [body] 中的值会按 UTF-8 进行 URL 编码。
  Future<String> post(
    String url, {
    Map<String, String>? body,
    Map<String, String>? headers,
  }) async {
    // 表单提交必须显式声明 Content-Type，否则服务器可能 404/不识别
    final mergedHeaders = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
      if (headers != null) ...headers,
    };
    return _requestWithRetry(
        url, body: body, headers: mergedHeaders, gbkBody: false);
  }

  /// 执行 POST 请求（表单值用 GBK 编码）
  ///
  /// 笔趣阁等中文站点的搜索表单要求关键词以 GBK 编码提交，
  /// 否则服务器无法识别中文关键词。此方法将 body 中的值用 GBK 编码后
  /// 再进行 URL 编码。
  Future<String> postGbk(
    String url, {
    Map<String, String>? body,
    Map<String, String>? headers,
  }) async {
    // 表单提交必须显式声明 Content-Type，否则服务器可能 404/不识别
    final mergedHeaders = <String, String>{
      'Content-Type': 'application/x-www-form-urlencoded',
      if (headers != null) ...headers,
    };
    return _requestWithRetry(
        url, body: body, headers: mergedHeaders, gbkBody: true);
  }

  /// 带重试的请求
  Future<String> _requestWithRetry(
    String url, {
    Map<String, String>? body,
    Map<String, String>? headers,
    bool gbkBody = false,
  }) async {
    int attempt = 0;
    Object? lastError;

    while (attempt < maxRetries) {
      try {
        final result = await _doRequest(url, body: body, headers: headers, gbkBody: gbkBody);
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
    bool gbkBody = false,
  }) async {
    // 请求间隔控制
    await _enforceMinInterval();

    final uri = Uri.parse(url);
    final requestHeaders = _buildHeaders(headers);

    final stopwatch = Stopwatch()..start();
    final isPost = body != null;
    debugPrint('[AppHttpClient] ${isPost ? "POST" : "GET"} $url');

    // 构建请求体：GBK 编码时将值先用 GBK 编码再 URL 编码
    final String? encodedBody = isPost ? _encodeBody(body, gbkBody) : null;

    final response = isPost
        ? await _client
            .post(uri, headers: requestHeaders, body: encodedBody)
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

    // 404 特殊处理：笔趣阁镜像常以 404 状态码返回正常搜索/章节内容（反爬手段）
    // 因此 404 时仍返回 body，交由上层解析；其他 4xx 才抛异常。
    if (response.statusCode != 200 && response.statusCode != 404) {
      // 4xx 客户端错误：不可重试，立即失败
      throw _NonRetryableException('HTTP ${response.statusCode}');
    }

    return _decodeBody(response);
  }

  /// 编码 POST 表单体
  ///
  /// [gbkEncode] 为 true 时，值先用 GBK 编码再 URL 编码（笔趣阁搜索要求）；
  /// 否则按标准 UTF-8 URL 编码。
  String _encodeBody(Map<String, String> body, bool gbkEncode) {
    if (gbkEncode) {
      // GBK 编码：将每个值用 GBK 编码为字节，再逐字节 URL 编码
      final parts = <String>[];
      body.forEach((key, value) {
        final gbkBytes = gbk.encode(value);
        final encoded = gbkBytes.map((b) => '%${b.toRadixString(16).padLeft(2, '0').toUpperCase()}').join();
        parts.add('$key=$encoded');
      });
      return parts.join('&');
    }
    // 标准 UTF-8 表单编码
    return body.entries
        .map((e) => '${e.key}=${Uri.encodeQueryComponent(e.value)}')
        .join('&');
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

  /// 解码响应体（智能编码检测）
  ///
  /// 笔趣阁类站点存在编码欺骗与混合：meta/Content-Type 可能声明 GBK 但实际是 UTF-8，
  /// 或 UTF-8 流中混入少量 GBK 字节（如回显的搜索关键词）。最可靠的方式是优先 UTF-8。
  ///
  /// 策略：
  /// 1. UTF-8 严格解码；成功则直接采用（覆盖绝大多数页面）
  /// 2. UTF-8 容错解码（替换非法字节为 U+FFFD）；若替换比例 < 5% 则采用
  ///    （处理"UTF-8 为主、混入少量 GBK 字节"的混合页面）
  /// 3. 否则按声明的 charset 用 GBK 解码（真正的 GBK 页面）
  /// 4. 最终兜底：UTF-8 容错
  String _decodeBody(http.Response response) {
    final bytes = response.bodyBytes;

    // 1. UTF-8 严格
    final strict = _tryUtf8(bytes);
    if (strict != null) return strict;

    // 2. UTF-8 容错（容忍少量坏字节）
    final tolerant = utf8.decode(bytes, allowMalformed: true);
    final replacementRatio = _replacementRatio(tolerant, bytes);
    if (replacementRatio < 0.05) {
      return tolerant;
    }

    // 3. 按 GBK 解码（真正的 GBK 页面）
    final declared = _extractCharset(response.headers['content-type']) ??
        _extractCharsetFromHtml(latin1.decode(bytes, allowInvalid: true));
    if (declared != null) {
      final byCharset = _decodeByCharset(bytes, declared);
      if (byCharset != null) return byCharset;
    }

    // 4. 兜底
    return tolerant;
  }

  /// 计算 UTF-8 容错解码中替换字符的字节占比
  ///
  /// U+FFFD 在 UTF-8 容错解码下每个坏字节产生 1 个替换字符（3 字节 UTF-8）。
  /// 这里用替换字符数 / 原始字节数 估算坏字节比例。
  double _replacementRatio(String decoded, List<int> rawBytes) {
    if (rawBytes.isEmpty) return 1.0;
    var count = 0;
    var codeUnits = decoded.codeUnits;
    for (var i = 0; i < codeUnits.length; i++) {
      if (codeUnits[i] == 0xFFFD) count++;
    }
    return count / rawBytes.length;
  }

  /// 尝试 UTF-8 严格解码。
  /// 返回解码结果（若无非法字节序列），否则返回 null。
  String? _tryUtf8(List<int> bytes) {
    try {
      return utf8.decode(bytes, allowMalformed: false);
    } catch (_) {
      return null;
    }
  }

  /// 按指定编码解码。返回解码结果，或该编码不适用时返回 null。
  String? _decodeByCharset(List<int> bytes, String charset) {
    final lower = charset.toLowerCase();
    if (lower.contains('gbk') || lower.contains('gb2312') ||
        lower.contains('gb-2312') || lower.contains('gb18030')) {
      try {
        return gbk.decode(bytes);
      } catch (e) {
        debugPrint('[AppHttpClient] GBK 解码失败: $e');
        return null;
      }
    }
    // 其他编码（如 utf-8）已由 _tryUtf8 处理
    return null;
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
