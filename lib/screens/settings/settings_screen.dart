import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/navigation/app_router.dart';
import '../../core/theme/markfit_colors.dart';
import '../../db/hive_database.dart';
import '../../providers/auth_provider.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/goal_provider.dart';
import '../../providers/sport_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/training_mode_provider.dart';
import '../../providers/workout_provider.dart';
import '../../services/backup_service.dart';
import '../../widgets/avatar_picker_sheet.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/glass_widgets.dart';
import '../../widgets/shared_sheets.dart';
import '../import/activity_import_screen.dart';

// ─────────────────────────────────────────────────────────────
// SettingsScreen — nessun Scaffold (tab di MainShell)
// ─────────────────────────────────────────────────────────────
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tp = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final c = context.mfc;
    final sysBottom = MediaQuery.of(context).viewPadding.bottom;

    return CosmicBackground(
      child: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: EdgeInsets.fromLTRB(20, 24, 20, 88 + sysBottom),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text('Impostazioni', style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.5)),
                      if ((auth.currentIdentifier ?? '').isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          auth.currentIdentifier!,
                          style: TextStyle(color: c.textTertiary, fontSize: 14),
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1),
                      ],
                    ])),
                  const SizedBox(width: 12),
                  GlassHeaderPill(children: [
                    GlassHeaderPillBtn(
                      icon: Icons.download_rounded,
                      color: MarkFitColors.teal,
                      tooltip: 'Esporta dati',
                      onTap: () => _showExportChooser(context, tp, auth)),
                    Container(width: 1, height: 20, color: c.divider),
                    GlassHeaderPillBtn(
                      icon: Icons.upload_rounded,
                      color: MarkFitColors.indigo,
                      tooltip: 'Importa backup',
                      onTap: () => _importBackup(context)),
                  ]),
                ],
              ),
              const SizedBox(height: 28),
              _ProfileCard(auth: auth, c: c),
              const SizedBox(height: 20),
              _SectionLabel('Aspetto', c: c),
              const SizedBox(height: 8),
              _ThemeToggle(isDark: tp.isDark, onToggle: tp.toggle, c: c),
              const SizedBox(height: 18),
              _SectionLabel('Backup dati', c: c),
              const SizedBox(height: 8),
              _Section(c: c, tiles: [
                _Tile(
                  icon: Icons.backup_rounded,
                  color: MarkFitColors.teal,
                  title: 'Esporta backup completo',
                  subtitle: 'Profilo, schede, esercizi, modalità e storico',
                  c: c,
                  onTap: () => _exportBackup(context, tp, auth, BackupExportType.full)),
                _Divider(c: c),
                _Tile(
                  icon: Icons.share_rounded,
                  color: MarkFitColors.indigo,
                  title: 'Esporta struttura schede',
                  subtitle: 'Schede, esercizi e modalità — senza storico',
                  c: c,
                  onTap: () => _exportBackup(context, tp, auth, BackupExportType.structure)),
                _Divider(c: c),
                _Tile(
                  icon: Icons.upload_outlined,
                  color: MarkFitColors.blue,
                  title: 'Importa backup',
                  subtitle: 'Ripristina o aggiungi da un file MarkFit',
                  c: c,
                  onTap: () => _importBackup(context)),
              ]),
              const SizedBox(height: 18),
              _SectionLabel('Sincronizzazione', c: c),
              const SizedBox(height: 8),
              _Section(c: c, tiles: [
                _Tile(
                  icon: Icons.upload_file_rounded,
                  color: MarkFitColors.blue,
                  title: 'Importa attività GPS',
                  subtitle: 'Da file TCX o GPX (Garmin, Suunto, Polar...)',
                  c: c,
                  onTap: () => pushPage(context, const ActivityImportScreen())),
              ]),
              const SizedBox(height: 18),
              _SectionLabel('Dati', c: c),
              const SizedBox(height: 8),
              _Section(c: c, tiles: [
                _Tile(
                  icon: Icons.delete_sweep_outlined,
                  color: MarkFitColors.red,
                  title: 'Elimina sessioni',
                  subtitle: 'Rimuove lo storico allenamenti',
                  c: c,
                  onTap: () => _confirmDeleteSessions(context, c)),
                _Divider(c: c),
                _Tile(
                  icon: Icons.note_alt_outlined,
                  color: MarkFitColors.orange,
                  title: 'Elimina note esercizi',
                  subtitle: 'Rimuove tutte le note degli esercizi',
                  c: c,
                  onTap: () => _confirmDeleteNotes(context, c)),
              ]),
              const SizedBox(height: 18),
              _SectionLabel('Account', c: c),
              const SizedBox(height: 8),
              _Section(c: c, tiles: [
                if (auth.accounts.length > 1) ...[
                  _Tile(
                    icon: Icons.switch_account_outlined,
                    color: MarkFitColors.blue,
                    title: 'Cambia account',
                    subtitle: '${auth.accounts.length} account salvati',
                    c: c,
                    onTap: () => _showSwitchAccount(context)),
                  _Divider(c: c),
                ],
                _Tile(
                  icon: Icons.logout_rounded,
                  color: MarkFitColors.red,
                  title: 'Logout',
                  titleColor: MarkFitColors.red,
                  c: c,
                  onTap: () => _confirmLogout(context, c)),
              ]),
              const SizedBox(height: 18),
              _SectionLabel('Info', c: c),
              const SizedBox(height: 8),
              _Section(c: c, tiles: [
                _Tile(
                  icon: Icons.info_outline_rounded,
                  color: MarkFitColors.cyan,
                  title: 'Versione',
                  c: c,
                  trailing: Text('1.0.0', style: TextStyle(
                      color: c.textTertiary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500))),
                _Divider(c: c),
                _Tile(
                  icon: Icons.fitness_center_rounded,
                  color: MarkFitColors.teal,
                  title: 'MarkFit',
                  subtitle: 'Traccia i tuoi allenamenti',
                  c: c),
              ]),
            ],
          ),
        ),
      ),
    );
  }

  // ── Export chooser ────────────────────────────────────────
  Future<void> _showExportChooser(
      BuildContext context, ThemeProvider tp, AuthProvider auth) async {
    final type = await showModalBottomSheet<BackupExportType>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => GlassSheetWrapper(
        title: 'Esporta dati',
        subtitle: 'Scegli cosa esportare',
        accentColor: MarkFitColors.teal,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          _Tile(
            icon: Icons.backup_rounded,
            color: MarkFitColors.teal,
            title: 'Backup completo',
            subtitle: 'Profilo, schede, esercizi, modalità e storico',
            c: ctx.mfc,
            onTap: () => Navigator.pop(ctx, BackupExportType.full)),
          const SizedBox(height: 4),
          _Tile(
            icon: Icons.share_rounded,
            color: MarkFitColors.indigo,
            title: 'Solo struttura schede',
            subtitle: 'Schede, esercizi e modalità — ideale da condividere',
            c: ctx.mfc,
            onTap: () => Navigator.pop(ctx, BackupExportType.structure)),
        ]),
      ),
    );
    if (type != null && context.mounted) {
      await _exportBackup(context, tp, auth, type);
    }
  }

  // ── Backup export ─────────────────────────────────────────
  Future<void> _exportBackup(BuildContext context, ThemeProvider tp,
      AuthProvider auth, BackupExportType type) async {
    final c = context.mfc;
    try {
      await BackupService.instance
          .exportBackup(auth: auth, isDark: tp.isDark, type: type);
      if (context.mounted) {
        _showSnack(
          context,
          c,
          type == BackupExportType.full
              ? '✓ Backup completo esportato'
              : '✓ Struttura schede esportata',
          MarkFitColors.teal,
        );
      }
    } catch (e) {
      if (context.mounted) {
        _showSnack(context, c, "Errore durante l'export", MarkFitColors.red);
      }
    }
  }

  // ── Backup import ─────────────────────────────────────────
  Future<void> _importBackup(BuildContext context) async {
    final c = context.mfc;
    BackupData? data;
    try {
      data = await BackupService.instance.pickAndParse();
    } on BackupValidationError catch (e) {
      if (context.mounted) {
        await showGlassDialog<void>(
          context: context,
          accentColor: MarkFitColors.red,
          icon: Container(width: 44, height: 44,
            decoration: BoxDecoration(
              color: MarkFitColors.red.withOpacity(0.12),
              shape: BoxShape.circle,
              border: Border.all(color: MarkFitColors.red.withOpacity(0.4))),
            child: const Icon(Icons.error_outline_rounded,
                color: MarkFitColors.red, size: 22)),
          title: 'Impossibile importare i dati',
          message: 'Il file utilizza una struttura dati incompatibile con '
              'questa versione dell\'applicazione.\n\n${e.message}',
          actions: [
            GlassDialogAction(label: 'OK', onTap: () => Navigator.pop(context)),
          ]);
      }
      return;
    } catch (_) {
      if (context.mounted) {
        _showSnack(context, context.mfc, 'Impossibile leggere il file',
            MarkFitColors.red);
      }
      return;
    }
    if (data == null || !context.mounted) return;

    final isStructure = data.isStructureOnly;
    final ok = await showGlassDialog<bool>(
      context: context,
      accentColor: isStructure ? MarkFitColors.indigo : MarkFitColors.orange,
      icon: Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color: (isStructure ? MarkFitColors.indigo : MarkFitColors.orange)
              .withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(
              color: (isStructure ? MarkFitColors.indigo : MarkFitColors.orange)
                  .withOpacity(0.4))),
        child: Icon(isStructure ? Icons.download_for_offline_rounded
                : Icons.restore_rounded,
            color: isStructure ? MarkFitColors.indigo : MarkFitColors.orange,
            size: 22)),
      title: isStructure ? 'Importa struttura schede' : 'Importa backup completo',
      message: isStructure
          ? 'Verranno aggiunte le schede contenute nel file '
            '(${_fmtDate(data.exportedAt)}).\n\nNessun dato esistente verrà '
            'sovrascritto o eliminato; nessuno storico verrà importato.'
          : 'Il backup del ${_fmtDate(data.exportedAt)} verrà ripristinato.'
            '\n\nI dati attuali verranno sostituiti. Vuoi procedere?',
      actions: [
        GlassDialogAction(label: 'Annulla',
            onTap: () => Navigator.pop(context, false)),
        GlassDialogAction(
            label: isStructure ? 'Importa' : 'Sostituisci',
            isDestructive: !isStructure,
            color: isStructure ? MarkFitColors.indigo : null,
            onTap: () => Navigator.pop(context, true)),
      ]);
    if (ok != true || !context.mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.black.withOpacity(0.55),
      builder: (ctx) => _LoadingDialog(c: context.mfc));
    try {
      await BackupService.instance.restoreBackup(data);
      if (context.mounted) {
        context.read<WorkoutProvider>().loadWorkouts();
        context.read<ExerciseProvider>().loadExercises();
        context.read<TrainingModeProvider>().loadModes();
        if (!isStructure) {
          context.read<GoalProvider>().loadGoals();
          context.read<SportProvider>().loadSessions();
        }
      }
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        _showSnack(
          context,
          context.mfc,
          isStructure ? '✓ Struttura schede importata' : '✓ Backup ripristinato',
          MarkFitColors.teal,
        );
      }
    } catch (e) {
      if (context.mounted) Navigator.pop(context);
      if (context.mounted) {
        _showSnack(context, context.mfc, "Errore durante l'import", MarkFitColors.red);
      }
    }
  }

  String _fmtDate(String iso) {
    try {
      final dt = DateTime.parse(iso);
      return '${dt.day.toString().padLeft(2, '0')}/'
          '${dt.month.toString().padLeft(2, '0')}/${dt.year}';
    } catch (_) { return iso; }
  }

  // ── Dialog helpers ────────────────────────────────────────
  Future<void> _confirmLogout(BuildContext context, MarkFitColors c) async {
    final ok = await showGlassDialog<bool>(
      context: context,
      accentColor: MarkFitColors.red,
      icon: Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color: MarkFitColors.red.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: MarkFitColors.red.withOpacity(0.4)),
          boxShadow: [BoxShadow(
              color: MarkFitColors.red.withOpacity(0.2), blurRadius: 12)]),
        child: const Icon(Icons.logout_rounded,
            color: MarkFitColors.red, size: 22)),
      title: 'Logout',
      message: "Vuoi uscire dall'account corrente?",
      actions: [
        GlassDialogAction(label: 'Annulla',
            onTap: () => Navigator.pop(context, false)),
        GlassDialogAction(label: 'Logout', isDestructive: true,
            onTap: () => Navigator.pop(context, true)),
      ]);
    if (ok == true && context.mounted) {
      context.read<AuthProvider>().logout();
    }
  }

  void _showSwitchAccount(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) =>
          _SwitchAccountSheet(auth: context.read<AuthProvider>()));
  }

  Future<void> _confirmDeleteSessions(
      BuildContext context, MarkFitColors c) async {
    final ok = await showGlassDialog<bool>(
      context: context,
      accentColor: MarkFitColors.red,
      icon: Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color: MarkFitColors.red.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: MarkFitColors.red.withOpacity(0.4))),
        child: const Icon(Icons.delete_sweep_outlined,
            color: MarkFitColors.red, size: 22)),
      title: 'Elimina sessioni',
      message: 'Tutte le sessioni verranno rimosse definitivamente.',
      actions: [
        GlassDialogAction(label: 'Annulla',
            onTap: () => Navigator.pop(context, false)),
        GlassDialogAction(label: 'Elimina tutto', isDestructive: true,
            onTap: () => Navigator.pop(context, true)),
      ]);
    if (ok == true && context.mounted) {
      await HiveDatabase.instance.deleteAllSessions();
      if (context.mounted) {
        _showSnack(context, c, 'Sessioni eliminate', MarkFitColors.teal);
      }
    }
  }

  Future<void> _confirmDeleteNotes(
      BuildContext context, MarkFitColors c) async {
    final ok = await showGlassDialog<bool>(
      context: context,
      accentColor: MarkFitColors.orange,
      icon: Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color: MarkFitColors.orange.withOpacity(0.12),
          shape: BoxShape.circle,
          border: Border.all(color: MarkFitColors.orange.withOpacity(0.4))),
        child: const Icon(Icons.note_alt_outlined,
            color: MarkFitColors.orange, size: 22)),
      title: 'Elimina note',
      message: 'Tutte le note degli esercizi verranno rimosse.',
      actions: [
        GlassDialogAction(label: 'Annulla',
            onTap: () => Navigator.pop(context, false)),
        GlassDialogAction(label: 'Elimina', isDestructive: true,
            onTap: () => Navigator.pop(context, true)),
      ]);
    if (ok == true && context.mounted) {
      await HiveDatabase.instance.deleteAllNotes();
      if (context.mounted) {
        _showSnack(context, c, 'Note eliminate', MarkFitColors.teal);
      }
    }
  }

  void _showSnack(
      BuildContext context, MarkFitColors c, String msg, Color accent) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: TextStyle(
          color: c.textOnAccent, fontWeight: FontWeight.w600)),
      backgroundColor: context.isDarkMode
          ? const Color(0xFF0D1117) : const Color(0xFF1E293B),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16)));
  }
}

