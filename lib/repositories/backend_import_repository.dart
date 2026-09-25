import 'package:flutter/foundation.dart';
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
  final int workoutsPruned;

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
    this.workoutsPruned = 0,
  });

  bool get hasErrors => errors.isNotEmpty;
}

/// Importa nel Hive locale del dispositivo corrente tutto ciò che
/// l'utente ha già sincronizzato sul backend da ALTRI dispositivi.
///
/// AGGIORNATO (audit sincronizzazione — STEP 1, race condition di
/// avvio) — causa radice individuata: sia
/// BackendAuthProvider._triggerAutoImport() sia
/// SyncEngine.runOnce() (avviato subito dopo da
/// BackendAuthProvider stesso, tramite SyncEngine.start()) creavano
/// CIASCUNO una propria istanza di BackendImportRepository e
/// chiamavano importAllFromBackend() in modo completamente
/// indipendente — nessuno dei due sapeva dell'esistenza dell'altro.
/// Il risultato erano DUE esecuzioni concorrenti dell'intero
/// processo di download/import, che scrivevano contemporaneamente
/// sulle stesse box Hive e sullo stesso SyncMappingStorage
/// (SharedPreferences, privo di lock), producendo risultati non
/// deterministici ad ogni avvio (conteggi diversi di sessioni/
/// obiettivi/esercizi tra un tentativo e l'altro, con lo stesso
/// identico stato del backend).
///
/// FIX — importAllFromBackend() è ora un "single-flight lock": se
/// per l'UTENTE CORRENTE (HiveDatabase.instance.currentUserId,
/// stesso identificatore già usato per isolare i dati tra account
/// in tutta l'app) è già in corso un'esecuzione, ogni nuovo
/// chiamante si aggancia alla STESSA Future invece di avviarne una
/// seconda in parallelo — indipendentemente da quale componente
/// (BackendAuthProvider o SyncEngine) lo abbia richiesto. Il lock è
/// scoped per utente (non globale) per evitare che un cambio
/// account mentre un import è in volo possa far "agganciare"
/// erroneamente il nuovo utente ai dati di quello precedente.
///
/// Nessuna modifica ai call site esistenti: il comportamento
/// pubblico (firma del metodo, tipo di ritorno, gestione di
/// shouldAbort per il chiamante originale) resta identico.
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

  // NUOVO (fix Step 1) — mappa statica userId → import in corso.
  // Static perché il lock deve valere per TUTTE le istanze di
  // BackendImportRepository create nell'app (BackendAuthProvider e
  // SyncEngine ne creano ciascuno la propria), non solo per una
  // singola istanza.
  static final Map<String, Future<ImportSummary>> _inFlightImports = {};

  Future<ImportSummary> importAllFromBackend({bool Function()? shouldAbort}) {
    final uid = HiveDatabase.instance.currentUserId;
    final existing = _inFlightImports[uid];
    if (existing != null) {
      debugPrint('[BackendImportRepository] Import già in corso per '
          'l\'utente corrente: mi aggancio al ciclo esistente invece '
          'di avviarne uno nuovo in parallelo (fix race condition avvio).');
      return existing;
    }
    final future = _runImport(shouldAbort: shouldAbort);
    _inFlightImports[uid] = future;
    future.whenComplete(() {
      // Rimuove il lock solo se è ancora questa la Future registrata
      // per questo utente (protegge da edge case di rimozioni
      // incrociate se nel frattempo l'utente è cambiato e una nuova
      // Future è già stata registrata per lo stesso uid).
      if (identical(_inFlightImports[uid], future)) {
        _inFlightImports.remove(uid);
      }
    });
    return future;
  }

  // RINOMINATO da importAllFromBackend() — corpo identico a prima,
  // ora eseguito sempre e solo dall'UNICA istanza "proprietaria"
  // registrata nel lock sopra.
  Future<ImportSummary> _runImport({bool Function()? shouldAbort}) async {
    final errors = <String>[];
    final exerciseIdMap = await _importExercises(errors);
    if (shouldAbort?.call() ?? false) {
      return ImportSummary(
        exercisesImported: exerciseIdMap.createdCount,
        trainingModesImported: 0, workoutsImported: 0, workoutExercisesImported: 0,
        circuitsImported: 0, sessionsImported: 0, sessionSetsImported: 0,
        goalsImported: 0, goalCompletionsImported: 0, errors: errors);
    }
    final trainingModeIdMap = await _importTrainingModes(errors);
    if (shouldAbort?.call() ?? false) {
      return ImportSummary(
        exercisesImported: exerciseIdMap.createdCount,
        trainingModesImported: trainingModeIdMap.createdCount,
        workoutsImported: 0, workoutExercisesImported: 0, circuitsImported: 0,
        sessionsImported: 0, sessionSetsImported: 0,
        goalsImported: 0, goalCompletionsImported: 0, errors: errors);
    }
    final workoutResult = await _importWorkouts(errors, exerciseIdMap, trainingModeIdMap);
    if (shouldAbort?.call() ?? false) {
      return ImportSummary(
        exercisesImported: exerciseIdMap.createdCount,
        trainingModesImported: trainingModeIdMap.createdCount,
        workoutsImported: workoutResult.workoutsCreated,
        workoutExercisesImported: workoutResult.exercisesLinked,
        circuitsImported: workoutResult.circuitsCreated,
        sessionsImported: 0, sessionSetsImported: 0,
        goalsImported: 0, goalCompletionsImported: 0, errors: errors);
    }
    final workoutsPruned = await _pruneDeletedWorkouts(errors);
    if (shouldAbort?.call() ?? false) {
      return ImportSummary(
        exercisesImported: exerciseIdMap.createdCount,
        trainingModesImported: trainingModeIdMap.createdCount,
        workoutsImported: workoutResult.workoutsCreated,
        workoutExercisesImported: workoutResult.exercisesLinked,
        circuitsImported: workoutResult.circuitsCreated,
        sessionsImported: 0, sessionSetsImported: 0,
        goalsImported: 0, goalCompletionsImported: 0, errors: errors,
        workoutsPruned: workoutsPruned);
    }
    final sessionResult = await _importSessions(errors, exerciseIdMap, trainingModeIdMap);
    if (shouldAbort?.call() ?? false) {
      return ImportSummary(
        exercisesImported: exerciseIdMap.createdCount,
        trainingModesImported: trainingModeIdMap.createdCount,
        workoutsImported: workoutResult.workoutsCreated,
        workoutExercisesImported: workoutResult.exercisesLinked,
        circuitsImported: workoutResult.circuitsCreated,
        sessionsImported: sessionResult.sessionsCreated,
        sessionSetsImported: sessionResult.setsCreated,
        goalsImported: 0, goalCompletionsImported: 0, errors: errors,
        workoutsPruned: workoutsPruned);
    }
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
      workoutsPruned: workoutsPruned,
    );
  }

  // ── Esercizi ─────────────────────────────────────────────
  Future<_RemoteToLocalMap> _importExercises(List<String> errors) async {
    final map = _RemoteToLocalMap();
    List<dynamic> remoteExercises;
    try {
      remoteExercises = await _api.fetchExercises();
    } catch (e, st) {
      debugPrint('[BackendImportRepository] fetchExercises() FALLITA: $e\n$st');
      errors.add('Esercizi: $e');
      return map;
    }

    final localExercises = HiveDatabase.instance.getExercises();
    final localByName = {
      for (final e in localExercises) e.name.trim().toLowerCase(): e.key as int,
    };

    for (final remote in remoteExercises) {
      try {
        final trimmedName = remote.name.trim();
        if (trimmedName.isEmpty) {
          debugPrint('[BackendImportRepository] Esercizio remoto senza '
              'nome saltato (id=${remote.id}).');
          continue;
        }
        final normalized = trimmedName.toLowerCase();
        final existingLocalKey = localByName[normalized];
        if (existingLocalKey != null) {
          map.set(remote.id, existingLocalKey);
          await _mapping.setRemoteId(_exerciseDomain, existingLocalKey, remote.id);
          continue;
        }
        final created = HiveExercise(
          name: trimmedName,
          muscleGroup: remote.muscleGroup,
          notes: remote.notes,
          isCustom: true,
        );
        await HiveDatabase.instance.addExercise(created);
        if (created.key == null) continue; // difesa aggiuntiva
        final newLocalKey = created.key as int;
        localByName[normalized] = newLocalKey;
        map.set(remote.id, newLocalKey, isNew: true);
        await _mapping.setRemoteId(_exerciseDomain, newLocalKey, remote.id);
      } catch (e, st) {
        debugPrint('[BackendImportRepository] Esercizio "${remote.name}" '
            'FALLITO: $e\n$st');
        errors.add('Esercizio "${remote.name}": $e');
      }
    }
    return map;
  }

  // ── Modalità di allenamento ──────────────────────────────
  Future<_RemoteToLocalMap> _importTrainingModes(List<String> errors) async {
    final map = _RemoteToLocalMap();
    List<dynamic> remoteModes;
    try {
      remoteModes = await _api.fetchTrainingModes();
    } catch (e, st) {
      debugPrint('[BackendImportRepository] fetchTrainingModes() FALLITA: $e\n$st');
      errors.add('Modalità: $e');
      return map;
    }

    final localModes = TrainingModeDatabase.instance.getAll();
    final localBySignature = {
      for (final m in localModes)
        '${m.name.trim().toLowerCase()}|${m.category.trim().toLowerCase()}': m.key as int,
    };

    for (final remote in remoteModes) {
      try {
        final trimmedName = remote.name.trim();
        if (trimmedName.isEmpty) {
          debugPrint('[BackendImportRepository] Modalità remota senza '
              'nome saltata (id=${remote.id}).');
          continue;
        }
        final signature =
            '${trimmedName.toLowerCase()}|${remote.category.trim().toLowerCase()}';
        final existingLocalKey = localBySignature[signature];
        if (existingLocalKey != null) {
          map.set(remote.id, existingLocalKey);
          await _mapping.setRemoteId(_trainingModeDomain, existingLocalKey, remote.id);
          continue;
        }
        final created = TrainingMode(
          name: trimmedName,
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
        final newLocalKeyDynamic = await TrainingModeDatabase.instance.add(created);
        if (newLocalKeyDynamic == null) continue;
        final newLocalKey = newLocalKeyDynamic as int;
        localBySignature[signature] = newLocalKey;
        map.set(remote.id, newLocalKey, isNew: true);
        await _mapping.setRemoteId(_trainingModeDomain, newLocalKey, remote.id);
      } catch (e, st) {
        debugPrint('[BackendImportRepository] Modalità "${remote.name}" '
            'FALLITA: $e\n$st');
        errors.add('Modalità "${remote.name}": $e');
      }
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

    List<dynamic> remoteWorkouts;
    try {
      remoteWorkouts = await _api.fetchWorkouts();
    } catch (e) {
      errors.add('Schede: $e');
      return _WorkoutImportResult(
          workoutsCreated: 0, exercisesLinked: 0, circuitsCreated: 0);
    }

    final existingMappings = await _mapping.getAllMappings(_workoutDomain);
    final localKeyByRemoteId = <String, int>{
      for (final entry in existingMappings.entries)
        entry.value: int.parse(entry.key),
    };
    final localWorkoutNames = HiveDatabase.instance
        .getWorkouts()
        .map((w) => w.name.trim().toLowerCase())
        .toSet();

    for (final remoteWorkout in remoteWorkouts) {
      try {
        final tombstonedNow = await _mapping.getTombstones(_workoutDomain);
        if (tombstonedNow.contains(remoteWorkout.id)) continue;

        if (localKeyByRemoteId.containsKey(remoteWorkout.id)) continue;

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
        await _mapping.setRemoteId(_workoutDomain, newWorkoutKey, remoteWorkout.id);
        localKeyByRemoteId[remoteWorkout.id] = newWorkoutKey;
        localWorkoutNames.add(remoteWorkout.name.trim().toLowerCase());

        final tombstonedAfter = await _mapping.getTombstones(_workoutDomain);
        if (tombstonedAfter.contains(remoteWorkout.id)) {
          await HiveDatabase.instance.deleteWorkout(newWorkoutKey);
          await _mapping.removeMapping(_workoutDomain, newWorkoutKey);
          localKeyByRemoteId.remove(remoteWorkout.id);
          continue;
        }

        workoutsCreated++;

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
          if (localExerciseKey == null) continue;

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
            notes: localCircuitKey != null ? '__circuit_$localCircuitKey' : we.notes,
            sortOrder: we.sortOrder,
          ));
          exercisesLinked++;
        }
      } catch (e, st) {
        debugPrint('[BackendImportRepository] Scheda '
            '"${remoteWorkout.name}" FALLITA: $e\n$st');
        errors.add('Scheda "${remoteWorkout.name}": $e');
      }
    }

    return _WorkoutImportResult(
      workoutsCreated: workoutsCreated,
      exercisesLinked: exercisesLinked,
      circuitsCreated: circuitsCreated,
    );
  }

  // ── Riconciliazione cancellazioni schede ─────────────────
  Future<int> _pruneDeletedWorkouts(List<String> errors) async {
    int pruned = 0;
    try {
      final remoteWorkouts = await _api.fetchWorkouts();
      final remoteIds = remoteWorkouts.map((w) => w.id).toSet();
      final localMappings = await _mapping.getAllMappings(_workoutDomain);

      for (final entry in localMappings.entries) {
        if (remoteIds.contains(entry.value)) continue;

        final localKey = int.tryParse(entry.key);
        if (localKey != null) {
          try {
            await HiveDatabase.instance.deleteWorkout(localKey);
            pruned++;
          } catch (_) {}
        }
        await _mapping.removeMapping(_workoutDomain, entry.key);
      }
    } catch (e) {
      errors.add('Pulizia schede eliminate: $e');
    }
    return pruned;
  }

  // ── Storico + serie ───────────────────────────────────────
  Future<_SessionImportResult> _importSessions(
    List<String> errors,
    _RemoteToLocalMap exerciseMap,
    _RemoteToLocalMap trainingModeMap,
  ) async {
    int sessionsCreated = 0;
    int setsCreated = 0;

    List<dynamic> remoteSessions;
    try {
      remoteSessions = await _api.fetchSessions();
    } catch (e, st) {
      debugPrint('[BackendImportRepository] fetchSessions() FALLITA: $e\n$st');
      errors.add('Storico: $e');
      return _SessionImportResult(sessionsCreated: 0, setsCreated: 0);
    }

    final localSignatures = HiveDatabase.instance
        .getSessions()
        .map((s) => '${s.workoutName.trim().toLowerCase()}|${s.date}')
        .toSet();
    final tombstonedSessionIds = await _mapping.getTombstones(_sessionDomain);

    final uid = HiveDatabase.instance.currentUserId;
    final sessionBox = Hive.box<HiveSession>('${uid}_sessions');

    for (final remoteSession in remoteSessions) {
      try {
        if (tombstonedSessionIds.contains(remoteSession.id)) continue;
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
          if (localExerciseKey == null) continue; // salta solo questa serie

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
      } catch (e, st) {
        debugPrint('[BackendImportRepository] Sessione '
            '"${remoteSession.workoutName}" (${remoteSession.date}) '
            'FALLITA: $e\n$st');
        errors.add('Sessione "${remoteSession.workoutName}" '
            '(${remoteSession.date}): $e');
      }
    }
    return _SessionImportResult(sessionsCreated: sessionsCreated, setsCreated: setsCreated);
  }

  Future<int?> _ensureExercise(
      String name, String muscleGroup, _RemoteToLocalMap exerciseMap) async {
    final trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      debugPrint('[BackendImportRepository] Serie con esercizio senza nome '
          'saltata (dato remoto incompleto).');
      return null;
    }
    final existing = HiveDatabase.instance
        .getExercises()
        .where((e) => e.name.trim().toLowerCase() == trimmedName.toLowerCase());
    if (existing.isNotEmpty) return existing.first.key as int;
    final created = HiveExercise(name: trimmedName, muscleGroup: muscleGroup, isCustom: true);
    await HiveDatabase.instance.addExercise(created);
    return created.key as int;
  }

  // ── Obiettivi + completamenti ────────────────────────────
  Future<_GoalImportResult> _importGoals(List<String> errors) async {
    int goalsCreated = 0;
    int completionsCreated = 0;

    List<dynamic> remoteGoals;
    try {
      remoteGoals = await _api.fetchGoals();
    } catch (e, st) {
      debugPrint('[BackendImportRepository] fetchGoals() FALLITA: $e\n$st');
      errors.add('Obiettivi: $e');
      return _GoalImportResult(goalsCreated: 0, completionsCreated: 0);
    }

    final localGoals = GoalDatabase.instance.getGoals();
    final localBySignature = {
      for (final g in localGoals)
        '${g.title.trim().toLowerCase()}|${g.category.trim().toLowerCase()}': g.key as int,
    };

    for (final remoteGoal in remoteGoals) {
      try {
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
      } catch (e, st) {
        debugPrint('[BackendImportRepository] Obiettivo '
            '"${remoteGoal.title}" FALLITO: $e\n$st');
        errors.add('Obiettivo "${remoteGoal.title}": $e');
      }
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

  int? getLocalByName(String name) => null;
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