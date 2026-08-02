// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:async';
import 'dart:convert';

/// Scarica [json] come file .json con nome [filename].
Future<void> downloadJsonFile(String json, String filename) async {
  final bytes = utf8.encode(json);
  final blob  = html.Blob([bytes], 'application/json');
  final url   = html.Url.createObjectUrlFromBlob(blob);
  final a     = html.AnchorElement(href: url)
    ..setAttribute('download', filename)
    ..style.display = 'none';
  html.document.body?.append(a);
  a.click();
  a.remove();
  html.Url.revokeObjectUrl(url);
}

/// Apre il file picker e restituisce il contenuto del file JSON
/// selezionato, oppure null se l'utente ha annullato.
Future<String?> pickJsonFile() async {
  final completer = Completer<String?>();
  bool  resolved  = false;

  final input = html.FileUploadInputElement()
    ..accept = '.json,application/json';

  input.onChange.listen((e) {
    final file = input.files?.first;
    if (file == null) {
      if (!resolved) { resolved = true; completer.complete(null); }
      return;
    }
    final reader = html.FileReader();
    reader.readAsText(file);
    reader.onLoad.listen((_) {
      if (!resolved) {
        resolved = true;
        completer.complete(reader.result as String?);
      }
    });
    reader.onError.listen((_) {
      if (!resolved) { resolved = true; completer.complete(null); }
    });
  });

  html.window.addEventListener('focus', (_) {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!resolved) { resolved = true; completer.complete(null); }
    });
  }, true);

  input.click();
  return completer.future;
}