// ─────────────────────────────────────────────────────────────
// _LoadingDialog
// ─────────────────────────────────────────────────────────────
class _LoadingDialog extends StatelessWidget {
  final MarkFitColors c;
  const _LoadingDialog({required this.c});
  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: c.glassCardStrong,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: c.glassBorder)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              const CircularProgressIndicator(
                  color: MarkFitColors.teal, strokeWidth: 3),
              const SizedBox(height: 16),
              Text('Operazione in corso...',
                  style: TextStyle(
                      color: c.textPrimary, fontSize: 14,
                      fontWeight: FontWeight.w600)),
            ])))));
  }
}

// ─────────────────────────────────────────────────────────────
// _ProfileCard
// ─────────────────────────────────────────────────────────────
class _ProfileCard extends StatelessWidget {
  final AuthProvider auth;
  final MarkFitColors c;
  const _ProfileCard({required this.auth, required this.c});
  @override
  Widget build(BuildContext context) {
    final account = auth.currentAccount;
    final name = account?.fullName ?? auth.currentIdentifier ?? '';
    final bio = account?.bio;
    final email = auth.currentIdentifier ?? '';
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: c.glassBlurStrong, sigmaY: c.glassBlurStrong),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: c.glassCardStrong,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: MarkFitColors.teal.withOpacity(0.3), width: 1),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 20)]
                : [BoxShadow(
                    color: MarkFitColors.teal.withOpacity(0.06),
                    blurRadius: 20,
                    spreadRadius: 2)]),
          child: Column(children: [
            Row(children: [
              GestureDetector(
                onTap: () => showAvatarPickerSheet(context),
                child: Stack(children: [
                  AvatarWidget(auth: auth, radius: 38, c: c),
                  Positioned(right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          MarkFitColors.teal, MarkFitColors.tealDk]),
                        shape: BoxShape.circle,
                        border: Border.all(color: c.scaffoldBg, width: 2),
                        boxShadow: [BoxShadow(
                            color: MarkFitColors.teal.withOpacity(0.4),
                            blurRadius: 6)]),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 12, color: Colors.white))),
                ])),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(name, style: TextStyle(
                    color: c.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (bio != null && bio.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(bio, style: TextStyle(
                      color: c.textSecondary, fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 3),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: MarkFitColors.teal.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                        color: MarkFitColors.teal.withOpacity(0.25),
                        width: 0.7)),
                  child: Text(email, style: TextStyle(
                      color: MarkFitColors.teal.withOpacity(0.9),
                      fontSize: 10,
                      fontWeight: FontWeight.w600),
                      overflow: TextOverflow.ellipsis)),
              ])),
            ]),
            if (account != null &&
                (account.firstName != null ||
                 account.birthDate != null ||
                 account.phone != null)) ...[
              const SizedBox(height: 12),
              Container(height: 0.6, color: c.divider),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (account.firstName != null)
                  _ProfileChip(
                    icon: Icons.person_rounded,
                    label: '${account.firstName} ${account.lastName ?? ''}'.trim(),
                    c: c),
                if (account.birthDate != null)
                  _ProfileChip(
                      icon: Icons.cake_outlined,
                      label: account.birthDate!, c: c),
                if (account.phone != null)
                  _ProfileChip(
                      icon: Icons.phone_outlined,
                      label: account.phone!, c: c),
                if (account.birthPlace != null)
                  _ProfileChip(
                      icon: Icons.location_on_outlined,
                      label: account.birthPlace!, c: c),
              ]),
            ],
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => _goToEdit(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: MarkFitColors.teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                      color: MarkFitColors.teal.withOpacity(0.35), width: 1)),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  Icon(Icons.edit_outlined, size: 15, color: MarkFitColors.teal),
                  SizedBox(width: 7),
                  Text('Modifica profilo', style: TextStyle(
                      color: MarkFitColors.teal,
                      fontSize: 13,
                      fontWeight: FontWeight.w700)),
                ]))),
          ]),
        ),
      ),
    );
  }
  void _goToEdit(BuildContext context) {
    pushPage(context, ChangeNotifierProvider.value(
        value: context.read<AuthProvider>(),
        child: const EditProfileScreen()));
  }
}

