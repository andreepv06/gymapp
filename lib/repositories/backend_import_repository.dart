import 'package:hive/hive.dart';

import '../db/hive_database.dart';
import '../db/goal_database.dart';
import '../db/training_mode_database.dart';
import '../models/hive_models.dart';
import '../models/goal_models.dart';
import '../models/training_mode.dart';
import '../services/api/import_api_service.dart';
import 'sync_mapping_storage.dart';

class ImportSummary {
  final int exercisesImported;
  final int trainingModesImported;
  final int workoutsImported;
  final int workoutExercisesImported;
  final int circuitsImported;
  final int sessionsImported;
  final int sessionSetsImported;
  final int goalsImported;
  final int goalCompletionsImported;
  final List<String> errors;

  const ImportSummary({
    required this.exercisesImported,
    required this.trainingModesImported,
    required this.workoutsImported,
    required this.workoutExercisesImported,
    required this.circuitsImported,
    required this.sessionsImported,
    required this.sessionSetsImported,
    required this.goalsImported,
    required this.goalCompletionsImported,
    required this.errors,
  });

  bool get hasErrors => errors.isNotEmpty;
}

/// Importa nel Hive locale del dispositivo corrente tutto ciò che
/// l'utente ha già sincronizzato sul backend da ALTRI dispositivi.
///
/// Regole di sicurezza, identiche in spirito alle sync repository di
/// invio, ma invertite:
///  - MAI sovrascrive un elemento locale già esistente (dedup per
///    nome/firma contro ciò che è già in Hive);
///  - dopo aver creato un elemento locale, registra subito il
///    mapping locale↔remoto, così una successiva "Sincronizza tutto"
///    su questo stesso dispositivo lo riconosce come "già
///    sincronizzato" invece di rimandarlo al backend (evita un loop
///    invio→ricezione→reinvio);
///  - nessuna cancellazione, in nessun caso.
///
/// Sport sessions non incluso in questo primo blocco (nessuna
/// dipendenza da altri domini, aggiunta simmetrica rimandata).
class BackendImportRepository {
  static const _exerciseDomain = 'exercise';
  static const _trainingModeDomain = 'trainingMode';
  static const _workoutDomain = 'workout';
  static const _circuitDomain = 'circuit';
  static const _sessionDomain = 'session';
  static const _goalDomain = 'goal';

  final ImportApiService _api;
  final SyncMappingStorage _mapping;

  BackendImportRepository({ImportApiService? api, SyncMappingStorage? mapping})
      : _api = api ?? ImportApiService(),
        _mapping = mapping ?? SyncMappingStorage();

  Future<ImportSummary> importAllFromBackend() async {
    final errors = <String>[];

    final exerciseIdMap = await _importExercises(errors);
    final trainingModeIdMap = await _importTrainingModes(errors);
    final workoutResult = await _importWorkouts(errors, exerciseIdMap, trainingModeIdMap);
    final sessionResult = await _importSessions(errors, exerciseIdMap, trainingModeIdMap);
    final goalResult = await _importGoals(errors);

    return ImportSummary(
      exercisesImported: exerciseIdMap.createdCount,
      trainingModesImported: trainingModeIdMap.createdCount,
      workoutsImported: workoutResult.workoutsCreated,
      workoutExercisesImported: workoutResult.exercisesLinked,
      circuitsImported: workoutResult.circuitsCreated,
      sessionsImported: sessionResult.sessionsCreated,
      sessionSetsImported: sessionResult.setsCreated,
      goalsImported: goalResult.goalsCreated,
      goalCompletionsImported: goalResult.completionsCreated,
      errors: errors,
    );
  }

