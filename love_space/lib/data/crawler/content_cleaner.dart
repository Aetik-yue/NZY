/// 内容清洗器
///
/// 对爬取的章节正文做清洗，去除广告、乱码等无关内容。
///
/// 策略：
/// 1. 规则过滤：去除 HTML 标签、广告关键词行、URL 等
/// 2. 统计启发：去除非中文比例过高的行（乱码）、过短的碎片行
class ContentCleaner {
  ContentCleaner({List<String>? adPhrases})
      : _adPhrases = adPhrases ?? _defaultAdPhrases;

  /// 硬广告短语（含这些的整行删除）。
  final List<String> _adPhrases;

  /// 默认硬广告短语
  static const List<String> _defaultAdPhrases = [
    '笔趣阁',
    '请记住',
    '本章未完',
    '点击下载',
    '推荐本书',
    '天才一秒',
    '最快更新',
    '无弹窗推荐',
    '请收藏本站',
    '顶点小说',
    '八一中文网',
    '请记住本站',
    '手机版阅读网址',
    '手机用户请',
    '请记住:域名',
    '章节错误',
    '点此举报',
    '加入书签',
    '方便下次阅读',
    '目录下载',
    '笔趣阁首发',
    '『章节错误',
    '顶点网址',
    '请记住:八一阵营',
    '天才地址',
    '燃文小说',
    '最快更新网站地址',
    '新域名',
    '请记住:新域名',
    'biqg.cc',
    'xbiquge.la',
    // 分页导航（章节页底部的翻页控件）
    '上一页',
    '下一页',
    '上一章',
    '下一章',
    '返回目录',
    '章节目录',
  ];

  /// URL 标记：含这些的子串从行内剔除（不删整行，避免误伤含 URL 的正文）
  static final RegExp _urlPattern = RegExp(
    r'https?://\S+|www\.[^\s，。]+|\.(?:com|net|cc|org|info|xyz|top)\b',
    caseSensitive: false,
  );

  /// 清洗正文
  ///
  /// 输入为可能含 HTML 标签的原始文本，输出为纯净的章节正文。
  String clean(String raw) {
    if (raw.trim().isEmpty) return '';

    var text = raw;

    // 0. 剔除 Unicode 替换字符 U+FFFD（UTF-8 容错解码坏字节产生，无意义）
    text = text.replaceAll(String.fromCharCode(0xFFFD), '');

    // 1. 去除 <script>、<style> 块
    text = _removeScriptAndStyle(text);

    // 2. 去除 HTML 标签
    text = _removeHtmlTags(text);

    // 3. 解码 HTML 实体
    text = _decodeHtmlEntities(text);

    // 4. 剔除行内的 URL 子串（不删整行，避免误伤含 URL 的正文）
    text = text.replaceAll(_urlPattern, '');

    // 5. 按行处理
    final lines = text.split('\n');
    final cleanedLines = <String>[];

    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        // 保留一个空行（合并连续空行）
        if (cleanedLines.isNotEmpty && cleanedLines.last.isNotEmpty) {
          cleanedLines.add('');
        }
        continue;
      }

      // 硬广告短语过滤（整行删除）
      if (_containsAdPhrase(trimmed)) continue;

      // 孤立导航词行（章节页翻页控件残留）删除
      if (_isNavigationWord(trimmed)) continue;

      // 统计启发：非中文比例过高 → 乱码
      if (_isGarbled(trimmed)) continue;

      // 统计启发：过短且无标点 → 碎片噪声
      if (_isNoise(trimmed)) continue;