class _ProfileChip extends StatelessWidget {
  final IconData icon; final String label; final MarkFitColors c;
  const _ProfileChip({required this.icon, required this.label,
      required this.c});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: c.glassCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.glassBorder, width: 0.7)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 11, color: c.textTertiary),
        const SizedBox(width: 5),
        Text(label.trim(), style: TextStyle(
            fontSize: 11, color: c.textSecondary,
            fontWeight: FontWeight.w500)),
      ]));
  }
}

// ─────────────────────────────────────────────────────────────
// Glass building blocks
// ─────────────────────────────────────────────────────────────
class _SectionLabel extends StatelessWidget {
  final String label; final MarkFitColors c;
  const _SectionLabel(this.label, {required this.c});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(label.toUpperCase(), style: TextStyle(
          color: MarkFitColors.cyan.withOpacity(
              context.isDarkMode ? 0.65 : 0.75),
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.4)));
  }
}
class _Section extends StatelessWidget {
  final List<Widget> tiles; final MarkFitColors c;
  const _Section({required this.tiles, required this.c});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(
            sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: c.glassBorder, width: 0.8),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 12)]
                : null),
          child: Column(children: tiles))));
  }
}
class _Tile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? trailing;
  final MarkFitColors c;
  final VoidCallback? onTap;
  const _Tile({
    required this.icon, required this.color, required this.title,
    required this.c,
    this.titleColor, this.subtitle, this.trailing, this.onTap});
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap != null
          ? () { HapticFeedback.selectionClick(); onTap!(); }
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(children: [
          Container(width: 36, height: 36,
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 19)),
          const SizedBox(width: 12),
          Expanded(child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            Text(title, style: TextStyle(
                color: titleColor ?? c.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(
                  fontSize: 11, color: c.textTertiary)),
            ],
          ])),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(Icons.chevron_right_rounded,
                color: c.textTertiary, size: 18),
        ])));
  }
}
class _Divider extends StatelessWidget {
  final MarkFitColors c;
  const _Divider({required this.c});
  @override
  Widget build(BuildContext context) {
    return Container(
        height: 0.5,
        margin: const EdgeInsets.symmetric(horizontal: 14),
        color: c.divider);
  }
}