  // ── Esercizi ─────────────────────────────────────────────
  Future<_RemoteToLocalMap> _importExercises(List<String> errors) async {
    final map = _RemoteToLocalMap();
    try {
      final remoteExercises = await _api.fetchExercises();
      final localExercises = HiveDatabase.instance.getExercises();
      final localByName = {
        for (final e in localExercises) e.name.trim().toLowerCase(): e.key as int,
      };

      for (final remote in remoteExercises) {
        final normalized = remote.name.trim().toLowerCase();
        final existingLocalKey = localByName[normalized];
        if (existingLocalKey != null) {
          map.set(remote.id, existingLocalKey);
          await _mapping.setRemoteId(_exerciseDomain, existingLocalKey, remote.id);
          continue;
        }
        final created = HiveExercise(
          name: remote.name,
          muscleGroup: remote.muscleGroup,
          notes: remote.notes,
          isCustom: true,
        );
        await HiveDatabase.instance.addExercise(created);
        final newLocalKey = created.key as int;
        localByName[normalized] = newLocalKey;
        map.set(remote.id, newLocalKey, isNew: true);
        await _mapping.setRemoteId(_exerciseDomain, newLocalKey, remote.id);
      }
    } catch (e) {
      errors.add('Esercizi: $e');
    }
    return map;
  }

  // ── Modalità di allenamento ──────────────────────────────
  Future<_RemoteToLocalMap> _importTrainingModes(List<String> errors) async {
    final map = _RemoteToLocalMap();
    try {
      final remoteModes = await _api.fetchTrainingModes();
      final localModes = TrainingModeDatabase.instance.getAll();
      final localBySignature = {
        for (final m in localModes)
          '${m.name.trim().toLowerCase()}|${m.category.trim().toLowerCase()}': m.key as int,
      };

      for (final remote in remoteModes) {
        final signature =
            '${remote.name.trim().toLowerCase()}|${remote.category.trim().toLowerCase()}';
        final existingLocalKey = localBySignature[signature];
        if (existingLocalKey != null) {
          map.set(remote.id, existingLocalKey);
          await _mapping.setRemoteId(_trainingModeDomain, existingLocalKey, remote.id);
          continue;
        }
        final created = TrainingMode(
          name: remote.name,
          category: remote.category,
          createdAt: DateTime.now().toIso8601String(),
          origin: 'imported',
          sets: remote.sets
              .map((s) => TrainingModeSet(
                    order: s.order,
                    fixedReps: s.fixedReps,
                    minReps: s.minReps,
                    maxReps: s.maxReps,
                  ))
              .toList(),
        );
        final newLocalKey = await TrainingModeDatabase.instance.add(created) as int;
        localBySignature[signature] = newLocalKey;
        map.set(remote.id, newLocalKey, isNew: true);
        await _mapping.setRemoteId(_trainingModeDomain, newLocalKey, remote.id);
      }
    } catch (e) {
      errors.add('Modalità: $e');
    }
    return map;
  }

