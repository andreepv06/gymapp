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
///
/// MODIFICATO (round 2) — l'elemento <input type="file"> ora viene
/// SEMPRE inserito nel DOM (document.body) prima di invocare click()
/// e rimosso quando la selezione è risolta. In precedenza l'elemento
/// restava "fluttuante" (mai attaccato al documento): alcuni browser
/// tollerano il click programmatico su un input non montato solo per
/// un numero limitato di invocazioni consecutive, dopodiché iniziano
/// a ignorarlo silenziosamente — nessuna eccezione, nessun evento,
/// il picker semplicemente smette di aprirsi. Root cause diretta del
/// comportamento "funziona a volte, poi mai più" segnalato.
///
/// Mantiene inoltre il fix precedente sul flag `fileSelected` per
/// evitare che il rilevamento "annullamento" (basato sull'evento
/// window.focus, unico segnale disponibile per l'annullamento del
/// picker nativo) corra contro la lettura asincrona del file.
Future<String?> pickJsonFile() async {
  final completer = Completer<String?>();
  bool resolved = false;
  bool fileSelected = false;
  final input = html.FileUploadInputElement()
    ..accept = '.json,application/json'
    ..style.display = 'none';

  void cleanup() {
    if (input.isConnected == true) {
      input.remove();
    }
  }

  void resolveOnce(String? value) {
    if (!resolved) {
      resolved = true;
      cleanup();
      completer.complete(value);
    }
  }

  late final void Function(html.Event) focusListener;
  focusListener = (_) {
    Future.delayed(const Duration(milliseconds: 600), () {
      if (!fileSelected) {
        resolveOnce(null);
      }
      html.window.removeEventListener('focus', focusListener, true);
    });
  };

  input.onChange.listen((e) {
    final file = input.files?.first;
    if (file == null) {
      resolveOnce(null);
      return;
    }
    fileSelected = true;
    final reader = html.FileReader();
    reader.readAsText(file);
    reader.onLoad.listen((_) {
      resolveOnce(reader.result as String?);
    });
    reader.onError.listen((_) {
      resolveOnce(null);
    });
  });

  html.document.body?.append(input);
  html.window.addEventListener('focus', focusListener, true);
  input.click();
  return completer.future;
}