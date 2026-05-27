import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;

// Import condizionale
import 'image_picker_helper_web.dart'
    if (dart.library.io) 'image_picker_helper_mobile.dart';

class ImagePickerHelper {
  static Future<String?> pickImageAsBase64() async {
    return pickImageAsBase64Impl();
  }
}