      cleanedLines.add(trimmed);
    }

    // 6. 去除首尾空行，合并连续空行
    return _normalizeSpaces(cleanedLines);
  }

  /// 提取章节标题（从含标题的文本中提取）
  ///
  /// 笔趣阁类站点章节标题通常在正文前的 `<h1>` 或 `.bookname h1` 中，
  /// 但有时也会混在正文里。此方法尝试提取第一个看起来像标题的行。
  String extractTitle(String raw, {String fallback = ''}) {
    // 尝试从 h1 标签提取
    final h1Match = RegExp(r'<h1[^>]*>([^<]+)</h1>', caseSensitive: false)
        .firstMatch(raw);
    if (h1Match != null) {
      final title = _decodeHtmlEntities(h1Match.group(1)!.trim());
      if (title.isNotEmpty) return title;
    }

    return fallback;
  }

  // ──────── 私有方法 ────────

  String _removeScriptAndStyle(String text) {
    return text
        .replaceAll(
          RegExp(r'<script[^>]*>[\s\S]*?</script>', caseSensitive: false),
          '',
        )
        .replaceAll(
          RegExp(r'<style[^>]*>[\s\S]*?</style>', caseSensitive: false),
          '',
        );
  }

  String _removeHtmlTags(String text) {
    // 块级标签转换为换行符（保留段落结构），避免正文被压成一整行
    var result = text;
    result = result.replaceAll(
      RegExp(r'</?(p|div|br|tr|li|h[1-6])[^>]*>', caseSensitive: false),
      '\n',
    );
    // 其余标签直接删除
    result = result.replaceAll(RegExp(r'<[^>]+>'), '');
    return result;
  }

  /// 常见 HTML 命名实体映射表
  static const Map<String, String> _namedEntities = {
    '&nbsp;': ' ',
    '&amp;': '&',
    '&lt;': '<',
    '&gt;': '>',
    '&quot;': '"',
    '&#39;': "'",
    '&apos;': "'",
    '&mdash;': '—',
    '&hellip;': '…',
    '&middot;': '·',
    '&lsquo;': ''',
    '&rsquo;': ''',
    '&ldquo;': '"',
    '&rdquo;': '"',
    '&laquo;': '«',
    '&raquo;': '»',
    '&copy;': '©',
    '&reg;': '®',
    '&trade;': '™',
    '&bull;': '•',
    '&deg;': '°',
    '&times;': '×',
    '&divide;': '÷',
  };

  String _decodeHtmlEntities(String text) {
    var result = text;

    // 转换常见命名实体
    for (final entry in _namedEntities.entries) {
      result = result.replaceAll(entry.key, entry.value);
    }

    // 转换数字字符实体（如 &#20013; → 中）
    result = result.replaceAllMapped(
      RegExp(r'&#(\d+);'),
      (match) {
        final code = int.tryParse(match.group(1) ?? '');
        if (code == null || code < 0 || code > 0x10FFFF) return match.group(0)!;
        return String.fromCharCode(code);
      },
    );

    // 转换十六进制字符实体（如 &#x4E2D; → 中）
    result = result.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (match) {
        final code = int.tryParse(match.group(1) ?? '', radix: 16);
        if (code == null || code < 0 || code > 0x10FFFF) return match.group(0)!;
        return String.fromCharCode(code);
      },
    );

    // 移除无法识别的命名实体
    result = result.replaceAll(RegExp(r'&[a-zA-Z]+;'), '');

    return result;
  }

  bool _containsAdPhrase(String line) {
    for (final phrase in _adPhrases) {
      if (line.contains(phrase)) return true;
    }
    return false;
  }

  /// 判断是否为孤立的导航词行（章节页翻页控件残留）
  static const _navigationWords = {"目录", "书页", "首页", "返回顶部", "上页", "下页"};
  bool _isNavigationWord(String line) => _navigationWords.contains(line);

  /// 判断是否为乱码行（中文比例 < 40%）
  bool _isGarbled(String line) {
    if (line.isEmpty) return false;
    final chineseCount = RegExp(r'[一-龥]').allMatches(line).length;
    final ratio = chineseCount / line.length;
    return ratio < 0.4; // 中文比例 < 40% 视为乱码
  }

  /// 判断是否为噪声行（过短且无中文标点）
  bool _isNoise(String line) {
    if (line.length < 5 && !RegExp(r'[一-龥]').hasMatch(line)) {
      return true;
    }
    return false;
  }

  String _normalizeSpaces(List<String> lines) {
    // 去除首尾空行
    while (lines.isNotEmpty && lines.first.isEmpty) {
      lines.removeAt(0);
    }
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }

    // 合并连续空行
    final result = <String>[];
    for (final line in lines) {
      if (line.isEmpty) {
        if (result.isEmpty || result.last.isNotEmpty) {
          result.add(line);
        }
      } else {
        result.add(line);
      }
    }

    return result.join('\n');
  }
}
