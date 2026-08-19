import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Helper robusto e condiviso per la selezione dell'immagine profilo.
///
/// FIX MODIFICA 1: questa è l'unica implementazione dell'ImagePickerHelper
/// ora effettivamente usata dall'app (fotocamera + galleria). La vecchia
/// implementazione in lib/screens/settings/image_picker_helper.dart (con
/// split mobile/web, nessuna gestione errori, solo galleria) non viene più
/// importata da nessuna schermata: era la causa reale del comportamento
/// intermittente segnalato (nessun try/catch robusto → eccezioni silenziose,
/// nessun controllo su file vuoti/troppo grandi, nessuna opzione fotocamera).
class ImagePickerHelper {
  static const int _maxOutputBytes = 1024 * 1024; // 1 MB post-encoding

  /// [source] = ImageSource.camera oppure ImageSource.gallery.
  /// Ritorna null se l'utente annulla (NON è un errore).
  /// Lancia un'eccezione con messaggio leggibile in ogni altro caso di
  /// fallimento, in modo che il chiamante possa sempre terminare il proprio
  /// stato di loading e mostrare un feedback (mai un loading infinito).
  static Future<String?> pickImageAsBase64({
    ImageSource source = ImageSource.gallery,
  }) async {
    final picker = ImagePicker();
    XFile? file;
    try {
      file = await picker.pickImage(
        source: source,
        // Resize al momento della pick per evitare OOM su immagini 4K+
        maxWidth: 512,
        maxHeight: 512,
        imageQuality: 88,
      );
    } catch (e) {
      debugPrint('[ImagePickerHelper] picker.pickImage error: $e');
      if (source == ImageSource.camera) {
        throw Exception(
            'Impossibile accedere alla fotocamera. Verifica i permessi dell\'app.');
      }
      throw Exception(
          'Impossibile accedere alla galleria. Verifica i permessi dell\'app.');
    }
    // Utente ha annullato la selezione — non è un errore.
    if (file == null) return null;

    Uint8List bytes;
    try {
      bytes = await file.readAsBytes();
    } catch (e) {
      debugPrint('[ImagePickerHelper] readAsBytes error: $e');
      throw Exception('Impossibile leggere il file selezionato.');
    }
    if (bytes.isEmpty) {
      throw Exception(
          'Il file selezionato è vuoto. Prova con un\'immagine diversa.');
    }
    final encoded = base64Encode(bytes);
    // Controllo dimensioni post-encoding (base64 ≈ 4/3 dei byte originali)
    if (encoded.length > _maxOutputBytes) {
      throw Exception(
          'L\'immagine è troppo grande. Seleziona un\'immagine più piccola.');
    }
    debugPrint(
        '[ImagePickerHelper] OK — ${bytes.length} bytes → ${encoded.length} chars base64 (source: $source)');
    return encoded;
  }
}