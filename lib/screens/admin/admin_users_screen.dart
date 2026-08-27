import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/markfit_colors.dart';
import '../../providers/backend_auth_provider.dart';
import '../../services/api/admin_api_service.dart';
import '../../services/api/api_exception.dart';
import '../../services/api/dto/admin_user_dto.dart';
import '../../widgets/cosmic_background.dart';

/// Pannello amministrativo minimo: lista utenti del backend.
/// Accessibile SOLO se l'utente autenticato ha role == 'ADMIN'
/// (verificato lato Flutter per la UI, ma l'unica vera barriera di
/// sicurezza è @Roles(Role.ADMIN) + RolesGuard sul backend — un
/// utente USER che forzasse la richiesta riceverebbe comunque 403).
class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final _api = AdminApiService();
  List<AdminUserSummary>? _users;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _api.fetchUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    final auth = context.watch<BackendAuthProvider>();
    final isAdmin = auth.currentUser?.role == 'ADMIN';

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
                Text('Admin — Utenti', style: TextStyle(
                    color: c.textPrimary, fontSize: 17,
                    fontWeight: FontWeight.w800)),
              ]),
            ),
            Expanded(child: _buildBody(context, c, isAdmin)),
          ]),
        ),
      ),
    );
  }

  Widget _buildBody(BuildContext context, MarkFitColors c, bool isAdmin) {
    if (!isAdmin) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            'Accesso riservato agli amministratori.',
            textAlign: TextAlign.center,
            style: TextStyle(color: c.textTertiary, fontSize: 14),
          ),
        ),
      );
    }
    if (_loading) {
      return const Center(child: CircularProgressIndicator(color: MarkFitColors.teal));
    }
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_error!, style: const TextStyle(color: MarkFitColors.red, fontSize: 13)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Riprova')),
          ]),
        ),
      );
    }
    final users = _users ?? [];
    if (users.isEmpty) {
      return Center(
        child: Text('Nessun utente registrato.',
            style: TextStyle(color: c.textTertiary, fontSize: 14)),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: users.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (_, i) {
          final u = users[i];
          return Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.glassCard,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: c.glassBorder, width: 0.8),
            ),
            child: Row(children: [
              Container(
                width: 36, height: 36,
                decoration: BoxDecoration(
                  color: (u.role == 'ADMIN' ? MarkFitColors.orange : MarkFitColors.teal)
                      .withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  u.role == 'ADMIN' ? Icons.shield_rounded : Icons.person_rounded,
                  size: 18,
                  color: u.role == 'ADMIN' ? MarkFitColors.orange : MarkFitColors.teal,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(u.displayName?.isNotEmpty == true ? u.displayName! : u.identifier,
                        style: TextStyle(color: c.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(u.identifier,
                        style: TextStyle(color: c.textTertiary, fontSize: 11)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(u.role, style: TextStyle(
                      color: u.role == 'ADMIN' ? MarkFitColors.orange : c.textSecondary,
                      fontSize: 11, fontWeight: FontWeight.w700)),
                  Text(u.isActive ? 'Attivo' : 'Disabilitato',
                      style: TextStyle(
                          color: u.isActive ? MarkFitColors.green : MarkFitColors.red,
                          fontSize: 10)),
                ],
              ),
            ]),
          );
        },
      ),
    );
  }
}