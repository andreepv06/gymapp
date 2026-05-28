import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  static final NotificationService instance =
      NotificationService._internal();
  NotificationService._internal();

  AudioPlayer? _audioPlayer;
  bool _initialized = false;

  Future<void> init() async {
    try {
      _audioPlayer = AudioPlayer();
      _initialized = true;
      debugPrint('Audio initialized');
    } catch (e) {
      debugPrint('Audio init error: $e');
    }
  }

  Future<void> playRestDone() async {
    try {
      // Su web ricrea sempre il player per evitare problemi di stato
      if (kIsWeb) {
        await _audioPlayer?.dispose();
        _audioPlayer = AudioPlayer();
      } else {
        _audioPlayer ??= AudioPlayer();
        await _audioPlayer!.stop();
      }

      await _audioPlayer!.play(AssetSource('sounds/rest_done.mp3'));
      debugPrint('Audio played');
    } catch (e) {
      debugPrint('Audio playback error: $e');
    }
  }

  void dispose() {
    _audioPlayer?.dispose();
    _audioPlayer = null;
    _initialized = false;
  }
}