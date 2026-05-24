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
    } catch (e) {
      debugPrint('Audio init error: $e');
    }
  }

  Future<void> playRestDone() async {
    try {
      if (_audioPlayer == null) await init();
      await _audioPlayer!.stop();
      await _audioPlayer!.play(AssetSource('sounds/rest_done.mp3'));
    } catch (e) {
      debugPrint('Audio error: $e');
    }
  }

  void dispose() {
    _audioPlayer?.dispose();
  }
}