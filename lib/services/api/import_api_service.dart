import 'api_client.dart';
import 'dto/exercise_detail_dto.dart';
import 'dto/training_mode_detail_dto.dart';
import 'dto/workout_detail_dto.dart';
import 'dto/session_detail_dto.dart';
import 'dto/goal_detail_dto.dart';

/// Chiamate REST di sola lettura usate esclusivamente dal flusso di
/// import (backend → Hive locale). Riusa gli stessi endpoint delle
/// sync repository di invio, con parsing verso DTO più dettagliati
/// (servono tutti i campi per ricostruire correttamente l'entità
/// locale, non solo id/nome come per la sync).
class ImportApiService {
  final ApiClient _client;
  ImportApiService({ApiClient? client}) : _client = client ?? ApiClient.instance;

  List<Map<String, dynamic>> _asList(Map<String, dynamic> json) {
    final raw = json['data'] ?? json.values.first;
    if (raw is! List) return [];
    return raw.whereType<Map<String, dynamic>>().toList();
  }

  Future<List<RemoteExerciseDetail>> fetchExercises() async {
    final json = await _client.get('/exercises');
    return _asList(json).map(RemoteExerciseDetail.fromJson).toList();
  }

  Future<List<RemoteTrainingModeDetail>> fetchTrainingModes() async {
    final json = await _client.get('/training-modes?all=true');
    return _asList(json).map(RemoteTrainingModeDetail.fromJson).toList();
  }

  Future<List<RemoteWorkoutDetail>> fetchWorkouts() async {
    final json = await _client.get('/workouts');
    return _asList(json).map(RemoteWorkoutDetail.fromJson).toList();
  }

  Future<List<RemoteWorkoutExerciseDetail>> fetchWorkoutExercises(String workoutId) async {
    final json = await _client.get('/workouts/$workoutId/exercises');
    return _asList(json).map(RemoteWorkoutExerciseDetail.fromJson).toList();
  }

  Future<List<RemoteCircuitDetail>> fetchCircuits(String workoutId) async {
    final json = await _client.get('/workouts/$workoutId/circuits');
    return _asList(json).map(RemoteCircuitDetail.fromJson).toList();
  }

  Future<List<RemoteSessionDetail>> fetchSessions() async {
    final json = await _client.get('/sessions');
    return _asList(json).map(RemoteSessionDetail.fromJson).toList();
  }

  Future<List<RemoteSessionSetDetail>> fetchSessionSets(String sessionId) async {
    final json = await _client.get('/sessions/$sessionId/sets');
    return _asList(json).map(RemoteSessionSetDetail.fromJson).toList();
  }

  Future<List<RemoteGoalDetail>> fetchGoals() async {
    final json = await _client.get('/goals');
    return _asList(json).map(RemoteGoalDetail.fromJson).toList();
  }

  Future<List<RemoteGoalCompletionDetail>> fetchGoalCompletions(String goalId) async {
    final json = await _client.get('/goals/$goalId/completions');
    return _asList(json).map(RemoteGoalCompletionDetail.fromJson).toList();
  }
}