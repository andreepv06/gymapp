// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';

Future<String?> pickImageAsBase64Impl() async {
  final completer = Completer<String?>();

  final input = html.FileUploadInputElement()
    ..accept = 'image/*'
    ..click();

  input.onChange.listen((e) {
    final file = input.files?.first;
    if (file == null) {
      completer.complete(null);
      return;
    }
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoad.listen((_) {
      final bytes = reader.result as List<int>;
      final b64 = base64Encode(bytes);
      completer.complete(b64);
    });
    reader.onError.listen((_) => completer.complete(null));
  });

  // Se l'utente chiude senza scegliere
  html.window.addEventListener('focus', (_) {
    Future.delayed(const Duration(milliseconds: 500), () {
      if (!completer.isCompleted) completer.complete(null);
    });
  }, true);

  return completer.future;
}