/// 专属录音的文件名规则。
///
/// 规则只依赖 Android MediaStore 返回的显示文件名：真实文件名去掉最后一个
/// 扩展名后，必须以 [prefix] 开头（大小写不敏感）。展示时隐藏前缀和紧随其后
/// 的常用分隔符。
abstract final class MusicFilenamePolicy {
  static const String prefix = 'yyzm';
  static const String unnamedTitle = '未命名录音';

  static final RegExp _leadingSeparators = RegExp(
    r'^[\s_＿\-－]+',
    unicode: true,
  );

  /// 是否为专属录音。
  static bool matches(String displayName) {
    return _withoutLastExtension(displayName).toLowerCase().startsWith(prefix);
  }

  /// 将真实文件名转换为 App 内展示标题。
  ///
  /// 调用方应先通过 [matches] 校验；为保持函数安全，非匹配输入会在去扩展名后
  /// 原样返回，而不会误删文件名中间的 `yyzm`。
  static String displayTitle(String displayName) {
    final stem = _withoutLastExtension(displayName);
    if (!stem.toLowerCase().startsWith(prefix)) return stem.trim();

    final withoutPrefix = stem.substring(prefix.length);
    final cleaned = withoutPrefix.replaceFirst(_leadingSeparators, '').trim();
    return cleaned.isEmpty ? unnamedTitle : cleaned;
  }

  static String _withoutLastExtension(String displayName) {
    final lastDot = displayName.lastIndexOf('.');
    if (lastDot <= 0) return displayName;
    return displayName.substring(0, lastDot);
  }
}
