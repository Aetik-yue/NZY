import 'package:flutter_riverpod/flutter_riverpod.dart';

/// 全屏音乐页最后展示的 App 相册照片路径。
///
/// 全屏页关闭后保留该路径，供迷你播放器静态展示；计时器仅存在于全屏页中。
final musicMemoryPhotoPathProvider = StateProvider<String?>((ref) => null);
