import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/markfit_colors.dart';
import '../../providers/backend_auth_provider.dart';
import '../../repositories/exercise_sync_repository.dart';
import '../../repositories/workout_sync_repository.dart';
import '../../repositories/session_sync_repository.dart';
import '../../repositories/training_mode_sync_repository.dart';
import '../../repositories/goal_sync_repository.dart';
import '../../repositories/sport_session_sync_repository.dart';
import '../../services/api/api_client.dart';
import '../../services/api/api_exception.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';
import '../admin/admin_users_screen.dart';

class CloudSyncScreen extends StatefulWidget {
  const CloudSyncScreen({super.key});

  @override
  State<CloudSyncScreen> createState() => _CloudSyncScreenState();
}

class _CloudSyncScreenState extends State<CloudSyncScreen> {
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _baseUrlCtrl = TextEditingController(text: ApiClient.instance.baseUrl);
  bool _isRegisterMode = false;

  bool _syncing = false;
  ExerciseSyncResult? _lastSyncResult;
  String? _syncError;

  bool _syncingWorkouts = false;
  WorkoutSyncResult? _lastWorkoutSyncResult;
  String? _workoutSyncError;

  bool _syncingSessions = false;
  SessionSyncResult? _lastSessionSyncResult;
  String? _sessionSyncError;

  bool _syncingModes = false;
  TrainingModeSyncResult? _lastModeSyncResult;
  String? _modeSyncError;

  bool _syncingGoals = false;
  GoalSyncResult? _lastGoalSyncResult;
  String? _goalSyncError;

  bool _syncingSportSessions = false;
  SportSessionSyncResult? _lastSportSyncResult;
  String? _sportSyncError;

  Future<void> _syncSessions() async {
    setState(() {
      _syncingSessions = true;
      _sessionSyncError = null;
      _lastSessionSyncResult = null;
    });
    try {
      final result = await SessionSyncRepository().syncLocalHistoryToBackend();
      if (!mounted) return;
      setState(() => _lastSessionSyncResult = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sessionSyncError = e.message);
    } finally {
      if (mounted) setState(() => _syncingSessions = false);
    }
  }

  Future<void> _syncTrainingModes() async {
    setState(() {
      _syncingModes = true;
      _modeSyncError = null;
      _lastModeSyncResult = null;
    });
    try {
      final result =
          await TrainingModeSyncRepository().syncLocalModesToBackend();
      if (!mounted) return;
      setState(() => _lastModeSyncResult = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _modeSyncError = e.message);
    } finally {
      if (mounted) setState(() => _syncingModes = false);
    }
  }

  Future<void> _syncGoals() async {
    setState(() {
      _syncingGoals = true;
      _goalSyncError = null;
      _lastGoalSyncResult = null;
    });
    try {
      final result = await GoalSyncRepository().syncLocalGoalsToBackend();
      if (!mounted) return;
      setState(() => _lastGoalSyncResult = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _goalSyncError = e.message);
    } finally {
      if (mounted) setState(() => _syncingGoals = false);
    }
  }

  Future<void> _syncSportSessions() async {
    setState(() {
      _syncingSportSessions = true;
      _sportSyncError = null;
      _lastSportSyncResult = null;
    });
    try {
      final result =
          await SportSessionSyncRepository().syncLocalSportSessionsToBackend();
      if (!mounted) return;
      setState(() => _lastSportSyncResult = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sportSyncError = e.message);
    } finally {
      if (mounted) setState(() => _syncingSportSessions = false);
    }
  }