// ─────────────────────────────────────────────────────────────
// _ThemeToggle
// ─────────────────────────────────────────────────────────────
class _ThemeToggle extends StatelessWidget {
  final bool isDark; final VoidCallback onToggle; final MarkFitColors c;
  const _ThemeToggle({required this.isDark, required this.onToggle,
      required this.c});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); onToggle(); },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: c.glassCard,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: c.glassBorder, width: 0.8),
              boxShadow: c.showElevation
                  ? [BoxShadow(color: c.elevationColor, blurRadius: 12)]
                  : null),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: (isDark
                      ? MarkFitColors.indigo
                      : MarkFitColors.orange).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: isDark ? MarkFitColors.indigo : MarkFitColors.orange,
                  size: 19)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text('Tema', style: TextStyle(
                    color: c.textPrimary, fontSize: 14,
                    fontWeight: FontWeight.w600)),
                Text(isDark ? 'Modalità scura' : 'Modalità chiara',
                    style: TextStyle(
                        fontSize: 11, color: c.textTertiary)),
              ])),
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: 50, height: 28,
                decoration: BoxDecoration(
                  color: isDark
                      ? MarkFitColors.indigo.withOpacity(0.3)
                      : MarkFitColors.orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? MarkFitColors.indigo.withOpacity(0.5)
                        : MarkFitColors.orange.withOpacity(0.4),
                    width: 1)),
                child: AnimatedAlign(
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeInOut,
                  alignment: isDark
                      ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    width: 22, height: 22,
                    margin: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      color: Colors.white, shape: BoxShape.circle,
                      boxShadow: [BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4)]),
                    child: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode,
                      size: 12,
                      color: isDark
                          ? MarkFitColors.indigo : MarkFitColors.orange)))),
            ]),
          ),
        ),
      ));
  }
}

