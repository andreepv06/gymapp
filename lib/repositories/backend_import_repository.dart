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
/// AGGIORNATO (audit sincronizzazione cross-device) — causa radice
/// dei sintomi "obiettivi assenti" e "2 sessioni invece di 11":
/// PRIMA, _importGoals() e _importSessions() avvolgevano l'INTERO
/// ciclo `for` in un unico try/catch. Un errore sull'elaborazione di
/// UN SOLO elemento (es. fetchGoalCompletions/fetchSessionSets
/// fallita per timeout durante cold start di Render) interrompeva
/// l'elaborazione di TUTTI gli elementi successivi nel ciclo — quelli
/// già processati con successo restavano importati (da qui "2 su
/// 11": le prime 2 sessioni riuscite, la terza fallita, le restanti 9
/// mai nemmeno tentate).
///
/// ORA: il try/catch è per SINGOLO elemento (stesso pattern già
/// corretto usato in WorkoutSyncRepository per gli esercizi). Un
/// fallimento isolato viene registrato in `errors` ma non blocca più
/// gli elementi successivi. Applicato anche a _importWorkouts() per
/// coerenza, anche se lì l'impatto osservato era minore.
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

  Future<ImportSummary> importAllFromBackend({bool Function()? shouldAbort}) async {
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

  // ── Esercizi — invariato ──────────────────────────────────
  // ── Esercizi ─────────────────────────────────────────────
  // RISCRITTO (fix root cause) — PRIMA questo metodo aveva un unico
  // try/catch attorno all'INTERO ciclo, E lo stesso bug del cast
  // nullo già trovato e corretto nelle sessioni: se un esercizio
  // remoto aveva nome vuoto, la guardia di integrità in
  // HiveDatabase.addExercise() bloccava la scrittura silenziosamente
  // (nessuna eccezione), ma la riga successiva `created.key as int`
  // lanciava comunque un TypeError su null — interrompendo l'intero
  // ciclo, quindi TUTTI gli esercizi successivi non venivano più
  // importati. Dato che gli esercizi sono la base per collegare
  // schede e sessioni, questo spiegava direttamente "carica solo
  // alcuni esercizi" e i cicli/esercizi mancanti nelle schede.
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
  // RISCRITTO (fix root cause) — stesso principio di _importExercises.
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
  // FIX — try/catch per SINGOLA scheda (vedi commento di classe).
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

  // ── Riconciliazione cancellazioni schede — invariato ─────
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
  // FIX — try/catch per SINGOLA sessione (vedi commento di classe).
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

    final uid = HiveDatabase.instance.currentUserId;
    final sessionBox = Hive.box<HiveSession>('${uid}_sessions');

    for (final remoteSession in remoteSessions) {
      try {
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

  // FIX (bug reale confermato dai log) — se il backend restituisce
  // una serie il cui riferimento all'esercizio non è popolato (né
  // 'exercise.name' né 'exerciseName' presenti nella risposta),
  // RemoteSessionSetDetail.fromJson produce un nome vuoto. Prima
  // d'ora questo faceva crashare l'INTERA sessione: la guardia di
  // integrità in HiveDatabase.addExercise() blocca silenziosamente
  // la scrittura (nessuna eccezione), ma il codice successivo
  // leggeva comunque `created.key as int` — null, cast fallito,
  // eccezione non gestita che abortiva tutta la sessione (prova
  // diretta nei log: "Sessione ... FALLITA: TypeError: null: type
  // ... is not a subtype of type 'int'", ripetuto per ogni sessione
  // con almeno una serie orfana di questo tipo).
  //
  // Ora: se il nome è vuoto, ritorna null e la SOLA serie orfana
  // viene saltata (il resto della sessione, con tutte le altre serie
  // valide, viene comunque importato correttamente).
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
  // FIX — try/catch per SINGOLO obiettivo (vedi commento di classe).
  Future<_GoalImportResult> _importGoals(List<String> errors) async {
    int goalsCreated = 0;
    int completionsCreated = 0;

    List<dynamic> remoteGoals;
    try {
      remoteGoals = await _api.fetchGoals();
    } catch (e, st) {
      // NUOVO — diagnostica temporanea (audit sincronizzazione):
      // gli obiettivi risultano a ZERO totale anche dopo il fix
      // per-elemento, il che indica che fetchGoals() stessa fallisce
      // PRIMA di entrare nel ciclo — probabile bug di parsing in
      // RemoteGoalDetail.fromJson su un campo nullo/mancante. Questo
      // log mostra l'errore reale, da rimuovere una volta risolto.
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