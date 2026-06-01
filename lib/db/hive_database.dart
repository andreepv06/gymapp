import 'package:hive_flutter/hive_flutter.dart';
import '../models/hive_models.dart';

class HiveDatabase {
  static final HiveDatabase instance = HiveDatabase._internal();
  HiveDatabase._internal();

  // userId corrente (sanitizzato)
  String _userId = '';

  // Nomi delle box correnti
  String get _exercises => '${_userId}_exercises';
  String get _workouts => '${_userId}_workouts';
  String get _workoutExercises =>
      '${_userId}_workout_exercises';
  String get _sessions => '${_userId}_sessions';
  String get _sessionSets => '${_userId}_session_sets';
  String get _exerciseNotes => '${_userId}_exercise_notes';

  /// Chiamato una volta sola all'avvio — registra solo gli adapter.
  /// Le box vengono aperte in switchUser().
  Future<void> init() async {
    await Hive.initFlutter();

    // Registra adapter solo se non già registrati
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(HiveExerciseAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(HiveWorkoutAdapter());
    }
    if (!Hive.isAdapterRegistered(2)) {
      Hive.registerAdapter(HiveWorkoutExerciseAdapter());
    }
    if (!Hive.isAdapterRegistered(3)) {
      Hive.registerAdapter(HiveSessionAdapter());
    }
    if (!Hive.isAdapterRegistered(4)) {
      Hive.registerAdapter(HiveSessionSetAdapter());
    }
    if (!Hive.isAdapterRegistered(5)) {
      Hive.registerAdapter(HiveExerciseNoteAdapter());
    }
    // NON apriamo box qui — lo fa switchUser()
  }

  /// Cambia utente: chiude le box vecchie e apre quelle
  /// prefissate per [userId].
  Future<void> switchUser(String userId) async {
    final newId =
        userId.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '_');

    if (newId == _userId && _boxesOpen) {
      // Stesso utente, box già aperte — niente da fare
      return;
    }

    // Chiudi le box correnti (se aperte)
    await _closeCurrentBoxes();

    _userId = newId;

    // Apri le box del nuovo utente
    await _openCurrentBoxes();

