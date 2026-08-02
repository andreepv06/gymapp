import 'dart:convert';
import 'dart:math' as math;

import 'package:hive/hive.dart';

import '../db/goal_database.dart';
import '../db/hive_database.dart';
import '../db/sport_database.dart';
import '../models/goal_models.dart';
import '../models/hive_models.dart';
import '../models/sport_models.dart';
import '../providers/auth_provider.dart';
import 'backup_file.dart';

// ─────────────────────────────────────────────────────────────
// BackupData — struttura intermedia del backup
// ─────────────────────────────────────────────────────────────

class BackupData {
  final String version;
  final String exportedAt;
  final String userId;
  final Map<String, dynamic>? profile;
  final List<Map<String, dynamic>> exercises;
  final List<Map<String, dynamic>> workouts;
  final List<Map<String, dynamic>> workoutExercises;
  final List<Map<String, dynamic>> circuits;
  final List<Map<String, dynamic>> sessions;
  final List<Map<String, dynamic>> sessionSets;
  final List<Map<String, dynamic>> exerciseNotes;
  final List<Map<String, dynamic>> goals;
  final List<Map<String, dynamic>> goalCompletions;
  final List<Map<String, dynamic>> sportSessions;
  final Map<String, dynamic> preferences;

  const BackupData({
    required this.version,
    required this.exportedAt,
    required this.userId,
    required this.profile,
    required this.exercises,
    required this.workouts,
    required this.workoutExercises,
    required this.circuits,
    required this.sessions,
    required this.sessionSets,
    required this.exerciseNotes,
    required this.goals,
    required this.goalCompletions,
    required this.sportSessions,
    required this.preferences,
  });

  Map<String, dynamic> toJson() => {
    'version':          version,
    'app':              'MarkFit',
    'exportedAt':       exportedAt,
    'userId':           userId,
    'profile':          profile,
    'exercises':        exercises,
    'workouts':         workouts,
    'workoutExercises': workoutExercises,
    'circuits':         circuits,
    'sessions':         sessions,
    'sessionSets':      sessionSets,
    'exerciseNotes':    exerciseNotes,
    'goals':            goals,
    'goalCompletions':  goalCompletions,
    'sportSessions':    sportSessions,
    'preferences':      preferences,
  };
}

// ─────────────────────────────────────────────────────────────
// BackupService
// ─────────────────────────────────────────────────────────────

class BackupService {
  BackupService._();
  static final instance = BackupService._();

  static const _kVersion = '1.0.0';

  // ── EXPORT ────────────────────────────────────────────────

  Future<void> exportBackup({
    required AuthProvider auth,
    required bool isDark,
  }) async {
    final data = await _buildBackupData(auth: auth, isDark: isDark);
    final json = jsonEncode(data.toJson());
    final now  = DateTime.now();
    final fname =
        'markfit_backup_${now.year}${now.month.toString().padLeft(2,'0')}${now.day.toString().padLeft(2,'0')}.json';
    await downloadJsonFile(json, fname);
  }

  // ── IMPORT ────────────────────────────────────────────────

  /// Legge un file JSON dal disco e lo valida.
  /// Restituisce BackupData oppure lancia [BackupValidationError].
  Future<BackupData?> pickAndParse() async {
    final raw = await pickJsonFile();
    if (raw == null) return null;
    return _parse(raw);
  }

  /// Esegue il restore completo dal [data] validato.
  Future<void> restoreBackup(BackupData data) async {
    await _clearCurrentUserData();
    await _importData(data);
  }

  // ── PRIVATE: build ────────────────────────────────────────