  // ── Schede + circuiti + esercizi ─────────────────────────
  Future<_WorkoutImportResult> _importWorkouts(
    List<String> errors,
    _RemoteToLocalMap exerciseMap,
    _RemoteToLocalMap trainingModeMap,
  ) async {
    int workoutsCreated = 0;
    int exercisesLinked = 0;
    int circuitsCreated = 0;

    try {
      final remoteWorkouts = await _api.fetchWorkouts();
      final localWorkoutNames = HiveDatabase.instance
          .getWorkouts()
          .map((w) => w.name.trim().toLowerCase())
          .toSet();

      for (final remoteWorkout in remoteWorkouts) {
        final alreadyImported =
            await _mapping.getRemoteId(_workoutDomain, remoteWorkout.id) != null;
        // Nota: qui il mapping è cercato al contrario (per id remoto)
        // solo come guardia extra; il controllo principale è per nome,
        // coerente con l'assenza di un lookup "getLocalIdByRemote" già
        // pronto in SyncMappingStorage (che indicizza per dominio+
        // chiave locale, non per id remoto — sufficiente qui perché il
        // dedup primario è comunque per nome).
        if (alreadyImported) continue;
        if (localWorkoutNames.contains(remoteWorkout.name.trim().toLowerCase())) {
          continue;
        }

        final createdWorkout = HiveWorkout(
          name: remoteWorkout.name,
          createdAt: DateTime.now().toIso8601String(),
          iconId: remoteWorkout.iconId,
          iconColorIndex: remoteWorkout.iconColorIndex,
        );
        final newWorkoutKey = await HiveDatabase.instance.addWorkout(createdWorkout);
        workoutsCreated++;
        await _mapping.setRemoteId(_workoutDomain, newWorkoutKey, remoteWorkout.id);
        localWorkoutNames.add(remoteWorkout.name.trim().toLowerCase());

        final remoteCircuits = await _api.fetchCircuits(remoteWorkout.id);
        final circuitIdMap = <String, int>{};
        for (final remoteCircuit in remoteCircuits) {
          final createdCircuit = HiveCircuit(
            workoutKey: newWorkoutKey,
            name: remoteCircuit.name,
            rounds: remoteCircuit.rounds,
            sortOrder: remoteCircuit.sortOrder,
          );
          await HiveDatabase.instance.addCircuit(createdCircuit);
          final newCircuitKey = createdCircuit.key as int;
          circuitIdMap[remoteCircuit.id] = newCircuitKey;
          circuitsCreated++;
          await _mapping.setRemoteId(_circuitDomain, newCircuitKey, remoteCircuit.id);
        }

        final remoteExercises = await _api.fetchWorkoutExercises(remoteWorkout.id);
        for (final we in remoteExercises) {
          final localExerciseKey = exerciseMap.getLocal(we.exerciseId);
          if (localExerciseKey == null) continue; // esercizio non risolto, salta in sicurezza

          final localCircuitKey =
              we.circuitId != null ? circuitIdMap[we.circuitId] : null;

          await HiveDatabase.instance.addWorkoutExercise(HiveWorkoutExercise(
            workoutKey: newWorkoutKey,
            exerciseKey: localExerciseKey,
            exerciseName: we.exerciseName,
            muscleGroup: we.muscleGroup,
            sets: we.sets,
            targetReps: we.targetReps,
            targetWeight: we.targetWeight,
            restSeconds: we.restSeconds,
            // Stesso pattern usato dalla V1: appartenenza al circuito
            // codificata nel prefisso di "notes".
            notes: localCircuitKey != null ? '__circuit_$localCircuitKey' : we.notes,
            sortOrder: we.sortOrder,
          ));
          exercisesLinked++;
        }
      }
    } catch (e) {
      errors.add('Schede: $e');
    }

    return _WorkoutImportResult(
      workoutsCreated: workoutsCreated,
      exercisesLinked: exercisesLinked,
      circuitsCreated: circuitsCreated,
    );
  }

  // ── Storico + serie ───────────────────────────────────────
  Future<_SessionImportResult> _importSessions(
    List<String> errors,
    _RemoteToLocalMap exerciseMap,
    _RemoteToLocalMap trainingModeMap,
  ) async {
    int sessionsCreated = 0;
    int setsCreated = 0;
    try {
      final remoteSessions = await _api.fetchSessions();
      final localSignatures = HiveDatabase.instance
          .getSessions()
          .map((s) => '${s.workoutName.trim().toLowerCase()}|${s.date}')
          .toSet();

      // Accesso diretto al box, come già fa BackupService.restoreBackup:
      // createSession() imposterebbe date=now(), inadatto qui perché
      // dobbiamo preservare la data storica reale della sessione importata.
      final uid = HiveDatabase.instance.currentUserId;
      final sessionBox = Hive.box<HiveSession>('${uid}_sessions');

      for (final remoteSession in remoteSessions) {
        final signature =
            '${remoteSession.workoutName.trim().toLowerCase()}|${remoteSession.date}';
        if (localSignatures.contains(signature)) continue;

        final createdSession = HiveSession(
          workoutKey: 0,
          workoutName: remoteSession.workoutName,
          date: remoteSession.date,
          durationSeconds: remoteSession.durationSeconds,
        );
        final newSessionKey = await sessionBox.add(createdSession) as int;
        sessionsCreated++;
        localSignatures.add(signature);

        final remoteSets = await _api.fetchSessionSets(remoteSession.id);
        for (final set in remoteSets) {
          final localExerciseKey =
              await _ensureExercise(set.exerciseName, set.muscleGroup, exerciseMap);

          await HiveDatabase.instance.addSessionSet(HiveSessionSet(
            sessionKey: newSessionKey,
            exerciseKey: localExerciseKey,
            exerciseName: set.exerciseName,
            muscleGroup: set.muscleGroup,
            setNumber: set.setNumber,
            weight: set.weight,
            reps: set.reps,
            completed: set.completed,
            restSeconds: set.restSeconds,
          ));
          setsCreated++;
        }
      }
    } catch (e) {
      errors.add('Storico: $e');
    }
    return _SessionImportResult(sessionsCreated: sessionsCreated, setsCreated: setsCreated);
  }

