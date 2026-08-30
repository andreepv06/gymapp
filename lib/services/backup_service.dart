import 'dart:convert';
import 'package:hive/hive.dart';
import '../db/goal_database.dart';
import '../db/hive_database.dart';
import '../db/sport_database.dart';
import '../db/training_mode_database.dart';
import '../models/goal_models.dart';
import '../models/hive_models.dart';
import '../models/sport_models.dart';
import '../models/training_mode.dart';
import '../providers/auth_provider.dart';
import 'backup_file.dart';

// ─────────────────────────────────────────────────────────────
// MODIFICA 3 — Import/Export
//
// Due tipologie di export:
//  - full      → backup completo (profilo, schede, esercizi,
//                modalità, storico, obiettivi, sport). Distruttivo
//                al momento dell'import (sostituisce i dati attuali).
//  - structure → solo schede + esercizi + modalità EFFETTIVAMENTE
//                usati da quelle schede. NESSUN profilo, NESSUNO
//                storico, NESSUN obiettivo. Additivo al momento
//                dell'import (mai sovrascrive dati esistenti,
//                dedup di esercizi/modalità per evitare duplicati
//                incontrollati, le schede vengono sempre create
//                come nuove voci).
// ─────────────────────────────────────────────────────────────
enum BackupExportType { full, structure }

// ─────────────────────────────────────────────────────────────
// BackupData — struttura intermedia del backup
// ─────────────────────────────────────────────────────────────
class BackupData {
  final String version;
  final int schemaVersion;
  final String exportType; // 'full' | 'structure'
  final String exportedAt;
  final String userId;
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> exercises;
  final List<Map<String, dynamic>> workouts;
  final List<Map<String, dynamic>> workoutExercises;
  final List<Map<String, dynamic>> circuits;
  final List<Map<String, dynamic>> trainingModes;
  final List<Map<String, dynamic>> sessions;
  final List<Map<String, dynamic>> sessionSets;
  final List<Map<String, dynamic>> exerciseNotes;
  final List<Map<String, dynamic>> goals;
  final List<Map<String, dynamic>> goalCompletions;
  final List<Map<String, dynamic>> sportSessions;
  final Map<String, dynamic> preferences;

  const BackupData({
    required this.version,
    required this.schemaVersion,
    required this.exportType,
    required this.exportedAt,
    required this.userId,
    required this.profile,
    required this.exercises,
    required this.workouts,
    required this.workoutExercises,
    required this.circuits,
    required this.trainingModes,
    required this.sessions,
    required this.sessionSets,
    required this.exerciseNotes,
    required this.goals,
    required this.goalCompletions,
    required this.sportSessions,
    required this.preferences,
  });

  bool get isStructureOnly => exportType == 'structure';

  Map<String, dynamic> toJson() => {
        'version': version,
        'schemaVersion': schemaVersion,
        'exportType': exportType,
        'app': 'MarkFit',
        'exportedAt': exportedAt,
        'userId': userId,
        'profile': profile,
        'exercises': exercises,
        'workouts': workouts,
        'workoutExercises': workoutExercises,
        'circuits': circuits,
        'trainingModes': trainingModes,
        'sessions': sessions,
        'sessionSets': sessionSets,
        'exerciseNotes': exerciseNotes,
        'goals': goals,
        'goalCompletions': goalCompletions,
        'sportSessions': sportSessions,
        'preferences': preferences,
      };
}

// ─────────────────────────────────────────────────────────────
// BackupService
// ─────────────────────────────────────────────────────────────
class BackupService {
  BackupService._();
  static final instance = BackupService._();

  static const _kVersion = '1.1.0';
  // Versione dello SCHEMA DATI (distinta dalla versione applicativa
  // sopra): incrementata ogni volta che la struttura del file di
  // backup cambia in modo non retrocompatibile. v1 = backup pre
  // sistema Modalità di Allenamento (nessun campo trainingModes/
  // exportType/schemaVersion). v2 = introduzione di trainingModes,
  // exportType, trainingModeKey su workoutExercises/sessionSets.
  static const _kSchemaVersion = 2;

  // ── EXPORT ────────────────────────────────────────────────
  Future<void> exportBackup({
    required AuthProvider auth,
    required bool isDark,
    required BackupExportType type,
  }) async {
    final data = await _buildBackupData(auth: auth, isDark: isDark, type: type);
    final json = jsonEncode(data.toJson());
    final now = DateTime.now();
    final stamp =
        '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final fname = type == BackupExportType.full
        ? 'markfit_backup_$stamp.json'
        : 'markfit_struttura_schede_$stamp.json';
    await downloadJsonFile(json, fname);
  }

