import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';

/// Helper robusto per la selezione dell'immagine profilo.
///
/// Motivi del fallimento silenzioso precedente:
/// 1. Nessuna gestione di file vuoti (bytes.isEmpty)
/// 2. Nessun resize — immagini grandi causavano timeout/OOM silenzioso
/// 3. Il catch in _pickImage swallowava qualsiasi eccezione
/// 4. Nessun feedback durante l'elaborazione (l'utente pensava che non succedesse nulla)
class ImagePickerHelper {
  static const int _maxOutputBytes = 1024 * 1024; // 1 MB post-encoding

  static Future<String?> pickImageAsBase64() async {
    final picker = ImagePicker();

    XFile? file;
    try {
      file = await picker.pickImage(
        source:       ImageSource.gallery,
        // Resize al momento della pick per evitare OOM su immagini 4K+
        maxWidth:     512,
        maxHeight:    512,
        imageQuality: 88,
      );
    } catch (e) {
      debugPrint('[ImagePickerHelper] picker.pickImage error: $e');
      rethrow; // Propagato al chiamante per mostrare feedback
    }

    // Utente ha annullato la selezione — non è un errore
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
        '[ImagePickerHelper] OK — ${bytes.length} bytes → ${encoded.length} chars base64');
    return encoded;
  }
}