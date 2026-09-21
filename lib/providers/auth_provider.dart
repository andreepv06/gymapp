import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../db/hive_database.dart';
import '../db/goal_database.dart';
import '../db/sport_database.dart';
import '../db/training_mode_database.dart';
import '../services/sync/cloud_auth_bridge.dart';
import '../services/api/dto/auth_dto.dart';

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

  // NUOVO (fix audit sincronizzazione) — registra il canale di
  // download del profilo: quando BackendAuthProvider scarica un
  // profilo dal backend (login, restore session, import iniziale
  // su un nuovo dispositivo), questo provider lo riceve e lo
  // applica all'account locale corrente. Prima d'ora questo
  // collegamento non esisteva: un profilo presente sul backend
  // non veniva mai copiato in locale.
  AuthProvider() {
    CloudAuthBridge.instance.registerProfileDownloadedHandler(
        (profile) => _applyRemoteProfile(profile));
  }

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

      debugPrint('[AUTH] "$id" non trovato localmente, verifico sul backend...');

      await HiveDatabase.instance.switchUser(id);
      await GoalDatabase.instance.switchUser(id);
      await SportDatabase.instance.switchUser(id);
      await TrainingModeDatabase.instance.switchUser(id);

      final remoteOk = await CloudAuthBridge.instance.verifyRemoteAccount(id, password);
      if (!remoteOk) {
        return 'Account non trovato. Registrati prima.';
      }

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
    unawaited(CloudAuthBridge.instance.notifyLogout());
    notifyListeners();
  }

  void setLoggedIn(String identifier) {
    _isLoggedIn = true;
    _currentIdentifier = identifier;
    notifyListeners();
  }

  // MODIFICATO (fix audit sincronizzazione) — dopo il salvataggio
  // locale (invariato), propaga al backend SOLO i campi
  // effettivamente passati in questa chiamata (update parziale),
  // fire-and-forget tramite lo stesso canale già usato per login/
  // logout. Se nessuna sessione backend è attiva, il canale è no-op
  // (comportamento offline-first invariato — vedi
  // CloudAuthBridge.notifyProfileUpdated).
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
    unawaited(CloudAuthBridge.instance.notifyProfileUpdated({
      if (displayName != null) 'displayName': displayName,
      if (firstName != null) 'firstName': firstName,
      if (lastName != null) 'lastName': lastName,
      if (birthDate != null) 'birthDate': birthDate,
      if (birthPlace != null) 'birthPlace': birthPlace,
      if (phone != null) 'phone': phone,
      if (bio != null) 'bio': bio,
      if (avatarBase64 != null) 'avatarBase64': avatarBase64,
    }));
  }

  // MODIFICATO (fix audit sincronizzazione) — propaga anche la
  // rimozione dell'avatar (stringa vuota invece di null: il campo
  // avatarUrl del backend è opzionale ma inviare esplicitamente ''
  // sovrascrive in modo pulito un valore precedente senza richiedere
  // gestione speciale di null lato validazione DTO).
  Future<void> clearAvatar() async {
    _accounts = await _readAccountsFromDisk();
    final idx = _accounts.indexWhere((a) => a.identifier == _currentIdentifier);
    if (idx == -1) return;
    _accounts[idx].avatarBase64 = null;
    await _saveAccounts();
    notifyListeners();
    unawaited(CloudAuthBridge.instance.notifyProfileUpdated({
      'avatarBase64': '',
    }));
  }

  // NUOVO (fix audit sincronizzazione) — applica al profilo locale
  // dell'utente corrente i dati scaricati dal backend. Chiamato da
  // BackendAuthProvider subito dopo ogni fetchCurrentUser() riuscito
  // (login, restore session, e soprattutto durante l'import iniziale
  // su un nuovo dispositivo). Scrive SOLO localmente (_saveAccounts):
  // non richiama mai notifyProfileUpdated, altrimenti si creerebbe un
  // loop upload↔download. Solo i campi remoti effettivamente
  // valorizzati sovrascrivono il dato locale, così un campo assente
  // sul backend non cancella un valore locale non ancora propagato.
  // FIX (bug reale trovato) — PRIMA questo metodo si basava su
  // _currentIdentifier per sapere "a chi" applicare il profilo
  // scaricato. Ma nel flusso di login su un telefono NUOVO
  // (AuthProvider.login() → verifyRemoteAccount() →
  // verifyRemoteCredentials() → notifyProfileDownloaded()), questa
  // chiamata avviene PRIMA che _loginInternal() imposti
  // _currentIdentifier — quindi la guardia "if (_currentIdentifier
  // == null) return" scartava SEMPRE il profilo appena scaricato, su
  // ogni telefono nuovo, senza eccezioni. Ora si usa
  // profile.identifier (già presente nella risposta del backend)
  // come sorgente di verità su quale account aggiornare, invece di
  // dipendere da uno stato locale non ancora aggiornato.
  Future<void> _applyRemoteProfile(BackendUserProfile profile) async {
    final targetIdentifier = profile.identifier.trim().toLowerCase();

    _accounts = await _readAccountsFromDisk();
    final idx = _accounts.indexWhere((a) => a.identifier == targetIdentifier);
    if (idx == -1) return;
    final account = _accounts[idx];

    if (profile.displayName != null) account.displayName = profile.displayName;
    if (profile.firstName != null) account.firstName = profile.firstName;
    if (profile.lastName != null) account.lastName = profile.lastName;
    if (profile.bio != null) account.bio = profile.bio;
    if (profile.avatarUrl != null && profile.avatarUrl!.isNotEmpty) {
      account.avatarBase64 = profile.avatarUrl;
    }

    await _saveAccounts();
    // Se il profilo scaricato riguarda l'utente attualmente
    // visualizzato, notifica la UI. Se riguarda un login in corso su
    // un identifier diverso da quello ancora "attivo" (raro, solo
    // nella finestra tra verify e _loginInternal), la UI si
    // aggiornerà comunque al notifyListeners() successivo chiamato
    // da _loginInternal.
    notifyListeners();
  }
}

void unawaited(Future<void> future) {}