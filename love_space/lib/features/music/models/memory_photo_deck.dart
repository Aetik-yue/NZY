import 'dart:math';

/// App 相册轮播牌组。
///
/// 每轮随机展示全部照片且不重复；新一轮开始时避免与上一张立即重复。
/// 只管理文件路径顺序，不读取系统相册或文件内容。
class MemoryPhotoDeck {
  MemoryPhotoDeck({Random? random}) : _random = random ?? Random();

  final Random _random;
  List<String> _source = const [];
  List<String> _remaining = [];
  String? _current;

  /// 当前展示的照片路径。
  String? get current => _current;

  /// 当前可参与轮播的照片数量。
  int get length => _source.length;

  /// 更新 App 相册中的有效照片路径。
  ///
  /// 返回来源列表是否发生变化。当前照片仍有效时会保留，避免相册流刷新造成闪烁。
  bool updatePaths(Iterable<String> paths) {
    final normalized = <String>{
      for (final path in paths)
        if (path.isNotEmpty) path,
    }.toList(growable: false);
    if (_samePaths(_source, normalized)) return false;

    final previous = _current;
    _source = normalized;
    if (_source.isEmpty) {
      _remaining = [];
      _current = null;
      return true;
    }

    if (previous != null && _source.contains(previous)) {
      _current = previous;
      _remaining = _source.where((path) => path != previous).toList()
        ..shuffle(_random);
      return true;
    }

    _current = null;
    _remaining = List<String>.from(_source)..shuffle(_random);
    advance();
    return true;
  }

  /// 切换到下一张照片；无照片返回 null，只有一张时保持不变。
  String? advance() {
    if (_source.isEmpty) {
      _current = null;
      return null;
    }
    if (_source.length == 1) {
      _current = _source.single;
      _remaining = [];
      return _current;
    }

    if (_remaining.isEmpty) {
      _remaining = List<String>.from(_source)..shuffle(_random);
      // List 从末尾取下一张；交换可避免新一轮第一张与上一轮最后一张相同。
      if (_remaining.last == _current) {
        final first = _remaining.first;
        _remaining[0] = _remaining.last;
        _remaining[_remaining.length - 1] = first;
      }
    }

    _current = _remaining.removeLast();
    return _current;
  }

  bool _samePaths(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
