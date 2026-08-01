/// 备忘录标签工具
///
/// 统一标签正则与提取逻辑，供「提取 / 高亮 / 筛选」三处共享，
/// 避免各处正则不一致导致「标签提取到、却筛不到」的问题。
library;

/// 中文友好的标签正则：
/// `#` 后跟中文 / 字母 / 数字 / 下划线，遇标点、空格、换行即结束，
/// 不会像 `#(\S+)` 那样吞掉尾随标点或整句。
final RegExp memoTagRegex = RegExp(r'#([一-龥a-zA-Z0-9_]+)');

/// 提取文本中的所有标签（去重，保持出现顺序）
List<String> extractMemoTags(String content) {
  final tags = <String>[];
  for (final m in memoTagRegex.allMatches(content)) {
    final tag = m.group(1)!;
    if (!tags.contains(tag)) tags.add(tag);
  }
  return tags;
}

/// 文本是否包含指定标签（精确匹配独立标签，避免子串误命中）
///
/// 例如筛选「旅行」时不会命中「#旅行计划」。
bool contentHasTag(String content, String tag) =>
    extractMemoTags(content).contains(tag);
