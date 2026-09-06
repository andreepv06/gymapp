import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../db/hive_database.dart';
import '../db/goal_database.dart';
import '../db/sport_database.dart';
import '../db/training_mode_database.dart';
import '../services/sync/cloud_auth_bridge.dart';

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
      return _accounts.firstWhere((a) => a.identifier == _currentIdentifier);
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
      _currentIdentifier = prefs.getString('current_identifier') ?? prefs.getString('user_email');
      _currentType = prefs.getString('current_type') ?? 'email';
      _accounts = await _readAccountsFromDisk();
      debugPrint('[AUTH] checkLogin: isLoggedIn=$_isLoggedIn, '
          'identifier=$_currentIdentifier, '
          'accounts=${_accounts.map((a) => a.identifier).toList()}');
      if (_isLoggedIn && _currentIdentifier != null) {
        await HiveDatabase.instance.switchUser(_currentIdentifier!);
        await GoalDatabase.instance.switchUser(_currentIdentifier!);
        await SportDatabase.instance.switchUser(_currentIdentifier!);
        await TrainingModeDatabase.instance.switchUser(_currentIdentifier!);
      }
    } catch (e) {
      debugPrint('[AUTH] checkLogin error: $e');
      _isLoggedIn = false;
      _currentIdentifier = null;
    }
    notifyListeners();
  }

  Future<List<UserAccount>> _readAccountsFromDisk() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('accounts');
    debugPrint('[AUTH] _readAccountsFromDisk raw: $raw');
    if (raw != null && raw.isNotEmpty) {
      try {
        final list = jsonDecode(raw) as List;
        final accounts =
            list.map((e) => UserAccount.fromJson(e as Map<String, dynamic>)).toList();
        debugPrint('[AUTH] accounts letti: ${accounts.map((a) => a.identifier).toList()}');
        return accounts;
      } catch (e) {
        debugPrint('[AUTH] parse error: $e');
        return [];
      }
    }
    final oldEmail = prefs.getString('user_email');
    final oldPassword = prefs.getString('user_password');
    if (oldEmail != null && oldPassword != null) {
      debugPrint('[AUTH] migrazione vecchio account: $oldEmail');
      final migrated = [UserAccount(identifier: oldEmail, password: oldPassword, type: 'email')];
      await prefs.setString('accounts', jsonEncode(migrated.map((a) => a.toJson()).toList()));
      return migrated;
    }
    debugPrint('[AUTH] nessun account su disco');
    return [];
  }

  Future<void> _saveAccounts() async {
    final prefs = await SharedPreferences.getInstance();
    final json = jsonEncode(_accounts.map((a) => a.toJson()).toList());
    await prefs.setString('accounts', json);
    debugPrint('[AUTH] _saveAccounts: salvati ${_accounts.length} account: '
        '${_accounts.map((a) => a.identifier).toList()}');
    final verify = prefs.getString('accounts');
    debugPrint('[AUTH] verifica disco dopo save: $verify');
  }

  bool _isEmail(String value) => value.contains('@');

  Future<String?> register({
    required String identifier,
    required String password,
  }) async {
    try {
      final id = identifier.trim().toLowerCase();
      final type = _isEmail(id) ? 'email' : 'username';
      debugPrint('[AUTH] register chiamato con id="$id", type=$type');
      if (id.isEmpty) return 'Inserisci email o username';
      if (!_isEmail(id) && id.length < 3) {
        return 'Username troppo corto (min 3 caratteri)';
      }
      if (password.length < 6) {
        return 'Password troppo corta (min 6 caratteri)';
      }
      final diskAccounts = await _readAccountsFromDisk();
      debugPrint('[AUTH] account su disco prima del check: '
          '${diskAccounts.map((a) => a.identifier).toList()}');
      final exists = diskAccounts.any((a) => a.identifier == id);
      debugPrint('[AUTH] id "$id" già presente? $exists');
      if (exists) {
        final label = type == 'email' ? 'indirizzo email' : 'username';
        return 'Account già esistente con questo $label';
      }
      _accounts = diskAccounts;
      _accounts.add(UserAccount(identifier: id, password: password, type: type));
      await _saveAccounts();
      await _loginInternal(id, type, password);
      return null;
    } catch (e) {
      debugPrint('[AUTH] register error: $e');
      return 'Errore durante la registrazione';
    }
  }

  // MODIFICATO — FIX CRITICO: prima di chiedere la verifica/import al
  // backend (che scrive subito nei box Hive "correnti"), passiamo
  // esplicitamente ai box Hive di questo identifier. In precedenza lo
  // switchUser avveniva solo DENTRO _loginInternal, DOPO la verifica:
  // l'import scaricava quindi i dati nei box dell'utente sbagliato (o
  // di nessun utente), che venivano poi "seppelliti" dallo switchUser
  // successivo che apre i box (vuoti) del nuovo utente — i dati
  // sembravano scaricarsi ma sparire subito. Ora l'ordine è corretto:
  // switch PRIMA, poi verifica+import, poi tutto il resto del login.
  Future<String?> login({
    required String identifier,
    required String password,
  }) async {
    try {
      final id = identifier.trim().toLowerCase();
      debugPrint('[AUTH] login con id="$id"');
      final diskAccounts = await _readAccountsFromDisk();
      _accounts = diskAccounts;
      debugPrint('[AUTH] account disponibili: ${_accounts.map((a) => a.identifier).toList()}');

      UserAccount? account;
      try {
        account = _accounts.firstWhere((a) => a.identifier == id);
      } catch (_) {
        account = null;
      }

      if (account != null) {
        if (account.password != password) {
          return 'Password errata';
        }
        await _loginInternal(id, account.type, password);
        return null;
      }

      // Account sconosciuto su questo dispositivo: verifica sul
      // backend prima di dichiarare fallito il login.
      debugPrint('[AUTH] "$id" non trovato localmente, verifico sul backend...');

      // FIX — passa ai box Hive di "id" PRIMA della verifica, perché
      // la verifica stessa scarica e scrive subito i dati dell'utente.
      await HiveDatabase.instance.switchUser(id);
      await GoalDatabase.instance.switchUser(id);
      await SportDatabase.instance.switchUser(id);
      await TrainingModeDatabase.instance.switchUser(id);

      final remoteOk = await CloudAuthBridge.instance.verifyRemoteAccount(id, password);
      if (!remoteOk) {
        return 'Account non trovato. Registrati prima.';
      }

      // Credenziali valide sul backend: crea l'account "ombra" su
      // questo dispositivo. I dati reali sono già stati scaricati
      // nei box giusti durante la verifica, appena sopra.
      final type = _isEmail(id) ? 'email' : 'username';
      _accounts.add(UserAccount(identifier: id, password: password, type: type));
      await _saveAccounts();
      await _loginInternal(id, type, password);
      debugPrint('[AUTH] "$id" autenticato tramite verifica backend (nuovo dispositivo)');
      return null;
    } catch (e) {
      debugPrint('[AUTH] login error: $e');
      return 'Errore durante il login';
    }
  }

  Future<void> _loginInternal(String identifier, String type, String password) async {
    final prefs = await SharedPreferences.getInstance();
    _isLoggedIn = true;
    _currentIdentifier = identifier;
    _currentType = type;
    await prefs.setBool('is_logged_in', true);
    await prefs.setString('current_identifier', identifier);
    await prefs.setString('current_type', type);
    debugPrint('[AUTH] _loginInternal: loggato come $identifier');
    // Idempotente: se già switchati sopra (caso nuovo dispositivo),
    // questo è un no-op sicuro sugli stessi box già aperti.
    await HiveDatabase.instance.switchUser(identifier);
    await GoalDatabase.instance.switchUser(identifier);
    await SportDatabase.instance.switchUser(identifier);
    await TrainingModeDatabase.instance.switchUser(identifier);
    unawaited(CloudAuthBridge.instance.syncIdentity(identifier, password));
    notifyListeners();
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_logged_in', false);
    _isLoggedIn = false;
    _currentIdentifier = null;
    _currentType = null;
    debugPrint('[AUTH] logout eseguito');
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
    _accounts = await _readAccountsFromDisk();
    final idx = _accounts.indexWhere((a) => a.identifier == _currentIdentifier);
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
    final idx = _accounts.indexWhere((a) => a.identifier == _currentIdentifier);
    if (idx == -1) return;
    _accounts[idx].avatarBase64 = null;
    await _saveAccounts();
    notifyListeners();
  }
}

void unawaited(Future<void> future) {}