  // ── IMPORT ────────────────────────────────────────────────
  /// Legge un file JSON dal disco e lo valida INTEGRALMENTE prima
  /// di ritornare. Nessuna scrittura su Hive avviene in questo
  /// metodo. Restituisce BackupData oppure lancia
  /// [BackupValidationError] con un motivo leggibile.
  Future<BackupData?> pickAndParse() async {
    final raw = await pickJsonFile();
    if (raw == null) return null;
    return _parse(raw);
  }

  /// Esegue l'import dal [data] già validato. Se [data.exportType]
  /// è 'structure', l'operazione è ADDITIVA (Parte 39/43): non
  /// cancella né sovrascrive nulla, non tocca storico/obiettivi/
  /// profilo. Se è 'full', l'operazione sostituisce integralmente
  /// i dati correnti dell'utente (comportamento invariato rispetto
  /// alle versioni precedenti, ora esteso alle modalità).
  Future<void> restoreBackup(BackupData data) async {
    if (data.isStructureOnly) {
      await _importStructureAdditive(data);
    } else {
      await _clearCurrentUserData();
      await _importFullData(data);
    }
  }

  // ── PRIVATE: build ────────────────────────────────────────
  Future<BackupData> _buildBackupData({
    required AuthProvider auth,
    required bool isDark,
    required BackupExportType type,
  }) async {
    final hdb = HiveDatabase.instance;
    final gdb = GoalDatabase.instance;
    final tmdb = TrainingModeDatabase.instance;

    final workouts = hdb.getWorkouts();
    final allWE = <Map<String, dynamic>>[];
    final allCir = <Map<String, dynamic>>[];
    final referencedModeKeys = <dynamic>{};
    final referencedExerciseKeys = <dynamic>{};

    for (final w in workouts) {
      for (final we in hdb.getWorkoutExercises(w.key)) {
        allWE.add(_serializeWE(we));
        if (we.trainingModeKey != null) {
          referencedModeKeys.add(we.trainingModeKey);
        }
        referencedExerciseKeys.add(we.exerciseKey);
      }
      for (final c in hdb.getCircuits(w.key)) {
        allCir.add(_serializeCircuit(c));
      }
    }

    List<Map<String, dynamic>> sessionsOut = [];
    List<Map<String, dynamic>> setsOut = [];
    List<Map<String, dynamic>> notesOut = [];
    List<Map<String, dynamic>> goalsOut = [];
    List<Map<String, dynamic>> completionsOut = [];
    List<Map<String, dynamic>> sportOut = [];
    Map<String, dynamic>? profileOut;
    List<Map<String, dynamic>> modesOut;
    List<Map<String, dynamic>> exercisesOut;

    if (type == BackupExportType.full) {
      final sessionsList = hdb.getSessions();
      sessionsOut = sessionsList.map(_serializeSession).toList();
      for (final s in sessionsList) {
        for (final ss in hdb.getSessionSets(s.key)) {
          setsOut.add(_serializeSet(ss));
          if (ss.trainingModeKey != null) {
            referencedModeKeys.add(ss.trainingModeKey);
          }
          referencedExerciseKeys.add(ss.exerciseKey);
        }
      }
      final customExercises =
          hdb.getExercises().where((e) => e.isCustom).toList();
      final customKeys = customExercises.map((e) => e.key as int).toList();
      final notesMap = hdb.getExerciseNotes(customKeys);
      notesOut = notesMap.entries
          .map((e) => {'exerciseKey': e.key, 'note': e.value})
          .toList();

      final goals = gdb.getGoals();
      goalsOut = goals.map(_serializeGoal).toList();
      for (final g in goals) {
        for (final c in gdb.getCompletionsForGoal(g.key)) {
          completionsOut.add(
              {'goalKey': g.key, 'date': c.date, 'completed': c.completed});
        }
      }
      sportOut =
          SportDatabase.instance.getSessions().map(_serializeSportSession).toList();
      profileOut = _serializeProfile(auth);
      // FULL: tutte le modalità, incluse quelle soft-eliminate, per
      // coerenza con i riferimenti storici delle sessioni esportate
      // (Parte 34/50: lo storico deve rimanere ricostruibile).
      modesOut = tmdb.getAll().map(_serializeMode).toList();
      exercisesOut = customExercises.map(_serializeExercise).toList();
    } else {
      // STRUTTURA: solo esercizi/modalità EFFETTIVAMENTE referenziati
      // dalle schede esportate (Parte 41/43) — mai storico, mai profilo.
      modesOut = tmdb
          .getAll()
          .where((m) => referencedModeKeys.contains(m.key))
          .map(_serializeMode)
          .toList();
      exercisesOut = hdb
          .getExercises()
          .where((e) => e.isCustom && referencedExerciseKeys.contains(e.key))
          .map(_serializeExercise)
          .toList();
    }

    return BackupData(
      version: _kVersion,
      schemaVersion: _kSchemaVersion,
      exportType: type == BackupExportType.full ? 'full' : 'structure',
      exportedAt: DateTime.now().toIso8601String(),
      userId: hdb.currentUserId,
      profile: profileOut,
      exercises: exercisesOut,
      workouts: workouts.map(_serializeWorkout).toList(),
      workoutExercises: allWE,
      circuits: allCir,
      trainingModes: modesOut,
      sessions: sessionsOut,
      sessionSets: setsOut,
      exerciseNotes: notesOut,
      goals: goalsOut,
      goalCompletions: completionsOut,
      sportSessions: sportOut,
      preferences: type == BackupExportType.full ? {'isDark': isDark} : {},
    );
  }

