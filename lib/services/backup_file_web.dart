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
/// MODIFICATO — risolta una race condition che causava un
/// comportamento INTERMITTENTE dell'importazione (a volte
/// funzionava, a volte si interrompeva silenziosamente senza alcun
/// errore mostrato).
///
/// Causa: i browser non emettono un evento "cancel" affidabile per
/// <input type="file">, quindi il codice usa un trucco diffuso —
/// ascoltare l'evento "focus" della finestra, che si riattiva sia
/// quando l'utente seleziona un file SIA quando annulla il picker
/// nativo del sistema operativo, con un timeout di 600ms per
/// distinguere i due casi. Il bug: quel timeout gareggiava contro la
/// lettura asincrona del file (FileReader) — se il file era più
/// grande o il browser più lento in quel momento, il timeout di
/// "annullamento presunto" poteva scattare PRIMA che la lettura del
/// file selezionato fosse completata, facendo risultare `null`
/// un'importazione in realtà valida, senza alcun errore mostrato.
/// Il listener "focus" inoltre non veniva MAI rimosso da `window`,
/// accumulandosi ad ogni apertura del picker.
///
/// Fix: un flag `fileSelected` viene impostato SUBITO in `onChange`
/// (che scatta appena il browser ha processato la selezione, ben
/// prima che FileReader finisca di leggere) — il listener "focus" ora
/// considera "annullato" solo se `onChange` non è MAI scattato,
/// eliminando la competizione con la lettura del file. Il listener
/// viene inoltre sempre rimosso al termine, evitando l'accumulo.
Future<String?> pickJsonFile() async {
  final completer = Completer<String?>();
  bool resolved = false;
  bool fileSelected = false;
  final input = html.FileUploadInputElement()
    ..accept = '.json,application/json';

  void resolveOnce(String? value) {
    if (!resolved) {
      resolved = true;
      completer.complete(value);
    }
  }

  late final void Function(html.Event) focusListener;
  focusListener = (_) {
    Future.delayed(const Duration(milliseconds: 600), () {
      // NUOVO — se onChange è già scattato (fileSelected == true),
      // la lettura del file è in corso o già completata: NON è un
      // annullamento, quindi non risolviamo qui, lasciamo che sia
      // reader.onLoad/onError a completare il Completer.
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
    fileSelected = true; // NUOVO — marca la selezione PRIMA di leggere
    final reader = html.FileReader();
    reader.readAsText(file);
    reader.onLoad.listen((_) {
      resolveOnce(reader.result as String?);
    });
    reader.onError.listen((_) {
      resolveOnce(null);
    });
  });

  html.window.addEventListener('focus', focusListener, true);
  input.click();
  return completer.future;
}