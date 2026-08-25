import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/markfit_colors.dart';
import '../../providers/backend_auth_provider.dart';
import '../../services/api/api_client.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';

// ─────────────────────────────────────────────────────────────
// CloudSyncScreen — primo punto di contatto reale Flutter↔backend.
//
// Schermata isolata, raggiungibile da Impostazioni, che NON
// sostituisce in alcun modo il login/i dati V1: permette solo di
// testare/usare l'autenticazione contro il nuovo backend NestJS,
// tramite BackendAuthProvider (stato completamente separato da
// AuthProvider). Base per i prossimi blocchi di sincronizzazione.
// ─────────────────────────────────────────────────────────────
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
        GlassTextField(
          controller: _passwordCtrl,
          hintText: 'Password',
          obscureText: true,
          onChanged: (_) {},
        ),
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