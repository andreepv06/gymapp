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

    // Vibrazione in background — non aspettare
    _vibrate();

    // Audio
    try {
      if (kIsWeb) {
        try {
          await _audioPlayer?.dispose();
        } catch (_) {}
        _audioPlayer = AudioPlayer();
        await _audioPlayer!.setVolume(1.0);
        await _audioPlayer!.play(
            AssetSource('sounds/rest_done.mp3'));
        debugPrint('Audio played (web)');
      } else {
        _audioPlayer ??= AudioPlayer();
        try {
          await _audioPlayer!.stop();
        } catch (_) {}
        await _audioPlayer!.play(
            AssetSource('sounds/rest_done.mp3'));
        debugPrint('Audio played (mobile)');
      }
    } catch (e) {
      debugPrint('Audio playback error: $e');
    } finally {
      // Aspetta un secondo prima di permettere
      // un'altra riproduzione
      await Future.delayed(const Duration(seconds: 1));
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