  Future<int> _ensureExercise(
      String name, String muscleGroup, _RemoteToLocalMap exerciseMap) async {
    final existing = HiveDatabase.instance
        .getExercises()
        .where((e) => e.name.trim().toLowerCase() == name.trim().toLowerCase());
    if (existing.isNotEmpty) return existing.first.key as int;
    final created = HiveExercise(name: name, muscleGroup: muscleGroup, isCustom: true);
    await HiveDatabase.instance.addExercise(created);
    return created.key as int;
  }

  // ── Obiettivi + completamenti ────────────────────────────
  Future<_GoalImportResult> _importGoals(List<String> errors) async {
    int goalsCreated = 0;
    int completionsCreated = 0;

    try {
      final remoteGoals = await _api.fetchGoals();
      final localGoals = GoalDatabase.instance.getGoals();
      final localBySignature = {
        for (final g in localGoals)
          '${g.title.trim().toLowerCase()}|${g.category.trim().toLowerCase()}': g.key as int,
      };

      for (final remoteGoal in remoteGoals) {
        final signature =
            '${remoteGoal.title.trim().toLowerCase()}|${remoteGoal.category.trim().toLowerCase()}';
        int localGoalKey;
        final existingKey = localBySignature[signature];
        if (existingKey != null) {
          localGoalKey = existingKey;
          await _mapping.setRemoteId(_goalDomain, localGoalKey, remoteGoal.id);
        } else {
          localGoalKey = await GoalDatabase.instance.addGoal(HiveGoal(
            title: remoteGoal.title,
            description: remoteGoal.description,
            category: remoteGoal.category,
            createdAt: DateTime.now().toIso8601String(),
            scheduleType: remoteGoal.scheduleType,
            scheduleDaysOfWeek: remoteGoal.scheduleDaysOfWeek.isEmpty
                ? null
                : remoteGoal.scheduleDaysOfWeek,
            scheduleStartDate: remoteGoal.scheduleStartDate,
            scheduleEndDate: remoteGoal.scheduleEndDate,
            scheduleCustomInterval: remoteGoal.scheduleCustomInterval,
            deadlineDate: remoteGoal.deadlineDate,
            colorIndex: remoteGoal.colorIndex,
          )) as int;
          goalsCreated++;
          localBySignature[signature] = localGoalKey;
          await _mapping.setRemoteId(_goalDomain, localGoalKey, remoteGoal.id);
        }

        final completions = await _api.fetchGoalCompletions(remoteGoal.id);
        for (final c in completions) {
          await GoalDatabase.instance.setCompletion(localGoalKey, c.date, c.completed);
          completionsCreated++;
        }
      }
    } catch (e) {
      errors.add('Obiettivi: $e');
    }

    return _GoalImportResult(
      goalsCreated: goalsCreated,
      completionsCreated: completionsCreated,
    );
  }
}

class _RemoteToLocalMap {
  final Map<String, int> _map = {};
  int createdCount = 0;

  void set(String remoteId, int localId, {bool isNew = false}) {
    _map[remoteId] = localId;
    if (isNew) createdCount++;
  }

  int? getLocal(String remoteId) => _map[remoteId];

  int? getLocalByName(String name) => null; // riservato per estensioni future
}

class _WorkoutImportResult {
  final int workoutsCreated;
  final int exercisesLinked;
  final int circuitsCreated;
  const _WorkoutImportResult({
    required this.workoutsCreated,
    required this.exercisesLinked,
    required this.circuitsCreated,
  });
}

class _SessionImportResult {
  final int sessionsCreated;
  final int setsCreated;
  const _SessionImportResult({required this.sessionsCreated, required this.setsCreated});
}

class _GoalImportResult {
  final int goalsCreated;
  final int completionsCreated;
  const _GoalImportResult({required this.goalsCreated, required this.completionsCreated});
}