// ─────────────────────────────────────────────────────────────
// _SwitchAccountSheet
// ─────────────────────────────────────────────────────────────
class _SwitchAccountSheet extends StatelessWidget {
  final AuthProvider auth;
  const _SwitchAccountSheet({required this.auth});
  @override
  Widget build(BuildContext context) {
    return GlassSheetWrapper(
      title: 'Seleziona account',
      subtitle: '${auth.accounts.length} account disponibili',
      accentColor: MarkFitColors.blue,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ...auth.accounts.map((a) {
          final isCurrent = a.identifier == auth.currentIdentifier;
          final c = context.mfc;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: isCurrent
                  ? null
                  : () { Navigator.pop(context); _switchTo(context, a); },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? MarkFitColors.blue.withOpacity(0.1)
                          : c.glassCard,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCurrent
                            ? MarkFitColors.blue.withOpacity(0.4)
                            : c.glassBorder,
                        width: isCurrent ? 1.0 : 0.8)),
                    child: Row(children: [
                      Container(width: 40, height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            MarkFitColors.blue.withOpacity(0.3),
                            MarkFitColors.indigo.withOpacity(0.2)]),
                          shape: BoxShape.circle),
                        child: Center(child: Text(a.initials,
                            style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 14,
                                fontWeight: FontWeight.w800)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text(a.displayName ?? a.identifier,
                            style: TextStyle(
                                color: c.textPrimary,
                                fontSize: 14,
                                fontWeight: isCurrent
                                    ? FontWeight.w700 : FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(a.identifier, style: TextStyle(
                            fontSize: 11, color: c.textTertiary)),
                      ])),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: MarkFitColors.blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: MarkFitColors.blue.withOpacity(0.35),
                                width: 0.8)),
                          child: const Text('Attivo', style: TextStyle(
                              color: MarkFitColors.blue,
                              fontSize: 10,
                              fontWeight: FontWeight.w700))),
                    ]))))));
        }),
        const SizedBox(height: 4),
      ]),
    );
  }
  void _switchTo(BuildContext context, UserAccount account) {
    final pwCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) {
        final kb = MediaQuery.of(ctx).viewInsets.bottom;
        final c = ctx.mfc;
        return GlassSheetWrapper(
          title: 'Accedi come',
          subtitle: account.identifier,
          accentColor: MarkFitColors.teal,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            _GlassInput(
              ctrl: pwCtrl, c: c,
              hint: 'Password',
              icon: Icons.lock_outline_rounded,
              obscure: true),
            SizedBox(height: kb > 0 ? 12 : 16),
            GestureDetector(
              onTap: () async {
                final err = await ctx.read<AuthProvider>().login(
                    identifier: account.identifier,
                    password: pwCtrl.text);
                if (err != null && ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(err),
                    backgroundColor: MarkFitColors.red));
                } else if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [
                    MarkFitColors.teal, MarkFitColors.tealDk]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                      color: MarkFitColors.teal.withOpacity(0.4),
                      blurRadius: 12, offset: const Offset(0, 3))]),
                child: Text('Accedi', textAlign: TextAlign.center,
                    style: TextStyle(
                        color: c.textOnAccent, fontSize: 15,
                        fontWeight: FontWeight.w700)))),
            SizedBox(height: kb > 0 ? kb : 4),
          ]),
        );
      });
  }
}

