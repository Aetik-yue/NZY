import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

/// 图片选择工具类
class ImagePickerHelper {
  static final ImagePicker _picker = ImagePicker();

  /// 从相册选择一张图片
  static Future<String?> pickFromGallery() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      return file == null ? null : _persist(file);
    } catch (e) {
      debugPrint('[ImagePicker] 从相册选择失败: $e');
      return null;
    }
  }

  /// 用相机拍摄一张图片
  static Future<String?> pickFromCamera() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1920,
        maxHeight: 1920,
        imageQuality: 85,
      );
      return file == null ? null : _persist(file);
    } catch (e) {
      debugPrint('[ImagePicker] 拍照失败: $e');
      return null;
    }
  }

  /// 弹出选择菜单（相册/相机），返回选择的图片路径
  static Future<String?> pickImage(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('选择照片',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  )),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_rounded),
              title: const Text('从相册选择'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_rounded),
              title: const Text('拍照'),
              onTap: () => Navigator.of(ctx).pop(ImageSource.camera),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );

    if (source == null) return null;
    if (source == ImageSource.gallery) return pickFromGallery();
    return pickFromCamera();
  }

  /// image_picker 返回的文件可能位于系统缓存；入库前复制到应用文档目录，
  /// 避免系统清理缓存后相册记录只剩失效路径。
  static Future<String> _persist(XFile picked) async {
    final root = await getApplicationDocumentsDirectory();
    final directory = Directory('${root.path}/photos');
    if (!await directory.exists()) await directory.create(recursive: true);

    final dot = picked.name.lastIndexOf('.');
    final rawExtension = dot >= 0 ? picked.name.substring(dot) : '.jpg';
    final extension = RegExp(r'^\.[A-Za-z0-9]{1,8}$').hasMatch(rawExtension)
        ? rawExtension.toLowerCase()
        : '.jpg';
    final target = File(
      '${directory.path}/photo_${DateTime.now().microsecondsSinceEpoch}$extension',
    );
    await File(picked.path).copy(target.path);
    return target.path;
  }
}