  Future<BackupData> _buildBackupData({
    required AuthProvider auth,
    required bool isDark,
  }) async {
    final hdb  = HiveDatabase.instance;
    final gdb  = GoalDatabase.instance;

    final workouts = hdb.getWorkouts();
    final sessions = hdb.getSessions();
    final goals    = gdb.getGoals();

    // WorkoutExercises + Circuits per workout
    final allWE  = <Map<String, dynamic>>[];
    final allCir = <Map<String, dynamic>>[];
    for (final w in workouts) {
      for (final we in hdb.getWorkoutExercises(w.key)) {
        allWE.add(_serializeWE(we));
      }
      for (final c in hdb.getCircuits(w.key)) {
        allCir.add(_serializeCircuit(c));
      }
    }

    // SessionSets per sessione
    final allSets = <Map<String, dynamic>>[];
    for (final s in sessions) {
      for (final ss in hdb.getSessionSets(s.key)) {
        allSets.add(_serializeSet(ss));
      }
    }

    // ExerciseNotes (solo custom exercises hanno note rilevanti)
    final customExercises = hdb.getExercises().where((e) => e.isCustom).toList();
    final customKeys = customExercises.map((e) => e.key as int).toList();
    final notesMap   = hdb.getExerciseNotes(customKeys);
    final allNotes   = notesMap.entries.map((e) => {
      'exerciseKey': e.key,
      'note':        e.value,
    }).toList();

    // GoalCompletions per goal
    final allCompletions = <Map<String, dynamic>>[];
    for (final g in goals) {
      for (final c in gdb.getCompletionsForGoal(g.key)) {
        allCompletions.add({
          'goalKey':   g.key,
          'date':      c.date,
          'completed': c.completed,
        });
      }
    }

    // Sport sessions
    final sportSessions = SportDatabase.instance.getSessions();

    return BackupData(
      version:    _kVersion,
      exportedAt: DateTime.now().toIso8601String(),
      userId:     hdb.currentUserId,
      profile:    _serializeProfile(auth),
      exercises:  customExercises.map(_serializeExercise).toList(),
      workouts:   workouts.map(_serializeWorkout).toList(),
      workoutExercises: allWE,
      circuits:   allCir,
      sessions:   sessions.map(_serializeSession).toList(),
      sessionSets: allSets,
      exerciseNotes: allNotes,
      goals:      goals.map(_serializeGoal).toList(),
      goalCompletions: allCompletions,
      sportSessions: sportSessions.map(_serializeSportSession).toList(),
      preferences: {'isDark': isDark},
    );
  }

  // ── PRIVATE: serialize ────────────────────────────────────

  Map<String, dynamic> _serializeProfile(AuthProvider auth) {
    final a = auth.currentAccount;
    if (a == null) return {};
    return {
      'identifier':  a.identifier,
      'displayName': a.displayName,
      'firstName':   a.firstName,
      'lastName':    a.lastName,
      'birthDate':   a.birthDate,
      'birthPlace':  a.birthPlace,
      'phone':       a.phone,
      'bio':         a.bio,
      // avatar not included — file reference would be invalid
    };
  }

  Map<String, dynamic> _serializeExercise(HiveExercise e) => {
    'id':          e.key,
    'name':        e.name,
    'muscleGroup': e.muscleGroup,
    'notes':       e.notes,
    'isCustom':    e.isCustom,
  };

  Map<String, dynamic> _serializeWorkout(HiveWorkout w) => {
    'id':             w.key,
    'name':           w.name,
    'createdAt':      w.createdAt,
    'iconId':         w.iconId,
    'iconColorIndex': w.iconColorIndex,
  };

  Map<String, dynamic> _serializeWE(HiveWorkoutExercise we) => {
    'workoutKey':    we.workoutKey,
    'exerciseKey':   we.exerciseKey,
    'exerciseName':  we.exerciseName,
    'muscleGroup':   we.muscleGroup,
    'sets':          we.sets,
    'targetReps':    we.targetReps,
    'targetWeight':  we.targetWeight,
    'restSeconds':   we.restSeconds,
    'notes':         we.notes,
    'sortOrder':     we.sortOrder,
  };

  Map<String, dynamic> _serializeCircuit(HiveCircuit c) => {
    'workoutKey': c.workoutKey,
    'name':       c.name,
    'rounds':     c.rounds,
    'sortOrder':  c.sortOrder,
  };

  Map<String, dynamic> _serializeSession(HiveSession s) => {
    'id':              s.key,
    'workoutKey':      s.workoutKey,
    'workoutName':     s.workoutName,
    'date':            s.date,
    'durationSeconds': s.durationSeconds,
  };