  Widget _buildSessionSyncSection(BuildContext context, MarkFitColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.glassCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MarkFitColors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.history_rounded, color: MarkFitColors.blue, size: 20),
            const SizedBox(width: 8),
            Text('Storico allenamenti', style: TextStyle(
                color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text(
            'Esporta tutte le sessioni e le relative serie. Operazione potenzialmente '
            'lunga con storici estesi. Crea sempre nuove voci (nessuna deduplicazione in questa fase).',
            style: TextStyle(color: c.textTertiary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          GlassPrimaryButton(
            label: _syncingSessions ? 'Sincronizzazione in corso...' : 'Esporta storico',
            color: MarkFitColors.blue,
            onTap: _syncingSessions ? null : _syncSessions,
          ),
          if (_sessionSyncError != null) ...[
            const SizedBox(height: 12),
            Text(_sessionSyncError!,
                style: const TextStyle(color: MarkFitColors.red, fontSize: 12)),
          ],
          if (_lastSessionSyncResult != null) ...[
            const SizedBox(height: 12),
            Text(
              '${_lastSessionSyncResult!.sessionsCreated} sessioni create · '
              '${_lastSessionSyncResult!.sessionsAlreadySynced} già sincronizzate · '
              '${_lastSessionSyncResult!.setsCreated} serie'
              '${_lastSessionSyncResult!.hasFailures ? ' · ${_lastSessionSyncResult!.sessionsFailed} sessioni fallite, ${_lastSessionSyncResult!.setsFailed} serie fallite' : ''}',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTrainingModeSyncSection(BuildContext context, MarkFitColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.glassCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MarkFitColors.purple.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.repeat_rounded, color: MarkFitColors.purple, size: 20),
            const SizedBox(width: 8),
            Text('Modalità di allenamento', style: TextStyle(
                color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text(
            'Esporta le modalità disponibili (non eliminate). Nessun versionamento/'
            'lineage sincronizzato in questa fase.',
            style: TextStyle(color: c.textTertiary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          GlassPrimaryButton(
            label: _syncingModes ? 'Sincronizzazione in corso...' : 'Esporta modalità',
            color: MarkFitColors.purple,
            onTap: _syncingModes ? null : _syncTrainingModes,
          ),
          if (_modeSyncError != null) ...[
            const SizedBox(height: 12),
            Text(_modeSyncError!,
                style: const TextStyle(color: MarkFitColors.red, fontSize: 12)),
          ],
          if (_lastModeSyncResult != null) ...[
            const SizedBox(height: 12),
            Text(
              '${_lastModeSyncResult!.created} modalità create · '
              '${_lastModeSyncResult!.alreadySynced} già sincronizzate'
              '${_lastModeSyncResult!.hasFailures ? ' · ${_lastModeSyncResult!.failed} fallite' : ''}',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGoalSyncSection(BuildContext context, MarkFitColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.glassCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MarkFitColors.green.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.track_changes_rounded, color: MarkFitColors.green, size: 20),
            const SizedBox(width: 8),
            Text('Obiettivi', style: TextStyle(
                color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text(
            'Esporta obiettivi e relativi completamenti storici.',
            style: TextStyle(color: c.textTertiary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          GlassPrimaryButton(
            label: _syncingGoals ? 'Sincronizzazione in corso...' : 'Esporta obiettivi',
            color: MarkFitColors.green,
            onTap: _syncingGoals ? null : _syncGoals,
          ),
          if (_goalSyncError != null) ...[
            const SizedBox(height: 12),
            Text(_goalSyncError!,
                style: const TextStyle(color: MarkFitColors.red, fontSize: 12)),
          ],
          if (_lastGoalSyncResult != null) ...[
            const SizedBox(height: 12),
            Text(
              '${_lastGoalSyncResult!.goalsCreated} obiettivi creati · '
              '${_lastGoalSyncResult!.goalsAlreadySynced} già sincronizzati · '
              '${_lastGoalSyncResult!.completionsCreated} completamenti'
              '${_lastGoalSyncResult!.hasFailures ? ' · ${_lastGoalSyncResult!.goalsFailed} obiettivi falliti, ${_lastGoalSyncResult!.completionsFailed} completamenti falliti' : ''}',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSportSessionSyncSection(BuildContext context, MarkFitColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.glassCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MarkFitColors.cyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.directions_run_rounded, color: MarkFitColors.cyan, size: 20),
            const SizedBox(width: 8),
            Text('Attività sportive', style: TextStyle(
                color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text(
            'Esporta le sessioni di corsa, ciclismo e altre attività registrate.',
            style: TextStyle(color: c.textTertiary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          GlassPrimaryButton(
            label: _syncingSportSessions ? 'Sincronizzazione in corso...' : 'Esporta attività',
            color: MarkFitColors.cyan,
            onTap: _syncingSportSessions ? null : _syncSportSessions,
          ),
          if (_sportSyncError != null) ...[
            const SizedBox(height: 12),
            Text(_sportSyncError!,
                style: const TextStyle(color: MarkFitColors.red, fontSize: 12)),
          ],
          if (_lastSportSyncResult != null) ...[
            const SizedBox(height: 12),
            Text(
              '${_lastSportSyncResult!.created} attività create · '
              '${_lastSportSyncResult!.alreadySynced} già sincronizzate'
              '${_lastSportSyncResult!.hasFailures ? ' · ${_lastSportSyncResult!.failed} fallite' : ''}',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    Future.microtask(
        () => context.read<BackendAuthProvider>().restoreSession());
  }

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    _baseUrlCtrl.dispose();
    super.dispose();
  }

  void _applyBaseUrl() {
    ApiClient.instance.setBaseUrl(_baseUrlCtrl.text.trim());
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text('URL backend impostato su: ${ApiClient.instance.baseUrl}'),
      backgroundColor: const Color(0xFF0D1117),
    ));
  }

  Future<void> _submit() async {
    final auth = context.read<BackendAuthProvider>();
    final identifier = _identifierCtrl.text.trim();
    final password = _passwordCtrl.text;
    if (identifier.isEmpty || password.isEmpty) return;

    final ok = _isRegisterMode
        ? await auth.register(identifier, password)
        : await auth.login(identifier, password);

    if (ok && mounted) {
      _identifierCtrl.clear();
      _passwordCtrl.clear();
    }
  }

  Future<void> _syncExercises() async {
    setState(() {
      _syncing = true;
      _syncError = null;
      _lastSyncResult = null;
    });
    try {
      final result =
          await ExerciseSyncRepository().syncLocalLibraryToBackend();
      if (!mounted) return;
      setState(() => _lastSyncResult = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _syncError = e.message);
    } finally {
      if (mounted) setState(() => _syncing = false);
    }
  }

  Future<void> _syncWorkouts() async {
    setState(() {
      _syncingWorkouts = true;
      _workoutSyncError = null;
      _lastWorkoutSyncResult = null;
    });
    try {
      final result = await WorkoutSyncRepository().syncLocalWorkoutsToBackend();
      if (!mounted) return;
      setState(() => _lastWorkoutSyncResult = result);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _workoutSyncError = e.message);
    } finally {
      if (mounted) setState(() => _syncingWorkouts = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    final auth = context.watch<BackendAuthProvider>();

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: CosmicBackground(
        child: SafeArea(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(children: [
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: c.glassCardInset,
                      borderRadius: BorderRadius.circular(11),
                      border: Border.all(color: c.glassBorder, width: 0.8)),
                    child: Icon(Icons.arrow_back_ios_new_rounded,
                        size: 15, color: c.iconPrimary))),
                const SizedBox(width: 12),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                  Text('Sincronizzazione cloud', style: TextStyle(
                      color: c.textPrimary, fontSize: 17,
                      fontWeight: FontWeight.w800)),
                  Text('Beta — connessione al nuovo backend', style: TextStyle(
                      color: c.textTertiary, fontSize: 11)),
                ])),
              ]),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: MarkFitColors.orange.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: MarkFitColors.orange.withOpacity(0.3)),
                      ),
                      child: Row(children: [
                        const Icon(Icons.science_outlined,
                            color: MarkFitColors.orange, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                              'Funzione sperimentale: non influisce sui tuoi dati locali (schede, sessioni, storico).',
                              style: TextStyle(
                                  color: c.textSecondary, fontSize: 12)),
                        ),
                      ]),
                    ),
                    const SizedBox(height: 16),
                    Text('URL BACKEND', style: TextStyle(
                        color: c.textTertiary, fontSize: 10,
                        fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                    const SizedBox(height: 8),
                    GlassTextField(
                      controller: _baseUrlCtrl,
                      hintText: 'http://localhost:3000/api',
                      onChanged: (_) {},
                    ),
                    const SizedBox(height: 8),
                    GlassPrimaryButton(
                      label: 'Applica URL',
                      color: MarkFitColors.indigo,
                      onTap: _applyBaseUrl,
                    ),
                    const SizedBox(height: 24),
                    if (auth.isAuthenticated) ...[
                      _buildAuthenticatedState(context, c, auth),
                      const SizedBox(height: 20),
                      _buildExerciseSyncSection(context, c),
                      const SizedBox(height: 20),
                      _buildWorkoutSyncSection(context, c),
                      const SizedBox(height: 20),
                      _buildSessionSyncSection(context, c),
                      const SizedBox(height: 20),
                      _buildTrainingModeSyncSection(context, c),
                      const SizedBox(height: 20),
                      _buildGoalSyncSection(context, c),
                      const SizedBox(height: 20),
                      _buildSportSessionSyncSection(context, c),
                    ] else ...[
                      _buildLoginForm(context, c, auth),
                    ],
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildAuthenticatedState(
      BuildContext context, MarkFitColors c, BackendAuthProvider auth) {
    final user = auth.currentUser;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.glassCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MarkFitColors.teal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.check_circle_rounded,
                color: MarkFitColors.teal, size: 20),
            const SizedBox(width: 8),
            Text('Connesso al backend', style: TextStyle(
                color: c.textPrimary, fontSize: 14,
                fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 8),
          Text('Identifier: ${user?.identifier ?? '-'}',
              style: TextStyle(color: c.textSecondary, fontSize: 13)),
          Text('Ruolo: ${user?.role ?? '-'}',
              style: TextStyle(color: c.textSecondary, fontSize: 13)),
          Text('Email verificata: ${user?.emailVerified == true ? "sì" : "no"}',
              style: TextStyle(color: c.textSecondary, fontSize: 13)),
          const SizedBox(height: 16),
          GlassPrimaryButton(
            label: auth.loading ? 'Attendere...' : 'Logout dal backend',
            color: MarkFitColors.red,
            onTap: auth.loading ? null : () => auth.logout(),
          ),
          if (user?.role == 'ADMIN') ...[
            const SizedBox(height: 10),
            GlassPrimaryButton(
              label: 'Apri pannello admin',
              color: MarkFitColors.orange,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AdminUsersScreen()),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseSyncSection(BuildContext context, MarkFitColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.glassCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MarkFitColors.indigo.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.fitness_center_rounded,
                color: MarkFitColors.indigo, size: 20),
            const SizedBox(width: 8),
            Text('Libreria esercizi', style: TextStyle(
                color: c.textPrimary, fontSize: 14,
                fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text(
            'Esporta i tuoi esercizi locali (Hive) verso il nuovo backend. '
            'Operazione manuale, ripetibile, non elimina né modifica nulla in locale.',
            style: TextStyle(color: c.textTertiary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          GlassPrimaryButton(
            label: _syncing ? 'Sincronizzazione in corso...' : 'Esporta libreria esercizi',
            color: MarkFitColors.indigo,
            onTap: _syncing ? null : _syncExercises,
          ),
          if (_syncError != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MarkFitColors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: MarkFitColors.red.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: MarkFitColors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_syncError!,
                      style: TextStyle(color: c.textPrimary, fontSize: 12)),
                ),
              ]),
            ),
          ],
          if (_lastSyncResult != null) ...[
            const SizedBox(height: 12),
            _SyncResultSummary(result: _lastSyncResult!, c: c),
          ],
        ],
      ),
    );
  }

  Widget _buildWorkoutSyncSection(BuildContext context, MarkFitColors c) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: c.glassCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: MarkFitColors.orange.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.assignment_rounded,
                color: MarkFitColors.orange, size: 20),
            const SizedBox(width: 8),
            Text('Schede di allenamento', style: TextStyle(
                color: c.textPrimary, fontSize: 14,
                fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text(
            'Esporta le schede locali con esercizi liberi e circuiti. '
            'Crea sempre nuove voci nel backend (nessuna deduplicazione schede/circuiti in questa fase).',
            style: TextStyle(color: c.textTertiary, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 14),
          GlassPrimaryButton(
            label: _syncingWorkouts ? 'Sincronizzazione in corso...' : 'Esporta schede',
            color: MarkFitColors.orange,
            onTap: _syncingWorkouts ? null : _syncWorkouts,
          ),
          if (_workoutSyncError != null) ...[
            const SizedBox(height: 12),
            Text(_workoutSyncError!,
                style: const TextStyle(color: MarkFitColors.red, fontSize: 12)),
          ],
          if (_lastWorkoutSyncResult != null) ...[
            const SizedBox(height: 12),
            Text(
              '${_lastWorkoutSyncResult!.workoutsCreated} schede create · '
              '${_lastWorkoutSyncResult!.workoutsAlreadySynced} già sincronizzate · '
              '${_lastWorkoutSyncResult!.freeExercisesLinked} esercizi liberi · '
              '${_lastWorkoutSyncResult!.circuitsCreated} circuiti · '
              '${_lastWorkoutSyncResult!.circuitExercisesLinked} esercizi in circuito'
              '${_lastWorkoutSyncResult!.hasFailures ? ' · ${_lastWorkoutSyncResult!.failedWorkoutNames.length} falliti' : ''}',
              style: TextStyle(color: c.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoginForm(
      BuildContext context, MarkFitColors c, BackendAuthProvider auth) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Expanded(
            child: _ModeChip(
              label: 'Login',
              selected: !_isRegisterMode,
              onTap: () => setState(() => _isRegisterMode = false),
              c: c,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ModeChip(
              label: 'Registrati',
              selected: _isRegisterMode,
              onTap: () => setState(() => _isRegisterMode = true),
              c: c,
            ),
          ),
        ]),
        const SizedBox(height: 16),
        GlassTextField(
          controller: _identifierCtrl,
          hintText: 'Email o username',
          onChanged: (_) {},
        ),
        const SizedBox(height: 10),
        _PasswordField(controller: _passwordCtrl, c: c),
        if (auth.lastError != null) ...[
          const SizedBox(height: 10),
          Text(auth.lastError!,
              style: const TextStyle(color: MarkFitColors.red, fontSize: 12)),
        ],
        const SizedBox(height: 16),
        GlassPrimaryButton(
          label: auth.loading
              ? 'Attendere...'
              : (_isRegisterMode ? 'Crea account' : 'Accedi'),
          color: MarkFitColors.teal,
          onTap: auth.loading ? null : _submit,
        ),
      ],
    );
  }
}

class _PasswordField extends StatefulWidget {
  final TextEditingController controller;
  final MarkFitColors c;
  const _PasswordField({required this.controller, required this.c});

  @override
  State<_PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<_PasswordField> {
  bool _obscured = true;

  @override
  Widget build(BuildContext context) {
    final c = widget.c;
    final isDark = context.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: c.inputBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.inputBorder, width: 0.8),
      ),
      child: TextField(
        controller: widget.controller,
        obscureText: _obscured,
        keyboardAppearance: isDark ? Brightness.dark : Brightness.light,
        style: TextStyle(color: c.inputText, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Password',
          hintStyle: TextStyle(color: c.inputHint, fontSize: 14),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          suffixIcon: GestureDetector(
            onTap: () => setState(() => _obscured = !_obscured),
            child: Icon(
              _obscured
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined,
              color: c.iconSecondary,
              size: 18,
            ),
          ),
        ),
      ),
    );
  }
}

class _SyncResultSummary extends StatelessWidget {
  final ExerciseSyncResult result;
  final MarkFitColors c;
  const _SyncResultSummary({required this.result, required this.c});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: MarkFitColors.teal.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: MarkFitColors.teal.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.check_circle_outline_rounded,
                color: MarkFitColors.teal, size: 16),
            const SizedBox(width: 6),
            Text('Sincronizzazione completata (${result.total} totali)',
                style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 6),
          Text('${result.created} creati · ${result.alreadySynced} già presenti'
              '${result.hasFailures ? ' · ${result.failedNames.length} falliti' : ''}',
              style: TextStyle(color: c.textSecondary, fontSize: 12)),
          if (result.hasFailures) ...[
            const SizedBox(height: 6),
            Text('Falliti: ${result.failedNames.join(', ')}',
                style: const TextStyle(color: MarkFitColors.red, fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

class _ModeChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final MarkFitColors c;
  const _ModeChip({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.c,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? MarkFitColors.teal.withOpacity(0.15)
              : c.glassCardInset,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? MarkFitColors.teal.withOpacity(0.5)
                  : c.glassBorder),
        ),
        child: Text(label,
            textAlign: TextAlign.center,
            style: TextStyle(
                color: selected ? MarkFitColors.teal : c.textTertiary,
                fontWeight: FontWeight.w700,
                fontSize: 13)),
      ),
    );
  }
}