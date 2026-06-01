import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../db/hive_database.dart';

class UserAccount {
  final String identifier;
  final String password;
  final String type;
  String? displayName;
  String? firstName;
  String? lastName;
  String? birthDate;
  String? birthPlace;
  String? phone;
  String? bio;
  String? avatarBase64;

  UserAccount({
    required this.identifier,
    required this.password,
    required this.type,
    this.displayName,
    this.firstName,
    this.lastName,
    this.birthDate,
    this.birthPlace,
    this.phone,
    this.bio,
    this.avatarBase64,
  });

  Map<String, dynamic> toJson() => {
        'identifier': identifier,
        'password': password,
        'type': type,
        'displayName': displayName,
        'firstName': firstName,
        'lastName': lastName,
        'birthDate': birthDate,
        'birthPlace': birthPlace,
        'phone': phone,
        'bio': bio,
        'avatarBase64': avatarBase64,
      };

  factory UserAccount.fromJson(Map<String, dynamic> json) =>
      UserAccount(
        identifier: json['identifier'] as String,
        password: json['password'] as String,
        type: json['type'] as String? ?? 'email',
        displayName: json['displayName'] as String?,
        firstName: json['firstName'] as String?,
        lastName: json['lastName'] as String?,
        birthDate: json['birthDate'] as String?,
        birthPlace: json['birthPlace'] as String?,
        phone: json['phone'] as String?,
        bio: json['bio'] as String?,
        avatarBase64: json['avatarBase64'] as String?,
      );

  String get fullName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    if (firstName != null) return firstName!;
    if (displayName != null) return displayName!;
    return identifier;
  }

  String get initials {
    final name = fullName;
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }
}

class AuthProvider extends ChangeNotifier {
  bool _isLoggedIn = false;
  String? _currentIdentifier;
  String? _currentType;
  List<UserAccount> _accounts = [];

  bool get isLoggedIn => _isLoggedIn;
  String? get userEmail => _currentIdentifier;
  String? get currentIdentifier => _currentIdentifier;
  String? get currentType => _currentType;
  List<UserAccount> get accounts => _accounts;

  UserAccount? get currentAccount {
    if (_currentIdentifier == null) return null;
    try {
      return _accounts
          .firstWhere((a) => a.identifier == _currentIdentifier);
    } catch (_) {
      return null;
    }
  }

  String? get displayName => currentAccount?.displayName;
  String? get bio => currentAccount?.bio;
  String get initials => currentAccount?.initials ?? '?';
  String? get avatarBase64 => currentAccount?.avatarBase64;

  Future<void> checkLogin() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
      _currentIdentifier =
          prefs.getString('current_identifier') ??
              prefs.getString('user_email');
      _currentType =
          prefs.getString('current_type') ?? 'email';

      // Ricarica sempre la lista account da disco
      await _loadAccounts();