// ─────────────────────────────────────────────────────────────
// AvatarWidget (condiviso)
// ─────────────────────────────────────────────────────────────
class AvatarWidget extends StatelessWidget {
  final AuthProvider auth;
  final double radius;
  final MarkFitColors c;
  const AvatarWidget({super.key, required this.auth,
      required this.radius, required this.c});
  @override
  Widget build(BuildContext context) {
    final b64 = auth.avatarBase64;
    if (b64 != null && b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        return Container(
          width: radius * 2, height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
                color: MarkFitColors.teal.withOpacity(0.5), width: 2),
            boxShadow: [BoxShadow(
                color: MarkFitColors.teal.withOpacity(0.25), blurRadius: 12)]),
          child: ClipOval(
              child: Image.memory(bytes, fit: BoxFit.cover)));
      } catch (_) {}
    }
    return Container(
      width: radius * 2, height: radius * 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            MarkFitColors.teal.withOpacity(0.4),
            MarkFitColors.cyan.withOpacity(0.15)]),
        shape: BoxShape.circle,
        border: Border.all(
            color: MarkFitColors.teal.withOpacity(0.55), width: 2),
        boxShadow: [BoxShadow(
            color: MarkFitColors.teal.withOpacity(0.3), blurRadius: 14)]),
      child: Center(child: Text(auth.initials, style: TextStyle(
          color: Colors.white,
          fontSize: radius * 0.55,
          fontWeight: FontWeight.w800))));
  }
}

// ─────────────────────────────────────────────────────────────
// EditProfileScreen
// ─────────────────────────────────────────────────────────────
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});
  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}