  // ── PRIVATE: serialize ────────────────────────────────────
  Map<String, dynamic> _serializeProfile(AuthProvider auth) {
    final a = auth.currentAccount;
    if (a == null) return {};
    return {
      'identifier': a.identifier,
      'displayName': a.displayName,
      'firstName': a.firstName,
      'lastName': a.lastName,
      'birthDate': a.birthDate,
      'birthPlace': a.birthPlace,
      'phone': a.phone,
      'bio': a.bio,
      // avatar non incluso — file reference sarebbe invalido tra installazioni
    };
  }

  Map<String, dynamic> _serializeExercise(HiveExercise e) => {
        'id': e.key,
        'name': e.name,
        'muscleGroup': e.muscleGroup,
        'notes': e.notes,
        'isCustom': e.isCustom,
      };

  Map<String, dynamic> _serializeWorkout(HiveWorkout w) => {
        'id': w.key,
        'name': w.name,
        'createdAt': w.createdAt,
        'iconId': w.iconId,
        'iconColorIndex': w.iconColorIndex,
      };

  Map<String, dynamic> _serializeWE(HiveWorkoutExercise we) => {
        'workoutKey': we.workoutKey,
        'exerciseKey': we.exerciseKey,
        'exerciseName': we.exerciseName,
        'muscleGroup': we.muscleGroup,
        'sets': we.sets,
        'targetReps': we.targetReps,
        'targetWeight': we.targetWeight,
        'restSeconds': we.restSeconds,
        'notes': we.notes,
        'sortOrder': we.sortOrder,
        'trainingModeKey': we.trainingModeKey,
      };

  Map<String, dynamic> _serializeCircuit(HiveCircuit c) => {
        'workoutKey': c.workoutKey,
        'name': c.name,
        'rounds': c.rounds,
        'sortOrder': c.sortOrder,
      };

  Map<String, dynamic> _serializeMode(TrainingMode m) => {
        'id': m.key,
        'name': m.name,
        'category': m.category,
        'createdAt': m.createdAt,
        'updatedAt': m.updatedAt,
        'isDeleted': m.isDeleted,
        'isDefault': m.isDefault,
        'origin': m.origin,
        'sets': m.orderedSets
            .map((s) => {
                  'order': s.order,
                  'fixedReps': s.fixedReps,
                  'minReps': s.minReps,
                  'maxReps': s.maxReps,
                })
            .toList(),
      };

  Map<String, dynamic> _serializeSession(HiveSession s) => {
        'id': s.key,
        'workoutKey': s.workoutKey,
        'workoutName': s.workoutName,
        'date': s.date,
        'durationSeconds': s.durationSeconds,
      };

  Map<String, dynamic> _serializeSet(HiveSessionSet ss) => {
        'sessionKey': ss.sessionKey,
        'exerciseKey': ss.exerciseKey,
        'exerciseName': ss.exerciseName,
        'muscleGroup': ss.muscleGroup,
        'setNumber': ss.setNumber,
        'weight': ss.weight,
        'reps': ss.reps,
        'completed': ss.completed,
        'restSeconds': ss.restSeconds,
        'trainingModeKey': ss.trainingModeKey,
        'executionStatus': ss.executionStatus,
      };

  Map<String, dynamic> _serializeGoal(HiveGoal g) => {
        'id': g.key,
        'title': g.title,
        'description': g.description,
        'category': g.category,
        'createdAt': g.createdAt,
        'scheduleType': g.scheduleType,
        'scheduleDaysOfWeek': g.scheduleDaysOfWeek,
        'scheduleStartDate': g.scheduleStartDate,
        'scheduleEndDate': g.scheduleEndDate,
        'scheduleCustomInterval': g.scheduleCustomInterval,
        'status': g.status,
        'currentStreak': g.currentStreak,
        'bestStreak': g.bestStreak,
        'deadlineDate': g.deadlineDate,
        'colorIndex': g.colorIndex,
      };

