import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService instance =
      NotificationService._internal();
  NotificationService._internal();

  AudioPlayer? _audioPlayer;

  Future<void> init() async {
    try {
      _audioPlayer = AudioPlayer();
      // Pre-carica su web per evitare ritardi
      if (kIsWeb) {
        await _audioPlayer!.setSource(AssetSource('sounds/rest_done.mp3'));
      }
    } catch (e) {
      debugPrint('Audio init error: $e');
    }
  }

  Future<void> playRestDone() async {
    try {
      _audioPlayer ??= AudioPlayer();
      await _audioPlayer!.stop();
      await _audioPlayer!.play(AssetSource('sounds/rest_done.mp3'));
    } catch (e) {
      debugPrint('Audio playback error: $e');
    }
  }

  void dispose() {
    _audioPlayer?.dispose();
    _audioPlayer = null;
  }
}