  Map<String, dynamic> _serializeSet(HiveSessionSet ss) => {
    'sessionKey':   ss.sessionKey,
    'exerciseKey':  ss.exerciseKey,
    'exerciseName': ss.exerciseName,
    'muscleGroup':  ss.muscleGroup,
    'setNumber':    ss.setNumber,
    'weight':       ss.weight,
    'reps':         ss.reps,
    'completed':    ss.completed,
    'restSeconds':  ss.restSeconds,
  };

  Map<String, dynamic> _serializeGoal(HiveGoal g) => {
    'id':                    g.key,
    'title':                 g.title,
    'description':           g.description,
    'category':              g.category,
    'createdAt':             g.createdAt,
    'scheduleType':          g.scheduleType,
    'scheduleDaysOfWeek':    g.scheduleDaysOfWeek,
    'scheduleStartDate':     g.scheduleStartDate,
    'scheduleEndDate':       g.scheduleEndDate,
    'scheduleCustomInterval': g.scheduleCustomInterval,
    'status':                g.status,
    'currentStreak':         g.currentStreak,
    'bestStreak':            g.bestStreak,
    'deadlineDate':          g.deadlineDate,
    'colorIndex':            g.colorIndex,
  };

  Map<String, dynamic> _serializeSportSession(HiveSportSession s) => {
    'sportType':       s.sportType,
    'date':            s.date,
    'durationSeconds': s.durationSeconds,
    'distanceKm':      s.distanceKm,
    'notes':           s.notes,
  };

  // ── PRIVATE: parse & validate ─────────────────────────────