      if (_isLoggedIn && _currentIdentifier != null) {
        await HiveDatabase.instance
            .switchUser(_currentIdentifier!);
      }
    } catch (e) {
      debugPrint('checkLogin error: $e');
      _isLoggedIn = false;
      _currentIdentifier = null;
    }
    notifyListeners();
  }

  /// Legge gli account SEMPRE da SharedPreferences —
  /// non fa mai affidamento sullo stato in memoria.
  Future<List<UserAccount>> _readAccountsFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('accounts');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        return list
            .map((e) =>
                UserAccount.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (e) {
        debugPrint('_readAccountsFromDisk parse error: $e');
        return [];
      }
    }
    // Migrazione da vecchio formato
    final oldEmail = prefs.getString('user_email');
    final oldPassword = prefs.getString('user_password');
    if (oldEmail != null && oldPassword != null) {
      final migrated = [
        UserAccount(
          identifier: oldEmail,
          password: oldPassword,
          type: 'email',
        )
      ];
      await prefs.setString(
        'accounts',
        jsonEncode(migrated.map((a) => a.toJson()).toList()),
      );
      return migrated;
    }
    return [];
  }

  Future<void> _loadAccounts() async {
    _accounts = await _readAccountsFromDisk();
  }

  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      'accounts',
      jsonEncode(_accounts.map((a) => a.toJson()).toList()),
    );
  }

  bool _isEmail(String value) => value.contains('@');

  Future<String?> register({
    required String identifier,
    required String password,
  }) async {
    try {
      final id = identifier.trim().toLowerCase();
      final type = _isEmail(id) ? 'email' : 'username';

      if (id.isEmpty) return 'Inserisci email o username';
      if (!_isEmail(id) && id.length < 3) {
        return 'Username troppo corto (min 3 caratteri)';
      }
      if (password.length < 6) {
        return 'Password troppo corta (min 6 caratteri)';
      }

      // FIX: rilegge sempre da disco prima di controllare
      // duplicati — evita falsi positivi su dati stantii
      _accounts = await _readAccountsFromDisk();

      final exists = _accounts.any((a) => a.identifier == id);
      if (exists) {
        final label =
            type == 'email' ? 'indirizzo email' : 'username';
        return 'Account già esistente con questo $label';
      }

      final newAccount = UserAccount(
        identifier: id,
        password: password,
        type: type,
      );
      _accounts.add(newAccount);
      await _saveAccounts();
      await _loginInternal(id, type);
      return null;
    } catch (e) {
      debugPrint('register error: $e');
      return 'Errore durante la registrazione';
    }
  }

  Future<String?> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final id = identifier.trim().toLowerCase();

      // FIX: rilegge da disco — la lista in memoria
      // potrebbe essere vuota dopo un logout/riavvio
      _accounts = await _readAccountsFromDisk();

      UserAccount? account;
      try {
        account =
            _accounts.firstWhere((a) => a.identifier == id);
      } catch (_) {
        return 'Account non trovato. Registrati prima.';
      }

      if (account.password != password) {
        return 'Password errata';
      }

      await _loginInternal(id, account.type);
      return null;
    } catch (e) {
      debugPrint('login error: $e');
      return 'Errore durante il login';
    }
  }

  Future<void> _loginInternal(
      String identifier, String type) async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = true;
    _currentIdentifier = identifier;
    _currentType = type;
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('current_identifier', identifier);
    await prefs.setString('current_type', type);
    await HiveDatabase.instance.switchUser(identifier);
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    _isLoggedIn = false;
    _currentIdentifier = null;
    _currentType = null;
    notifyListeners();
  }

  void setLoggedIn(String identifier) {
    _isLoggedIn = true;
    _currentIdentifier = identifier;
    notifyListeners();
  }

  Future<void> updateProfile({
    String? displayName,
    String? firstName,
    String? lastName,
    String? birthDate,
    String? birthPlace,
    String? phone,
    String? bio,
    String? avatarBase64,
  }) async {
    // Ricarica da disco prima di modificare
    _accounts = await _readAccountsFromDisk();
    final idx = _accounts
        .indexWhere((a) => a.identifier == _currentIdentifier);
    if (idx == -1) return;

    final account = _accounts[idx];
    if (displayName != null) account.displayName = displayName;
    if (firstName != null) account.firstName = firstName;
    if (lastName != null) account.lastName = lastName;
    if (birthDate != null) account.birthDate = birthDate;
    if (birthPlace != null) account.birthPlace = birthPlace;
    if (phone != null) account.phone = phone;
    if (bio != null) account.bio = bio;
    if (avatarBase64 != null) {
      account.avatarBase64 = avatarBase64;
    }
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> clearAvatar() async {
    _accounts = await _readAccountsFromDisk();
    final idx = _accounts
        .indexWhere((a) => a.identifier == _currentIdentifier);
    if (idx == -1) return;
    _accounts[idx].avatarBase64 = null;
    await _saveAccounts();
    notifyListeners();
  }
}