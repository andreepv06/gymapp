import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationService {
  static final NotificationService instance =
      NotificationService._internal();
  NotificationService._internal();

  AudioPlayer? _audioPlayer;
  bool _isPlaying = false;

  Future<void> init() async {
    try {
      if (!kIsWeb) {
        _audioPlayer = AudioPlayer();
      }
      debugPrint('NotificationService initialized');
    } catch (e) {
      debugPrint('Audio init error: $e');
    }
  }

  Future<void> playRestDone() async {
    if (_isPlaying) return;
    _isPlaying = true;

    // 1. Vibrazione — tripla, funziona su mobile e PWA installata
    _vibrate();

    // 2. Audio
    try {
      if (kIsWeb) {
        // Su web: ricrea sempre il player per bypassare stato bloccato
        // NOTA: su Safari/iOS la prima riproduzione richiede interazione utente
        try {
          await _audioPlayer?.dispose();
        } catch (_) {}
        _audioPlayer = AudioPlayer();
        await _audioPlayer!.setVolume(1.0);
        await _audioPlayer!.play(AssetSource('sounds/rest_done.mp3'));
        debugPrint('Audio played (web)');
      } else {
        // Mobile: riusa il player
        _audioPlayer ??= AudioPlayer();
        try {
          await _audioPlayer!.stop();
        } catch (_) {}
        await _audioPlayer!.play(AssetSource('sounds/rest_done.mp3'));
        debugPrint('Audio played (mobile)');
      }
    } catch (e) {
      debugPrint('Audio playback error: $e');
    } finally {
      _isPlaying = false;
    }
  }

  void _vibrate() async {
    try {
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 180));
      await HapticFeedback.heavyImpact();
      await Future.delayed(const Duration(milliseconds: 180));
      await HapticFeedback.heavyImpact();
    } catch (_) {}
  }

  void dispose() {
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _isPlaying = false;
  }
}