    // Se è la prima volta per questo utente, inserisce gli esercizi default
    if (_exBox.isEmpty) {
      await _insertDefaultExercises();
    }
  }

  bool get _boxesOpen {
    if (_userId.isEmpty) return false;
    return Hive.isBoxOpen(_exercises) &&
        Hive.isBoxOpen(_workouts) &&
        Hive.isBoxOpen(_workoutExercises) &&
        Hive.isBoxOpen(_sessions) &&
        Hive.isBoxOpen(_sessionSets) &&
        Hive.isBoxOpen(_exerciseNotes);
  }

  Future<void> _openCurrentBoxes() async {
    if (_userId.isEmpty) return;
    if (!Hive.isBoxOpen(_exercises)) {
      await Hive.openBox<HiveExercise>(_exercises);
    }
    if (!Hive.isBoxOpen(_workouts)) {
      await Hive.openBox<HiveWorkout>(_workouts);
    }
    if (!Hive.isBoxOpen(_workoutExercises)) {
      await Hive.openBox<HiveWorkoutExercise>(
          _workoutExercises);
    }
    if (!Hive.isBoxOpen(_sessions)) {
      await Hive.openBox<HiveSession>(_sessions);
    }
    if (!Hive.isBoxOpen(_sessionSets)) {
      await Hive.openBox<HiveSessionSet>(_sessionSets);
    }
    if (!Hive.isBoxOpen(_exerciseNotes)) {
      await Hive.openBox<HiveExerciseNote>(_exerciseNotes);
    }
  }

  Future<void> _closeCurrentBoxes() async {
    if (_userId.isEmpty) return;
    final names = [
      _exercises,
      _workouts,
      _workoutExercises,
      _sessions,
      _sessionSets,
      _exerciseNotes,
    ];
    for (final name in names) {
      if (Hive.isBoxOpen(name)) {
        await Hive.box(name).close();
      }
    }
  }

  // ── Getter box (sicuri: lanciano se le box non sono aperte) ──

  Box<HiveExercise> get _exBox =>
      Hive.box<HiveExercise>(_exercises);
  Box<HiveWorkout> get _woBox =>
      Hive.box<HiveWorkout>(_workouts);
  Box<HiveWorkoutExercise> get _weBox =>
      Hive.box<HiveWorkoutExercise>(_workoutExercises);
  Box<HiveSession> get _seBox =>
      Hive.box<HiveSession>(_sessions);
  Box<HiveSessionSet> get _ssBox =>
      Hive.box<HiveSessionSet>(_sessionSets);
  Box<HiveExerciseNote> get _enBox =>
      Hive.box<HiveExerciseNote>(_exerciseNotes);

  // ── EXERCISES ──

  List<HiveExercise> getExercises() {
    final list = _exBox.values.toList();
    list.sort((a, b) {
      final mg = a.muscleGroup.compareTo(b.muscleGroup);
      return mg != 0 ? mg : a.name.compareTo(b.name);
    });
    return list;
  }

  Future<void> addExercise(HiveExercise exercise) async {
    await _exBox.add(exercise);
  }

  Future<void> deleteExercise(dynamic key) async {
    await _exBox.delete(key);
  }

  bool exerciseNameExists(String name) {
    return _exBox.values.any((e) =>
        e.name.trim().toLowerCase() ==
        name.trim().toLowerCase());
  }

  // ── WORKOUTS ──

  List<HiveWorkout> getWorkouts() {
    final list = _woBox.values.toList();
    list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return list;
  }

  Future<int> addWorkout(HiveWorkout workout) async {
    return await _woBox.add(workout);
  }

  Future<void> updateWorkout(dynamic key, String name) async {
    final w = _woBox.get(key);
    if (w != null) {
      w.name = name;
      await w.save();
    }
  }

  Future<void> deleteWorkout(dynamic key) async {
    await _woBox.delete(key);
    final toDelete = _weBox.keys
        .where((k) => _weBox.get(k)?.workoutKey == key)
        .toList();
    await _weBox.deleteAll(toDelete);
  }

  // ── WORKOUT EXERCISES ──

  List<HiveWorkoutExercise> getWorkoutExercises(
      dynamic workoutKey) {
    final list = _weBox.values
        .where((we) => we.workoutKey == workoutKey)
        .toList();
    list.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    for (final we in list) {
      if (we.notes == null) {
        try {
          final ex = _exBox.values
              .firstWhere((e) => e.key == we.exerciseKey);
          we.notes = ex.notes;
        } catch (_) {}
      }
    }
    return list;
  }

  Future<void> addWorkoutExercise(
      HiveWorkoutExercise we) async {
    await _weBox.add(we);
  }

  Future<void> updateWorkoutExercise(
      dynamic key, HiveWorkoutExercise updated) async {
    await _weBox.put(key, updated);
  }

  Future<void> deleteWorkoutExercise(dynamic key) async {
    await _weBox.delete(key);
  }

  Future<void> reorderWorkoutExercises(
      List<HiveWorkoutExercise> exercises) async {
    for (int i = 0; i < exercises.length; i++) {
      exercises[i].sortOrder = i;
      await exercises[i].save();
    }
  }

  // ── SESSIONS ──

  Future<int> createSession(
      dynamic workoutKey, String workoutName) async {
    final session = HiveSession(
      workoutKey:
          workoutKey is int ? workoutKey : workoutKey as int,
      workoutName: workoutName,
      date: DateTime.now().toIso8601String(),
    );
    return await _seBox.add(session);
  }

  Future<void> updateSessionDuration(
      dynamic sessionKey, int durationSeconds) async {
    final s = _seBox.get(sessionKey);
    if (s != null) {
      s.durationSeconds = durationSeconds;
      await s.save();
    }
  }

  Future<void> addSessionSet(HiveSessionSet set) async {
    await _ssBox.add(set);
  }

  List<HiveSession> getSessions() {
    final list = _seBox.values.toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  List<HiveSessionSet> getSessionSets(dynamic sessionKey) {
    return _ssBox.values
        .where((s) => s.sessionKey == sessionKey)
        .toList()
      ..sort((a, b) {
        final ex = a.exerciseKey.compareTo(b.exerciseKey);
        return ex != 0
            ? ex
            : a.setNumber.compareTo(b.setNumber);
      });
  }

  List<HiveSessionSet> getLastExerciseSets(
      dynamic exerciseKey) {
    final allSets = _ssBox.values
        .where((s) => s.exerciseKey == exerciseKey)
        .toList();
    if (allSets.isEmpty) return [];
    final lastSessionKey = allSets
        .map((s) => s.sessionKey)
        .reduce((a, b) => a > b ? a : b);
    return allSets
        .where((s) => s.sessionKey == lastSessionKey)
        .toList()
      ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
  }

  List<HiveSessionSet> getExerciseHistory(
      dynamic exerciseKey) {
    return _ssBox.values
        .where((s) => s.exerciseKey == exerciseKey)
        .toList()
      ..sort(
          (a, b) => b.sessionKey.compareTo(a.sessionKey));
  }

  Future<void> deleteAllSessions() async {
    await _seBox.clear();
    await _ssBox.clear();
  }

  // ── EXERCISE NOTES ──

  Future<void> saveExerciseNote(
      dynamic exerciseKey, String note) async {
    HiveExerciseNote? existing;
    try {
      existing = _enBox.values
          .firstWhere((n) => n.exerciseKey == exerciseKey);
    } catch (_) {}

    if (existing == null) {
      await _enBox.add(HiveExerciseNote(
        exerciseKey: exerciseKey is int
            ? exerciseKey
            : exerciseKey as int,
        note: note,
        updatedAt: DateTime.now().toIso8601String(),
      ));
    } else {
      existing.note = note;
      existing.updatedAt = DateTime.now().toIso8601String();
      await existing.save();
    }
  }

  Future<void> deleteExerciseNote(
      dynamic exerciseKey) async {
    final keys = _enBox.keys
        .where(
            (k) => _enBox.get(k)?.exerciseKey == exerciseKey)
        .toList();
    await _enBox.deleteAll(keys);
  }

  String? getExerciseNote(dynamic exerciseKey) {
    try {
      return _enBox.values
          .firstWhere((n) => n.exerciseKey == exerciseKey)
          .note;
    } catch (_) {
      return null;
    }
  }

  Map<int, String> getExerciseNotes(List<dynamic> keys) {
    final result = <int, String>{};
    for (final note in _enBox.values) {
      if (keys.contains(note.exerciseKey)) {
        result[note.exerciseKey] = note.note;
      }
    }
    return result;
  }

  Future<void> deleteAllNotes() async {
    await _enBox.clear();
  }

  // ── DEFAULT EXERCISES ──

  Future<void> _insertDefaultExercises() async {
    final defaults = [
      HiveExercise(name: 'Chest press', muscleGroup: 'Petto'),
      HiveExercise(
          name: 'Pectoral machine',
          muscleGroup: 'Petto'),
      HiveExercise(
          name: 'Croci ai cavi bassi (panca piana)',
          muscleGroup: 'Petto'),
      HiveExercise(
          name: 'Croci ai cavi bassi (panca inclinata)',
          muscleGroup: 'Petto'),
      HiveExercise(
          name: 'Croci ai cavi', muscleGroup: 'Petto'),
      HiveExercise(
          name: 'Panca inclinata con bilanciere',
          muscleGroup: 'Petto'),
      HiveExercise(
          name: 'Distensioni panca piana con manubri',
          muscleGroup: 'Petto'),
      HiveExercise(
          name: 'Distensioni panca inclinata con manubri',
          muscleGroup: 'Petto'),
      HiveExercise(
          name: 'Distensioni panca piana multipower',
          muscleGroup: 'Petto'),
      HiveExercise(
          name: 'Distensioni panca inclinata multipower',
          muscleGroup: 'Petto'),
      HiveExercise(
          name: 'Panca piana', muscleGroup: 'Petto'),
      HiveExercise(
          name: 'Panca inclinata', muscleGroup: 'Petto'),
      HiveExercise(
          name: 'Panca declinata', muscleGroup: 'Petto'),
      HiveExercise(
          name: 'Pullover con manubrio',
          muscleGroup: 'Petto'),
      HiveExercise(name: 'Push-up', muscleGroup: 'Petto'),
      HiveExercise(
          name: 'Lento avanti multipower',
          muscleGroup: 'Spalle'),
      HiveExercise(
          name: 'Lento dietro multipower',
          muscleGroup: 'Spalle'),
      HiveExercise(
          name: 'Lento manubri', muscleGroup: 'Spalle'),
      HiveExercise(
          name: 'Lento manubri con rotazione',
          muscleGroup: 'Spalle'),
      HiveExercise(
          name: 'Alzate laterali', muscleGroup: 'Spalle'),
      HiveExercise(
          name: 'Alzate frontali', muscleGroup: 'Spalle'),
      HiveExercise(
          name: 'Alzate laterali busto 90°',
          muscleGroup: 'Spalle'),
      HiveExercise(
          name: 'Trazioni al mento con bilanciere',
          muscleGroup: 'Spalle'),
      HiveExercise(
          name: 'Trazioni al mento multipower',
          muscleGroup: 'Spalle'),
      HiveExercise(
          name: 'Cavi incrociati alti',
          muscleGroup: 'Spalle'),
      HiveExercise(
          name: 'Cavi incrociati bassi',
          muscleGroup: 'Spalle'),
      HiveExercise(
          name: 'Rotatori con elastico',
          muscleGroup: 'Spalle'),
      HiveExercise(
          name: 'Military press', muscleGroup: 'Spalle'),
      HiveExercise(
          name: 'Face pull', muscleGroup: 'Spalle'),
      HiveExercise(
          name: 'Lat machine avanti',
          muscleGroup: 'Schiena'),
      HiveExercise(
          name: 'Lat machine inversa',
          muscleGroup: 'Schiena'),
      HiveExercise(
          name: 'Lat machine dietro',
          muscleGroup: 'Schiena'),
      HiveExercise(
          name: 'Low row', muscleGroup: 'Schiena'),
      HiveExercise(
          name: 'Rematore 1 manubrio a 90°',
          muscleGroup: 'Schiena'),
      HiveExercise(
          name: 'Rematore 2 manubri',
          muscleGroup: 'Schiena'),
      HiveExercise(
          name: 'Rematore con bilanciere',
          muscleGroup: 'Schiena'),
      HiveExercise(
          name: 'Pulley al cavo basso',
          muscleGroup: 'Schiena'),
      HiveExercise(
          name: 'Pulley al cavo alto',
          muscleGroup: 'Schiena'),
      HiveExercise(
          name: 'Stacco da terra', muscleGroup: 'Schiena'),
      HiveExercise(
          name: 'Vertical traction',
          muscleGroup: 'Schiena'),
      HiveExercise(
          name: 'Pull down', muscleGroup: 'Schiena'),
      HiveExercise(
          name: 'Trazioni', muscleGroup: 'Schiena'),
      HiveExercise(
          name: 'Curl manubri alternati su panca',
          muscleGroup: 'Bicipiti'),
      HiveExercise(
          name: 'Curl manubri alternati panca inclinata',
          muscleGroup: 'Bicipiti'),
      HiveExercise(
          name: 'Curl manubri alternati in piedi',
          muscleGroup: 'Bicipiti'),
      HiveExercise(
          name: 'Curl presa inversa manubri su panca',
          muscleGroup: 'Bicipiti'),
      HiveExercise(
          name:
              'Curl presa inversa manubri panca inclinata',
          muscleGroup: 'Bicipiti'),
      HiveExercise(
          name: 'Curl presa inversa manubri in piedi',
          muscleGroup: 'Bicipiti'),
      HiveExercise(
          name: 'Curl bilanciere',
          muscleGroup: 'Bicipiti'),
      HiveExercise(
          name: 'Curl bilanciere presa inversa',
          muscleGroup: 'Bicipiti'),
      HiveExercise(
          name: 'Panca scott', muscleGroup: 'Bicipiti'),
      HiveExercise(
          name: 'Curl in concentrazione',
          muscleGroup: 'Bicipiti'),
      HiveExercise(
          name: 'Curl con ercolina',
          muscleGroup: 'Bicipiti'),
      HiveExercise(
          name: 'Curl ercolina presa inversa',
          muscleGroup: 'Bicipiti'),
      HiveExercise(
          name: 'Curl ai cavi alti',
          muscleGroup: 'Bicipiti'),
      HiveExercise(
          name: 'Curl al cavo basso',
          muscleGroup: 'Bicipiti'),
      HiveExercise(
          name: 'Curl al cavo basso presa inversa',
          muscleGroup: 'Bicipiti'),
      HiveExercise(
          name: 'Tricipiti con ercolina',
          muscleGroup: 'Tricipiti'),
      HiveExercise(
          name: 'Tricipiti con manubrio su panca',
          muscleGroup: 'Tricipiti'),
      HiveExercise(
          name: 'French press', muscleGroup: 'Tricipiti'),
      HiveExercise(
          name:
              'Tricipiti con appoggio palmare su panca',
          muscleGroup: 'Tricipiti'),
      HiveExercise(
          name: 'Tricipiti al cavo alto',
          muscleGroup: 'Tricipiti'),
      HiveExercise(
          name: 'Tricipiti con manubrio busto a 90°',
          muscleGroup: 'Tricipiti'),
      HiveExercise(
          name: 'Piegamenti mani unite',
          muscleGroup: 'Tricipiti'),
      HiveExercise(
          name: 'Dip alle parallele',
          muscleGroup: 'Tricipiti'),
      HiveExercise(
          name: 'Tricep pushdown',
          muscleGroup: 'Tricipiti'),
      HiveExercise(
          name: 'Panca iperextension',
          muscleGroup: 'Lombari'),
      HiveExercise(
          name: 'Stacchi gambe semitese',
          muscleGroup: 'Lombari'),
      HiveExercise(
          name: 'Leg press', muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Leg extension', muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Leg curl', muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Glutes machine', muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Adductor machine',
          muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Abductor machine',
          muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Squat a corpo libero',
          muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Squat con bilanciere',
          muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Squat al multipower',
          muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Squat sumo', muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Affondi frontali', muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Affondi frontali con manubri',
          muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Affondi frontali con bilanciere',
          muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Affondi laterali', muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Polpacci alla pressa',
          muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Polpacci su rialzo',
          muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Slanci posteriori ai cavi',
          muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Slanci posteriori a corpo libero',
          muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Adduttori ai cavi', muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Abduttori ai cavi', muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Slanci laterali a corpo libero',
          muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Slanci posteriori in quadrupedia',
          muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Elevazioni laterali in quadrupedia',
          muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Ponte per glutei', muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Calf raises', muscleGroup: 'Gambe'),
      HiveExercise(
          name: 'Crunch avanti',
          muscleGroup: 'Addominali'),
      HiveExercise(
          name: 'Crunch avanti su palla',
          muscleGroup: 'Addominali'),
      HiveExercise(
          name: 'Addominali su palla',
          muscleGroup: 'Addominali'),
      HiveExercise(
          name: 'Crunch inversi',
          muscleGroup: 'Addominali'),
      HiveExercise(
          name: 'Addominali su panca piana',
          muscleGroup: 'Addominali'),
      HiveExercise(
          name: 'Addominali su panca inclinata',
          muscleGroup: 'Addominali'),
      HiveExercise(
          name: 'Addominali in isometria',
          muscleGroup: 'Addominali'),
      HiveExercise(
          name: 'Retto addominale con pallina',
          muscleGroup: 'Addominali'),
      HiveExercise(
          name:
              'Retto addominale con pallina + isometria',
          muscleGroup: 'Addominali'),
      HiveExercise(
          name: 'Obliqui con pallina',
          muscleGroup: 'Addominali'),
      HiveExercise(
          name: 'Obliqui su panca iperextension',
          muscleGroup: 'Addominali'),
      HiveExercise(
          name: 'Plank', muscleGroup: 'Addominali'),
      HiveExercise(
          name: 'Crunch', muscleGroup: 'Addominali'),
      HiveExercise(
          name: 'Russian twist',
          muscleGroup: 'Addominali'),
      HiveExercise(
          name: 'Leg raise', muscleGroup: 'Addominali'),
    ];
    for (final ex in defaults) {
      await _exBox.add(ex);
    }
  }
}