  BackupData _parse(String raw) {
    Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw BackupValidationError('Il file non è un JSON valido.');
    }
    _require(json, 'version');
    _require(json, 'app');
    _require(json, 'sessions');
    _require(json, 'goals');
    if (json['app'] != 'MarkFit') {
      throw BackupValidationError(
          'Il file non è un backup MarkFit.');
    }
    final ver = json['version'] as String? ?? '';
    if (!_versionCompatible(ver)) {
      throw BackupValidationError(
          'Versione backup ($ver) non compatibile con questa versione di MarkFit.');
    }
    return BackupData(
      version:    ver,
      exportedAt: json['exportedAt'] as String? ?? '',
      userId:     json['userId']     as String? ?? '',
      profile:    json['profile']    as Map<String, dynamic>?,
      exercises:  _listOf(json, 'exercises'),
      workouts:   _listOf(json, 'workouts'),
      workoutExercises: _listOf(json, 'workoutExercises'),
      circuits:   _listOf(json, 'circuits'),
      sessions:   _listOf(json, 'sessions'),
      sessionSets: _listOf(json, 'sessionSets'),
      exerciseNotes: _listOf(json, 'exerciseNotes'),
      goals:      _listOf(json, 'goals'),
      goalCompletions: _listOf(json, 'goalCompletions'),
      sportSessions: _listOf(json, 'sportSessions'),
      preferences: json['preferences'] as Map<String, dynamic>? ?? {},
    );
  }

  void _require(Map<String, dynamic> m, String key) {
    if (!m.containsKey(key)) {
      throw BackupValidationError(
          'Campo obbligatorio mancante: "$key".');
    }
  }

  bool _versionCompatible(String ver) {
    // Accetta 1.x.x
    return ver.startsWith('1.');
  }

  List<Map<String, dynamic>> _listOf(
      Map<String, dynamic> m, String key) {
    final raw = m[key];
    if (raw == null) return [];
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  // ── PRIVATE: clear ────────────────────────────────────────

  Future<void> _clearCurrentUserData() async {
    final hdb = HiveDatabase.instance;
    final gdb = GoalDatabase.instance;
    final sdb = SportDatabase.instance;

    // Sessions + sets
    await hdb.deleteAllSessions();
    await hdb.deleteAllNotes();

    // Workouts (also deletes workout exercises + circuits)
    final workouts = hdb.getWorkouts();
    for (final w in workouts) {
      await hdb.deleteWorkout(w.key);
    }

    // Custom exercises
    final exercises = hdb.getExercises();
    for (final e in exercises.where((e) => e.isCustom)) {
      await hdb.deleteExercise(e.key);
    }

    // Goals + completions
    final goals = gdb.getGoals();
    for (final g in goals) {
      await gdb.deleteGoal(g.key);
    }

    // Sport sessions
    final sportSessions = sdb.getSessions();
    for (final s in sportSessions) {
      await sdb.deleteSession(s.key);
    }
  }

  // ── PRIVATE: import ────────────────────────────────────────

  Future<void> _importData(BackupData data) async {
    final hdb = HiveDatabase.instance;
    final gdb = GoalDatabase.instance;
    final sdb = SportDatabase.instance;
    final uid = hdb.currentUserId;

    // Key remap tables
    final exKeyMap  = <int, int>{};    // oldExKey → newExKey
    final woKeyMap  = <int, int>{};    // oldWoKey → newWoKey
    final sesKeyMap = <int, int>{};    // oldSesKey → newSesKey
    final goalKeyMap = <int, int>{};   // oldGoalKey → newGoalKey

    // 1. Custom exercises
    for (final e in data.exercises) {
      final oldId = (e['id'] as num).toInt();
      final obj   = HiveExercise(
        name:        e['name'] as String,
        muscleGroup: e['muscleGroup'] as String,
        notes:       e['notes'] as String?,
        isCustom:    true,
      );
      await hdb.addExercise(obj);
      exKeyMap[oldId] = (obj.key as num).toInt();
    }

    // 2. Workouts
    for (final w in data.workouts) {
      final oldId = (w['id'] as num).toInt();
      final obj   = HiveWorkout(
        name:           w['name'] as String,
        createdAt:      w['createdAt'] as String,
        iconId:         w['iconId'] as String?,
        iconColorIndex: w['iconColorIndex'] as int?,
      );
      final newKey = await hdb.addWorkout(obj);
      woKeyMap[oldId] = newKey;
    }

    // 3. WorkoutExercises
    for (final we in data.workoutExercises) {
      final oldWoKey = (we['workoutKey'] as num).toInt();
      final oldExKey = (we['exerciseKey'] as num).toInt();
      final newWoKey = woKeyMap[oldWoKey] ?? oldWoKey;
      // exerciseKey: remap if it was a custom exercise
      final newExKey = exKeyMap[oldExKey] ?? oldExKey;
      final obj = HiveWorkoutExercise(
        workoutKey:   newWoKey,
        exerciseKey:  newExKey,
        exerciseName: we['exerciseName'] as String,
        muscleGroup:  we['muscleGroup']  as String,
        sets:         (we['sets'] as num?)?.toInt()        ?? 3,
        targetReps:   (we['targetReps'] as num?)?.toInt()  ?? 8,
        targetWeight: (we['targetWeight'] as num?)?.toDouble(),
        restSeconds:  (we['restSeconds'] as num?)?.toInt(),
        notes:        we['notes'] as String?,
        sortOrder:    (we['sortOrder'] as num?)?.toInt()   ?? 0,
      );
      await hdb.addWorkoutExercise(obj);
    }

    // 4. Circuits
    for (final c in data.circuits) {
      final oldWoKey = (c['workoutKey'] as num).toInt();
      final obj = HiveCircuit(
        workoutKey: woKeyMap[oldWoKey] ?? oldWoKey,
        name:       c['name']   as String,
        rounds:     (c['rounds']    as num?)?.toInt() ?? 3,
        sortOrder:  (c['sortOrder'] as num?)?.toInt() ?? 0,
      );
      await hdb.addCircuit(obj);
    }

    // 5. Sessions — accesso diretto al box (createSession imposta date = now)
    final sesBoxName = '${uid}_sessions';
    final sesBox = Hive.box<HiveSession>(sesBoxName);
    for (final s in data.sessions) {
      final oldId    = (s['id'] as num).toInt();
      final oldWoKey = (s['workoutKey'] as num).toInt();
      final obj = HiveSession(
        workoutKey:      woKeyMap[oldWoKey] ?? oldWoKey,
        workoutName:     s['workoutName']     as String,
        date:            s['date']            as String,
        durationSeconds: (s['durationSeconds'] as num?)?.toInt(),
      );
      final newKey = await sesBox.add(obj);
      sesKeyMap[oldId] = (newKey as num).toInt();
    }

    // 6. Session sets
    for (final ss in data.sessionSets) {
      final oldSesKey = (ss['sessionKey'] as num).toInt();
      final oldExKey  = (ss['exerciseKey'] as num).toInt();
      final obj = HiveSessionSet(
        sessionKey:   sesKeyMap[oldSesKey] ?? oldSesKey,
        exerciseKey:  exKeyMap[oldExKey]   ?? oldExKey,
        exerciseName: ss['exerciseName'] as String,
        muscleGroup:  ss['muscleGroup']  as String,
        setNumber:    (ss['setNumber'] as num).toInt(),
        weight:       (ss['weight']    as num).toDouble(),
        reps:         (ss['reps']      as num).toInt(),
        completed:    ss['completed']  as bool? ?? false,
        restSeconds:  (ss['restSeconds'] as num?)?.toInt(),
      );
      await hdb.addSessionSet(obj);
    }

    // 7. Exercise notes
    for (final n in data.exerciseNotes) {
      final oldKey = (n['exerciseKey'] as num).toInt();
      final newKey = exKeyMap[oldKey] ?? oldKey;
      final note   = n['note'] as String? ?? '';
      if (note.isNotEmpty) {
        await hdb.saveExerciseNote(newKey, note);
      }
    }

    // 8. Goals
    for (final g in data.goals) {
      final oldId = (g['id'] as num).toInt();
      final daysRaw = g['scheduleDaysOfWeek'];
      final days    = daysRaw is List
          ? daysRaw.whereType<num>().map((e) => e.toInt()).toList()
          : <int>[];
      final newKey = await gdb.addGoal(HiveGoal(
        title:                  g['title']    as String,
        description:            g['description'] as String?,
        category:               g['category'] as String,
        createdAt:              g['createdAt'] as String,
        scheduleType:           g['scheduleType'] as String,
        scheduleDaysOfWeek:     days.isEmpty ? null : days,
        scheduleStartDate:      g['scheduleStartDate'] as String?,
        scheduleEndDate:        g['scheduleEndDate']   as String?,
        scheduleCustomInterval: (g['scheduleCustomInterval'] as num?)?.toInt(),
        status:          g['status']       as String? ?? 'active',
        currentStreak:   (g['currentStreak'] as num?)?.toInt() ?? 0,
        bestStreak:      (g['bestStreak']    as num?)?.toInt() ?? 0,
        deadlineDate:    g['deadlineDate'] as String?,
        colorIndex:      (g['colorIndex']   as num?)?.toInt() ?? 0,
      ));
      goalKeyMap[oldId] = (newKey as num).toInt();
    }

    // 9. Goal completions
    for (final c in data.goalCompletions) {
      final oldGoalKey = (c['goalKey'] as num).toInt();
      final newGoalKey = goalKeyMap[oldGoalKey] ?? oldGoalKey;
      await gdb.setCompletion(
          newGoalKey, c['date'] as String, c['completed'] as bool? ?? false);
    }

    // 10. Sport sessions — accesso diretto al box
    final sportBoxName = '${uid}_sport_sessions';
    if (Hive.isBoxOpen(sportBoxName)) {
      final sportBox = Hive.box<HiveSportSession>(sportBoxName);
      for (final s in data.sportSessions) {
        await sportBox.add(HiveSportSession(
          sportType:       s['sportType']  as String,
          date:            s['date']       as String,
          durationSeconds: (s['durationSeconds'] as num).toInt(),
          distanceKm:      (s['distanceKm'] as num?)?.toDouble(),
          notes:           s['notes'] as String?,
        ));
      }
    }
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