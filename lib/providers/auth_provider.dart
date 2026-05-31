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

  factory UserAccount.fromJson(Map<String, dynamic> json) => UserAccount(
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
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = prefs.getBool('is_logged_in') ?? false;
    _currentIdentifier = prefs.getString('current_identifier') ??
        prefs.getString('user_email');
    _currentType = prefs.getString('current_type') ?? 'email';
    await _loadAccounts();
    // Se è loggato, carica le box del suo utente
    if (_isLoggedIn && _currentIdentifier != null) {
      await HiveDatabase.instance.switchUser(_currentIdentifier!);
    }
    notifyListeners();
  }

  Future<void> _loadAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('accounts');
    if (raw != null) {
      try {
        final list = jsonDecode(raw) as List;
        _accounts = list
            .map((e) =>
                UserAccount.fromJson(e as Map<String, dynamic>))
            .toList();
      } catch (_) {
        _accounts = [];
      }
    } else {
      final oldEmail = prefs.getString('user_email');
      final oldPassword = prefs.getString('user_password');
      if (oldEmail != null && oldPassword != null) {
        _accounts = [
          UserAccount(
            identifier: oldEmail,
            password: oldPassword,
            type: 'email',
          )
        ];
        await _saveAccounts();
      }
    }
  }

  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('accounts',
        jsonEncode(_accounts.map((a) => a.toJson()).toList()));
  }

  bool _isEmail(String value) => value.contains('@');

  Future<String?> register({
    required String identifier,
    required String password,
  }) async {
    final id = identifier.trim().toLowerCase();
    final type = _isEmail(id) ? 'email' : 'username';

    if (id.isEmpty) return 'Inserisci email o username';
    if (!_isEmail(id) && id.length < 3) {
      return 'Username troppo corto (min 3 caratteri)';
    }

    final exists = _accounts.any((a) => a.identifier == id);
    if (exists) {
      return 'Account già esistente con questo '
          '${type == 'email' ? 'indirizzo email' : 'username'}';
    }

    _accounts.add(UserAccount(
      identifier: id,
      password: password,
      type: type,
    ));
    await _saveAccounts();
    await _loginInternal(id, type);
    return null;
  }

  Future<String?> login({
    required String identifier,
    required String password,
  }) async {
    final id = identifier.trim().toLowerCase();
    UserAccount? account;
    try {
      account = _accounts.firstWhere((a) => a.identifier == id);
    } catch (_) {
      return 'Account non trovato. Registrati prima.';
    }
    if (account.password != password) return 'Password errata';
    await _loginInternal(id, account.type);
    return null;
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
    // Carica le box Hive dell'utente loggato
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
    final account = currentAccount;
    if (account == null) return;
    if (displayName != null) account.displayName = displayName;
    if (firstName != null) account.firstName = firstName;
    if (lastName != null) account.lastName = lastName;
    if (birthDate != null) account.birthDate = birthDate;
    if (birthPlace != null) account.birthPlace = birthPlace;
    if (phone != null) account.phone = phone;
    if (bio != null) account.bio = bio;
    if (avatarBase64 != null) account.avatarBase64 = avatarBase64;
    await _saveAccounts();
    notifyListeners();
  }

  Future<void> clearAvatar() async {
    final account = currentAccount;
    if (account == null) return;
    account.avatarBase64 = null;
    await _saveAccounts();
    notifyListeners();
  }
}