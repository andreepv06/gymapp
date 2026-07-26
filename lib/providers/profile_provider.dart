import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ─────────────────────────────────────────────────────────────
// ProfileProvider
// Gestisce l'immagine profilo utente.
// Usato da HomeScreen (avatar) e SettingsScreen (modifica).
// Persistenza tramite SharedPreferences (path file locale).
// ─────────────────────────────────────────────────────────────

class ProfileProvider extends ChangeNotifier {
  static const _kImageKey = 'profile_image_path';
  static const _kNameKey  = 'profile_display_name';

  String? _imagePath;
  String? _displayName;

  String? get imagePath    => _imagePath;
  String? get displayName  => _displayName;

  Future<void> loadProfile() async {
    final prefs = await SharedPreferences.getInstance();
    _imagePath   = prefs.getString(_kImageKey);
    _displayName = prefs.getString(_kNameKey);
    notifyListeners();
  }

  Future<void> setImagePath(String? path) async {
    _imagePath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null && path.isNotEmpty) {
      await prefs.setString(_kImageKey, path);
    } else {
      await prefs.remove(_kImageKey);
    }
    notifyListeners();
  }

  Future<void> setDisplayName(String? name) async {
    _displayName = name;
    final prefs = await SharedPreferences.getInstance();
    if (name != null && name.isNotEmpty) {
      await prefs.setString(_kNameKey, name);
    } else {
      await prefs.remove(_kNameKey);
    }
    notifyListeners();
  }

  Future<void> clearProfile() async {
    _imagePath = _displayName = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kImageKey);
    await prefs.remove(_kNameKey);
    notifyListeners();
  }
}