  Map<String, dynamic> _serializeSportSession(HiveSportSession s) => {
        'sportType': s.sportType,
        'date': s.date,
        'durationSeconds': s.durationSeconds,
        'distanceKm': s.distanceKm,
        'notes': s.notes,
      };

  // ── PRIVATE: parse & validate ─────────────────────────────
  BackupData _parse(String raw) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw BackupValidationError('Il file non è un JSON valido o è corrotto.');
    }

    _require(json, 'app');
    if (json['app'] != 'MarkFit') {
      throw BackupValidationError(
          'Il file non è un backup MarkFit (formato non supportato).');
    }

    final schemaVersion = (json['schemaVersion'] as num?)?.toInt() ?? 1;
    if (schemaVersion < 1 || schemaVersion > _kSchemaVersion) {
      throw BackupValidationError(
          'Versione schema dati (v$schemaVersion) non compatibile con questa '
          'versione di MarkFit (supportate: v1–v$_kSchemaVersion). '
          'Aggiorna l\'app per importare questo file.');
    }

    final exportType = json['exportType'] as String? ?? 'full';
    if (exportType != 'full' && exportType != 'structure') {
      throw BackupValidationError(
          'Tipo di export "$exportType" non riconosciuto.');
    }

    _require(json, 'sessions');
    _require(json, 'workouts');
    _require(json, 'exercises');

    _validateList(json, 'workoutExercises', requiredKeys: const [
      'workoutKey',
      'exerciseKey',
      'exerciseName',
      'muscleGroup',
    ]);
    _validateList(json, 'trainingModes',
        requiredKeys: const ['name', 'category', 'sets']);

    return BackupData(
      version: json['version'] as String? ?? '1.0.0',
      schemaVersion: schemaVersion,
      exportType: exportType,
      exportedAt: json['exportedAt'] as String? ?? '',
      userId: json['userId'] as String? ?? '',
      profile: json['profile'] as Map<String, dynamic>?,
      exercises: _listOf(json, 'exercises'),
      workouts: _listOf(json, 'workouts'),
      workoutExercises: _listOf(json, 'workoutExercises'),
      circuits: _listOf(json, 'circuits'),
      trainingModes: _listOf(json, 'trainingModes'),
      sessions: _listOf(json, 'sessions'),
      sessionSets: _listOf(json, 'sessionSets'),
      exerciseNotes: _listOf(json, 'exerciseNotes'),
      goals: _listOf(json, 'goals'),
      goalCompletions: _listOf(json, 'goalCompletions'),
      sportSessions: _listOf(json, 'sportSessions'),
      preferences: json['preferences'] as Map<String, dynamic>? ?? {},
    );
  }

  void _require(Map<String, dynamic> m, String key) {
    if (!m.containsKey(key)) {
      throw BackupValidationError('Campo obbligatorio mancante: "$key".');
    }
  }

  /// Valida in modo fail-fast la lista [key]: se un elemento manca di
  /// un campo obbligatorio, o (per le modalità) ha una struttura di
  /// serie non valida, l'intera importazione viene bloccata PRIMA
  /// che qualsiasi dato venga scritto su Hive (Parte 39/40).
  void _validateList(Map<String, dynamic> json, String key,
      {required List<String> requiredKeys}) {
    final raw = json[key];
    if (raw == null) return; // campo assente → lista vuota, consentito
    if (raw is! List) {
      throw BackupValidationError(
          'Il campo "$key" ha un formato non valido (attesa una lista).');
    }
    for (final item in raw) {
      if (item is! Map) {
        throw BackupValidationError('Elemento non valido in "$key".');
      }
      for (final rk in requiredKeys) {
        if (!item.containsKey(rk)) {
          throw BackupValidationError(
              'Campo obbligatorio "$rk" mancante in "$key".');
        }
      }
      if (key == 'trainingModes') {
        final sets = item['sets'];
        if (sets is! List || sets.isEmpty) {
          throw BackupValidationError(
              'Modalità "${item['name']}" senza serie valide.');
        }
        for (final s in sets) {
          if (s is! Map || !s.containsKey('order')) {
            throw BackupValidationError(
                'Struttura serie non valida nella modalità "${item['name']}".');
          }
          final hasFixed = s['fixedReps'] != null;
          final hasRange = s['minReps'] != null && s['maxReps'] != null;
          if (!hasFixed && !hasRange) {
            throw BackupValidationError(
                'Serie senza reps valide nella modalità "${item['name']}".');
          }
        }
      }
    }
  }

  List<Map<String, dynamic>> _listOf(Map<String, dynamic> m, String key) {
    final raw = m[key];
    if (raw == null) return [];
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  // ── PRIVATE: clear (solo restore FULL) ────────────────────
  Future<void> _clearCurrentUserData() async {
    final hdb = HiveDatabase.instance;
    final gdb = GoalDatabase.instance;
    final sdb = SportDatabase.instance;

    await hdb.deleteAllSessions();
    await hdb.deleteAllNotes();

    final workouts = hdb.getWorkouts();
    for (final w in workouts) {
      await hdb.deleteWorkout(w.key);
    }

    final exercises = hdb.getExercises();
    for (final e in exercises.where((e) => e.isCustom)) {
      await hdb.deleteExercise(e.key);
    }

    final goals = gdb.getGoals();
    for (final g in goals) {
      await gdb.deleteGoal(g.key);
    }

    final sportSessions = sdb.getSessions();
    for (final s in sportSessions) {
      await sdb.deleteSession(s.key);
    }

    await TrainingModeDatabase.instance.clearAllForImport();
  }

  // ── PRIVATE: resolver condivisi (full + structure) ────────

  /// Trova un esercizio esistente (custom o predefinito) per NOME
  /// (case-insensitive), altrimenti lo crea come custom. Questo è
  /// ciò che rende possibile trasferire una scheda che usa esercizi
  /// STANDARD (non solo custom) tra installazioni diverse: la
  /// exerciseKey numerica non è portabile, ma il nome sì.
  Future<int> _getOrCreateExercise({
    required String name,
    required String muscleGroup,
    String? notes,
    required List<HiveExercise> cache,
    void Function(int)? rememberKey,
  }) async {
    try {
      final match = cache.firstWhere(
          (e) => e.name.trim().toLowerCase() == name.trim().toLowerCase());
      final key = match.key as int;
      rememberKey?.call(key);
      return key;
    } catch (_) {
      final created = HiveExercise(
          name: name, muscleGroup: muscleGroup, notes: notes, isCustom: true);
      await HiveDatabase.instance.addExercise(created);
      cache.add(created);
      final key = created.key as int;
      rememberKey?.call(key);
      return key;
    }
  }

  String _modeSignature(
      String name, String category, List<Map<String, dynamic>> sets) {
    final setsSig = sets
        .map((s) =>
            '${s['order']}:${s['fixedReps']}:${s['minReps']}:${s['maxReps']}')
        .join(',');
    return '${name.trim().toLowerCase()}|${category.trim().toLowerCase()}|$setsSig';
  }

  String _modeSignatureFor(TrainingMode m) => _modeSignature(
      m.name,
      m.category,
      m.orderedSets
          .map((s) => {
                'order': s.order,
                'fixedReps': s.fixedReps,
                'minReps': s.minReps,
                'maxReps': s.maxReps,
              })
          .toList());

  // ── PRIVATE: import FULL (distruttivo, restore completo) ──
  Future<void> _importFullData(BackupData data) async {
    final hdb = HiveDatabase.instance;
    final gdb = GoalDatabase.instance;
    final tmdb = TrainingModeDatabase.instance;
    final uid = hdb.currentUserId;

    final exerciseCache = hdb.getExercises();
    final exKeyMap = <int, int>{};
    final woKeyMap = <int, int>{};
    final sesKeyMap = <int, int>{};
    final goalKeyMap = <int, int>{};
    final modeKeyMap = <int, int>{};

    // 1. Esercizi custom esplicitamente esportati (dedup per nome)
    for (final e in data.exercises) {
      final oldId = (e['id'] as num).toInt();
      final newKey = await _getOrCreateExercise(
          name: e['name'] as String,
          muscleGroup: e['muscleGroup'] as String,
          notes: e['notes'] as String?,
          cache: exerciseCache);
      exKeyMap[oldId] = newKey;
    }

    // 2. Modalità di allenamento — restore 1:1 (Parte 12/34/50: lo
    //    storico deve poter risolvere esattamente la modalità storica
    //    originale, incluse quelle soft-eliminate).
    int? originalDefaultNewKey;
    for (final m in data.trainingModes) {
      final oldId = (m['id'] as num).toInt();
      final setsJson = (m['sets'] as List).cast<Map<String, dynamic>>();
      final mode = TrainingMode(
        name: m['name'] as String,
        category: m['category'] as String,
        createdAt:
            m['createdAt'] as String? ?? DateTime.now().toIso8601String(),
        updatedAt: m['updatedAt'] as String?,
        isDeleted: m['isDeleted'] as bool? ?? false,
        isDefault: false, // impostato in blocco più sotto, mai durante il loop
        origin: m['origin'] as String? ?? 'custom',
        sets: setsJson
            .map((s) => TrainingModeSet(
                  order: (s['order'] as num).toInt(),
                  fixedReps: (s['fixedReps'] as num?)?.toInt(),
                  minReps: (s['minReps'] as num?)?.toInt(),
                  maxReps: (s['maxReps'] as num?)?.toInt(),
                ))
            .toList(),
      );
      final newKey = await tmdb.add(mode) as int;
      modeKeyMap[oldId] = newKey;
      if (m['isDefault'] == true) originalDefaultNewKey = newKey;
    }
    if (originalDefaultNewKey != null) {
      await tmdb.setDefault(originalDefaultNewKey);
    } else {
      await tmdb.finalizeAfterImport();
    }
    // Backup legacy senza alcuna modalità esportata: ripristina il
    // catalogo predefinito standard invece di lasciare l'utente senza.
    await tmdb.reseedIfEmptyAfterImport();

    // 3. Workouts
    for (final w in data.workouts) {
      final oldId = (w['id'] as num).toInt();
      final obj = HiveWorkout(
        name: w['name'] as String,
        createdAt: w['createdAt'] as String,
        iconId: w['iconId'] as String?,
        iconColorIndex: w['iconColorIndex'] as int?,
      );
      final newKey = await hdb.addWorkout(obj);
      woKeyMap[oldId] = newKey;
    }

    // 4. WorkoutExercises
    for (final we in data.workoutExercises) {
      final oldWoKey = (we['workoutKey'] as num).toInt();
      final oldExKey = (we['exerciseKey'] as num).toInt();
      final newExKey = exKeyMap[oldExKey] ??
          await _getOrCreateExercise(
              name: we['exerciseName'] as String,
              muscleGroup: we['muscleGroup'] as String,
              cache: exerciseCache,
              rememberKey: (k) => exKeyMap[oldExKey] = k);
      final oldModeKey = (we['trainingModeKey'] as num?)?.toInt();
      final newModeKey = oldModeKey != null ? modeKeyMap[oldModeKey] : null;
      final obj = HiveWorkoutExercise(
        workoutKey: woKeyMap[oldWoKey] ?? oldWoKey,
        exerciseKey: newExKey,
        exerciseName: we['exerciseName'] as String,
        muscleGroup: we['muscleGroup'] as String,
        sets: (we['sets'] as num?)?.toInt() ?? 3,
        targetReps: (we['targetReps'] as num?)?.toInt() ?? 8,
        targetWeight: (we['targetWeight'] as num?)?.toDouble(),
        restSeconds: (we['restSeconds'] as num?)?.toInt(),
        notes: we['notes'] as String?,
        sortOrder: (we['sortOrder'] as num?)?.toInt() ?? 0,
        trainingModeKey: newModeKey,
      );
      await hdb.addWorkoutExercise(obj);
    }

    // 5. Circuits
    for (final c in data.circuits) {
      final oldWoKey = (c['workoutKey'] as num).toInt();
      final obj = HiveCircuit(
        workoutKey: woKeyMap[oldWoKey] ?? oldWoKey,
        name: c['name'] as String,
        rounds: (c['rounds'] as num?)?.toInt() ?? 3,
        sortOrder: (c['sortOrder'] as num?)?.toInt() ?? 0,
      );
      await hdb.addCircuit(obj);
    }

    // 6. Sessions — accesso diretto al box (createSession imposta date = now)
    final sesBoxName = '${uid}_sessions';
    final sesBox = Hive.box<HiveSession>(sesBoxName);
    for (final s in data.sessions) {
      final oldId = (s['id'] as num).toInt();
      final oldWoKey = (s['workoutKey'] as num).toInt();
      final obj = HiveSession(
        workoutKey: woKeyMap[oldWoKey] ?? oldWoKey,
        workoutName: s['workoutName'] as String,
        date: s['date'] as String,
        durationSeconds: (s['durationSeconds'] as num?)?.toInt(),
      );
      final newKey = await sesBox.add(obj);
      sesKeyMap[oldId] = newKey;
    }

    // 7. Session sets
    for (final ss in data.sessionSets) {
      final oldSesKey = (ss['sessionKey'] as num).toInt();
      final oldExKey = (ss['exerciseKey'] as num).toInt();
      final newExKey = exKeyMap[oldExKey] ??
          await _getOrCreateExercise(
              name: ss['exerciseName'] as String,
              muscleGroup: ss['muscleGroup'] as String,
              cache: exerciseCache,
              rememberKey: (k) => exKeyMap[oldExKey] = k);
      final oldModeKey = (ss['trainingModeKey'] as num?)?.toInt();
      final newModeKey = oldModeKey != null ? modeKeyMap[oldModeKey] : null;
      final obj = HiveSessionSet(
        sessionKey: sesKeyMap[oldSesKey] ?? oldSesKey,
        exerciseKey: newExKey,
        exerciseName: ss['exerciseName'] as String,
        muscleGroup: ss['muscleGroup'] as String,
        setNumber: (ss['setNumber'] as num).toInt(),
        weight: (ss['weight'] as num).toDouble(),
        reps: (ss['reps'] as num).toInt(),
        completed: ss['completed'] as bool? ?? false,
        restSeconds: (ss['restSeconds'] as num?)?.toInt(),
        trainingModeKey: newModeKey,
        executionStatus: ss['executionStatus'] as String?,
      );
      await hdb.addSessionSet(obj);
    }

    // 8. Exercise notes
    for (final n in data.exerciseNotes) {
      final oldKey = (n['exerciseKey'] as num).toInt();
      final newKey = exKeyMap[oldKey] ?? oldKey;
      final note = n['note'] as String? ?? '';
      if (note.isNotEmpty) {
        await hdb.saveExerciseNote(newKey, note);
      }
    }

    // 9. Goals
    for (final g in data.goals) {
      final oldId = (g['id'] as num).toInt();
      final daysRaw = g['scheduleDaysOfWeek'];
      final days = daysRaw is List
          ? daysRaw.whereType<num>().map((e) => e.toInt()).toList()
          : <int>[];
      final newKey = await gdb.addGoal(HiveGoal(
        title: g['title'] as String,
        description: g['description'] as String?,
        category: g['category'] as String,
        createdAt: g['createdAt'] as String,
        scheduleType: g['scheduleType'] as String,
        scheduleDaysOfWeek: days.isEmpty ? null : days,
        scheduleStartDate: g['scheduleStartDate'] as String?,
        scheduleEndDate: g['scheduleEndDate'] as String?,
        scheduleCustomInterval: (g['scheduleCustomInterval'] as num?)?.toInt(),
        status: g['status'] as String? ?? 'active',
        currentStreak: (g['currentStreak'] as num?)?.toInt() ?? 0,
        bestStreak: (g['bestStreak'] as num?)?.toInt() ?? 0,
        deadlineDate: g['deadlineDate'] as String?,
        colorIndex: (g['colorIndex'] as num?)?.toInt() ?? 0,
      ));
      goalKeyMap[oldId] = newKey as int;
    }

    // 10. Goal completions
    for (final c in data.goalCompletions) {
      final oldGoalKey = (c['goalKey'] as num).toInt();
      final newGoalKey = goalKeyMap[oldGoalKey] ?? oldGoalKey;
      await gdb.setCompletion(
          newGoalKey, c['date'] as String, c['completed'] as bool? ?? false);
    }

    // 11. Sport sessions — accesso diretto al box
    final sportBoxName = '${uid}_sport_sessions';
    if (Hive.isBoxOpen(sportBoxName)) {
      final sportBox = Hive.box<HiveSportSession>(sportBoxName);
      for (final s in data.sportSessions) {
        await sportBox.add(HiveSportSession(
          sportType: s['sportType'] as String,
          date: s['date'] as String,
          durationSeconds: (s['durationSeconds'] as num).toInt(),
          distanceKm: (s['distanceKm'] as num?)?.toDouble(),
          notes: s['notes'] as String?,
        ));
      }
    }
  }

  // ── PRIVATE: import STRUCTURE (additivo, non distruttivo) ─
  Future<void> _importStructureAdditive(BackupData data) async {
    final hdb = HiveDatabase.instance;
    final tmdb = TrainingModeDatabase.instance;

    final exerciseCache = hdb.getExercises();
    final exKeyMap = <int, int>{};
    for (final e in data.exercises) {
      final oldId = (e['id'] as num).toInt();
      final newKey = await _getOrCreateExercise(
          name: e['name'] as String,
          muscleGroup: e['muscleGroup'] as String,
          notes: e['notes'] as String?,
          cache: exerciseCache);
      exKeyMap[oldId] = newKey;
    }

    // Modalità: dedup per struttura EQUIVALENTE (nome+categoria+serie).
    // Il flag isDefault del file di origine viene SEMPRE ignorato: il
    // default dell'utente che importa non deve mai essere alterato da
    // una struttura condivisa (Parte 43: nessun effetto collaterale
    // sulle preferenze dell'utente ricevente).
    final modeCache = tmdb.getAvailable();
    final modeKeyMap = <int, int>{};
    for (final m in data.trainingModes) {
      final oldId = (m['id'] as num).toInt();
      final setsJson = (m['sets'] as List).cast<Map<String, dynamic>>();
      final sig =
          _modeSignature(m['name'] as String, m['category'] as String, setsJson);
      int newKey;
      try {
        final match =
            modeCache.firstWhere((mode) => _modeSignatureFor(mode) == sig);
        newKey = match.key as int;
      } catch (_) {
        final mode = TrainingMode(
          name: m['name'] as String,
          category: m['category'] as String,
          createdAt: DateTime.now().toIso8601String(),
          isDeleted: false,
          isDefault: false,
          origin: 'custom',
          sets: setsJson
              .map((s) => TrainingModeSet(
                    order: (s['order'] as num).toInt(),
                    fixedReps: (s['fixedReps'] as num?)?.toInt(),
                    minReps: (s['minReps'] as num?)?.toInt(),
                    maxReps: (s['maxReps'] as num?)?.toInt(),
                  ))
              .toList(),
        );
        newKey = await tmdb.add(mode) as int;
        modeCache.add(mode);
      }
      modeKeyMap[oldId] = newKey;
    }

    // Workouts: SEMPRE creati come nuove voci (anche a fronte di nomi
    // uguali a schede già presenti) — è il comportamento corretto per
    // "condividi la mia scheda con un altro utente" (Parte 34/43).
    final woKeyMap = <int, int>{};
    for (final w in data.workouts) {
      final oldId = (w['id'] as num).toInt();
      final obj = HiveWorkout(
        name: w['name'] as String,
        createdAt: DateTime.now().toIso8601String(),
        iconId: w['iconId'] as String?,
        iconColorIndex: w['iconColorIndex'] as int?,
      );
      final newKey = await hdb.addWorkout(obj);
      woKeyMap[oldId] = newKey;
    }

    for (final we in data.workoutExercises) {
      final oldWoKey = (we['workoutKey'] as num).toInt();
      if (!woKeyMap.containsKey(oldWoKey)) continue; // riga orfana, ignorata
      final oldExKey = (we['exerciseKey'] as num).toInt();
      final newExKey = exKeyMap[oldExKey] ??
          await _getOrCreateExercise(
              name: we['exerciseName'] as String,
              muscleGroup: we['muscleGroup'] as String,
              cache: exerciseCache,
              rememberKey: (k) => exKeyMap[oldExKey] = k);
      final oldModeKey = (we['trainingModeKey'] as num?)?.toInt();
      final newModeKey = oldModeKey != null ? modeKeyMap[oldModeKey] : null;
      final obj = HiveWorkoutExercise(
        workoutKey: woKeyMap[oldWoKey]!,
        exerciseKey: newExKey,
        exerciseName: we['exerciseName'] as String,
        muscleGroup: we['muscleGroup'] as String,
        sets: (we['sets'] as num?)?.toInt() ?? 3,
        targetReps: (we['targetReps'] as num?)?.toInt() ?? 8,
        targetWeight: (we['targetWeight'] as num?)?.toDouble(),
        restSeconds: (we['restSeconds'] as num?)?.toInt(),
        notes: we['notes'] as String?,
        sortOrder: (we['sortOrder'] as num?)?.toInt() ?? 0,
        trainingModeKey: newModeKey,
      );
      await hdb.addWorkoutExercise(obj);
    }

    for (final c in data.circuits) {
      final oldWoKey = (c['workoutKey'] as num).toInt();
      if (!woKeyMap.containsKey(oldWoKey)) continue;
      final obj = HiveCircuit(
        workoutKey: woKeyMap[oldWoKey]!,
        name: c['name'] as String,
        rounds: (c['rounds'] as num?)?.toInt() ?? 3,
        sortOrder: (c['sortOrder'] as num?)?.toInt() ?? 0,
      );
      await hdb.addCircuit(obj);
    }

    // Storico, obiettivi, profilo, sport: MAI toccati in un import
    // "struttura" — anche se per qualche motivo il file ne contenesse
    // (dati ignorati per contratto, Parte 43).
  }
}

// ─────────────────────────────────────────────────────────────
// BackupValidationError
// ─────────────────────────────────────────────────────────────
class BackupValidationError implements Exception {
  final String message;
  const BackupValidationError(this.message);
  @override
  String toString() => message;
}