class _EditProfileScreenState extends State<EditProfileScreen> {
  late TextEditingController _firstNameCtrl;
  late TextEditingController _lastNameCtrl;
  late TextEditingController _phoneCtrl;
  late TextEditingController _birthPlaceCtrl;
  late TextEditingController _bioCtrl;
  DateTime? _selectedDate;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    final a = context.read<AuthProvider>().currentAccount;
    _firstNameCtrl = TextEditingController(text: a?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: a?.lastName ?? '');
    _phoneCtrl = TextEditingController(text: a?.phone ?? '');
    _birthPlaceCtrl = TextEditingController(text: a?.birthPlace ?? '');
    _bioCtrl = TextEditingController(text: a?.bio ?? '');
    if (a?.birthDate != null) {
      try { _selectedDate = DateTime.parse(a!.birthDate!); } catch (_) {}
    }
  }
  @override
  void dispose() {
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose();
    _phoneCtrl.dispose(); _birthPlaceCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime(now.year - 25),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Data di nascita',
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
                primary: MarkFitColors.teal)),
        child: child!));
    if (picked != null) setState(() => _selectedDate = picked);
  }
  Future<void> _save() async {
    setState(() => _loading = true);
    await context.read<AuthProvider>().updateProfile(
      firstName: _firstNameCtrl.text.trim().isEmpty
          ? null : _firstNameCtrl.text.trim(),
      lastName: _lastNameCtrl.text.trim().isEmpty
          ? null : _lastNameCtrl.text.trim(),
      phone: _phoneCtrl.text.trim().isEmpty
          ? null : _phoneCtrl.text.trim(),
      birthPlace: _birthPlaceCtrl.text.trim().isEmpty
          ? null : _birthPlaceCtrl.text.trim(),
      bio: _bioCtrl.text.trim().isEmpty
          ? null : _bioCtrl.text.trim(),
      birthDate: _selectedDate?.toIso8601String().split('T')[0]);
    setState(() => _loading = false);
    if (mounted) {
      Navigator.pop(context);
      _showSnack('Profilo aggiornato!');
    }
  }
  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: const TextStyle(
          color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFF0D1117),
      behavior: SnackBarBehavior.floating));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final c = context.mfc;
    final kbHeight = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      backgroundColor: Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: CosmicBackground(
        child: SafeArea(
          child: Column(children: [
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(
                    sigmaX: c.glassBlurStrong,
                    sigmaY: c.glassBlurStrong),
                child: Container(
                  decoration: BoxDecoration(
                    color: c.glassCard,
                    border: Border(bottom: BorderSide(
                        color: MarkFitColors.cyan.withOpacity(0.12),
                        width: 0.6)),
                    boxShadow: c.showElevation
                        ? [BoxShadow(color: c.elevationColor,
                            blurRadius: 6, offset: const Offset(0, 2))]
                        : null),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: c.glassCardStrong,
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: c.glassBorder, width: 0.7)),
                        child: Icon(Icons.arrow_back_ios_new_rounded,
                            size: 15, color: c.textPrimary))),
                    const SizedBox(width: 12),
                    Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text('Modifica profilo', style: TextStyle(
                          color: c.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.3)),
                      Text('Aggiorna i tuoi dati', style: TextStyle(
                          color: c.textTertiary, fontSize: 11)),
                    ])),
                    GestureDetector(
                      onTap: _loading ? null : () {
                        HapticFeedback.mediumImpact();
                        _save();
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          gradient: _loading ? null : const LinearGradient(
                              colors: [MarkFitColors.teal, MarkFitColors.tealDk]),
                          color: _loading ? c.glassCard : null,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: _loading ? null : [BoxShadow(
                              color: MarkFitColors.teal.withOpacity(0.4),
                              blurRadius: 10, offset: const Offset(0, 3))]),
                        child: _loading
                            ? SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: MarkFitColors.teal.withOpacity(0.7)))
                            : const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.check_rounded,
                                    color: Colors.white, size: 15),
                                SizedBox(width: 5),
                                Text('Salva', style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                              ]))),
                  ])))),
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + kbHeight),
                  child: Column(children: [
                    _EditAvatar(auth: auth, c: c),
                    const SizedBox(height: 20),
                    _FormSection(
                      title: 'Dati personali',
                      icon: Icons.person_rounded,
                      color: MarkFitColors.teal, c: c,
                      children: [
                      Row(children: [
                        Expanded(child: _GlassInput(
                            ctrl: _firstNameCtrl, c: c, hint: 'Nome',
                            icon: Icons.person_outline_rounded,
                            accentColor: MarkFitColors.teal)),
                        const SizedBox(width: 10),
                        Expanded(child: _GlassInput(
                            ctrl: _lastNameCtrl, c: c, hint: 'Cognome',
                            accentColor: MarkFitColors.teal)),
                      ]),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _pickDate,
                        child: _DateField(
                            date: _selectedDate, c: c,
                            hint: 'Data di nascita',
                            icon: Icons.cake_outlined)),
                      const SizedBox(height: 10),
                      _GlassInput(
                          ctrl: _birthPlaceCtrl, c: c,
                          hint: 'Luogo di nascita',
                          icon: Icons.location_on_outlined,
                          accentColor: MarkFitColors.indigo),
                      const SizedBox(height: 10),
                      _GlassInput(
                          ctrl: _phoneCtrl, c: c,
                          hint: 'Telefono',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          accentColor: MarkFitColors.green),
                    ]),
                    const SizedBox(height: 14),
                    _FormSection(
                      title: 'Su di me',
                      icon: Icons.notes_rounded,
                      color: MarkFitColors.cyan, c: c,
                      children: [
                      _GlassInput(
                          ctrl: _bioCtrl, c: c,
                          hint: 'Raccontati in poche parole...',
                          accentColor: MarkFitColors.cyan,
                          maxLines: 3),
                    ]),
                    const SizedBox(height: 24),
                    GestureDetector(
                      onTap: _loading ? null : _save,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          gradient: _loading ? null : const LinearGradient(
                              colors: [MarkFitColors.teal, MarkFitColors.tealDk]),
                          color: _loading ? c.glassCard : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _loading ? null : [BoxShadow(
                              color: MarkFitColors.teal.withOpacity(0.4),
                              blurRadius: 16, offset: const Offset(0, 4))]),
                        child: _loading
                            ? Row(mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white.withOpacity(0.7))),
                                const SizedBox(width: 10),
                                const Text('Salvataggio...', style: TextStyle(
                                    color: Colors.white, fontSize: 15,
                                    fontWeight: FontWeight.w600)),
                              ])
                            : const Row(mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                Icon(Icons.update_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Salva modifiche', style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w700)),
                              ]))),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _EditAvatar — FIX MODIFICA 1
