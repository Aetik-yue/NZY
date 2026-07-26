import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

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
      return file?.path;
    } catch (_) {
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
      return file?.path;
    } catch (_) {
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
              child: Text('选择照片', style: TextStyle(
                fontSize: 16, fontWeight: FontWeight.w600,
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
}
