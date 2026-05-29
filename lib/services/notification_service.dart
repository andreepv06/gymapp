import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static final NotificationService instance =
      NotificationService._internal();
  NotificationService._internal();

  AudioPlayer? _audioPlayer;

  Future<void> init() async {
    try {
      _audioPlayer = AudioPlayer();
      debugPrint('Audio initialized');
    } catch (e) {
      debugPrint('Audio init error: $e');
    }
  }

  Future<void> playRestDone() async {
    // 1. Vibrazione — funziona sia su mobile che su PWA installata
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 200));
      await HapticFeedback.heavyImpact();
    } catch (_) {}

    // 2. Audio — su web richiede interazione utente precedente (policy browser)
    try {
      if (kIsWeb) {
        // Su web ricrea sempre il player: evita problemi di stato
        await _audioPlayer?.dispose();
        _audioPlayer = AudioPlayer();
        await _audioPlayer!.setVolume(1.0);
        await _audioPlayer!.play(AssetSource('sounds/rest_done.mp3'));
      } else {
        _audioPlayer ??= AudioPlayer();
        await _audioPlayer!.stop();
        await _audioPlayer!.play(AssetSource('sounds/rest_done.mp3'));
      }
      debugPrint('Audio played');
    } catch (e) {
      debugPrint('Audio playback error: $e');
    }
  }

  void dispose() {
    _audioPlayer?.dispose();
    _audioPlayer = null;
  }
}