// Tap sull'avatar o su "Cambia foto" apre l'unico sheet condiviso
// (Fotocamera/Galleria/Rimuovi). Nessuna logica di picking duplicata.
// ─────────────────────────────────────────────────────────────
class _EditAvatar extends StatelessWidget {
  final AuthProvider auth;
  final MarkFitColors c;
  const _EditAvatar({required this.auth, required this.c});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: c.glassCard,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: MarkFitColors.cyan.withOpacity(0.15), width: 0.8),
            boxShadow: c.showElevation
                ? [BoxShadow(color: c.elevationColor, blurRadius: 12)]
                : null),
          child: Column(children: [
            GestureDetector(
              onTap: () => showAvatarPickerSheet(context),
              child: Stack(children: [
                AvatarWidget(auth: auth, radius: 46, c: c),
                Positioned(right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(colors: [
                        MarkFitColors.teal, MarkFitColors.tealDk]),
                      shape: BoxShape.circle,
                      border: Border.all(color: c.scaffoldBg, width: 2)),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 14, color: Colors.white))),
              ])),
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => showAvatarPickerSheet(context),
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: MarkFitColors.teal.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: MarkFitColors.teal.withOpacity(0.3), width: 0.8)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(Icons.photo_camera_outlined,
                      size: 14, color: MarkFitColors.teal),
                  const SizedBox(width: 6),
                  Text('Cambia foto', style: TextStyle(
                      color: MarkFitColors.teal, fontSize: 12,
                      fontWeight: FontWeight.w600)),
                ]))),
          ]))));
  }
}

// ─────────────────────────────────────────────────────────────
// Form widgets
// ─────────────────────────────────────────────────────────────
class _FormSection extends StatelessWidget {
  final String title; final IconData icon;
  final Color color; final MarkFitColors c;
  final List<Widget> children;
  const _FormSection({required this.title, required this.icon,
      required this.color, required this.c, required this.children});
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Container(width: 24, height: 24,
          decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(6)),
          child: Icon(icon, size: 12, color: color)),
        const SizedBox(width: 7),
        Text(title.toUpperCase(), style: TextStyle(
            color: color.withOpacity(0.85), fontSize: 10,
            fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      ]),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: c.glassCard,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: color.withOpacity(0.15), width: 0.8),
              boxShadow: c.showElevation
                  ? [BoxShadow(color: c.elevationColor, blurRadius: 10)]
                  : null),
            child: Column(children: children)))),
    ]);
  }
}
class _GlassInput extends StatelessWidget {
  final TextEditingController ctrl;
  final MarkFitColors c;
  final String hint;
  final IconData? icon;
  final Color accentColor;
  final TextInputType keyboardType;
  final int maxLines;
  final bool obscure;
  const _GlassInput({
    required this.ctrl, required this.c, required this.hint,
    this.icon,
    this.accentColor = MarkFitColors.teal,
    this.keyboardType = TextInputType.text,
    this.maxLines = 1,
    this.obscure = false,
  });
  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          decoration: BoxDecoration(
            color: c.inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.inputBorder, width: 0.8)),
          child: TextField(
            controller: ctrl,
            maxLines: obscure ? 1 : maxLines,
            obscureText: obscure,
            keyboardType: keyboardType,
            keyboardAppearance: isDark ? Brightness.dark : Brightness.light,
            textCapitalization: TextCapitalization.sentences,
            style: TextStyle(color: c.inputText, fontSize: 14),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: TextStyle(color: c.inputHint, fontSize: 14),
              prefixIcon: icon != null
                  ? Icon(icon, color: c.iconSecondary, size: 17) : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14, vertical: 12)),
          ),
        ),
      ),
    );
  }
}
class _DateField extends StatelessWidget {
  final DateTime? date;
  final MarkFitColors c;
  final String hint;
  final IconData icon;
  const _DateField({required this.date, required this.c,
      required this.hint, required this.icon});
  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/${d.year}';
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: c.inputBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: c.inputBorder, width: 0.8)),
          child: Row(children: [
            Icon(icon, color: c.iconSecondary, size: 17),
            const SizedBox(width: 10),
            Expanded(child: Text(
              date != null ? _fmt(date!) : hint,
              style: TextStyle(
                  color: date != null ? c.textPrimary : c.inputHint,
                  fontSize: 14))),
            Icon(Icons.calendar_today_outlined,
                color: c.iconSecondary, size: 15),
          ]),
        ),
      ),
    );
  }
}