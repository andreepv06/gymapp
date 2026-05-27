import 'dart:convert';
import 'package:image_picker/image_picker.dart';

Future<String?> pickImageAsBase64Impl() async {
  final picker = ImagePicker();
  final picked = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 80,
  );
  if (picked == null) return null;
  final bytes = await picked.readAsBytes();
  return base64Encode(bytes);
}