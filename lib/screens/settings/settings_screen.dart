import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/navigation/app_router.dart';
import '../../db/hive_database.dart';
import '../../providers/auth_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/cosmic_background.dart';
import '../../widgets/shared_sheets.dart';
import '../import/activity_import_screen.dart';
import 'image_picker_helper.dart';

// ── Design tokens ─────────────────────────────────────────────
const _cyan   = Color(0xFF00E5FF);
const _teal   = Color(0xFF00D4AA);
const _tealDk = Color(0xFF00A880);
const _indigo = Color(0xFF6366F1);
const _orange = Color(0xFFFF8C00);
const _red    = Color(0xFFFF3B30);
const _green  = Color(0xFF22C55E);
const _blue   = Color(0xFF3B82F6);

// ─────────────────────────────────────────────────────────────
// SettingsScreen
//
// FIX ARCHITETTURALE: nessun Scaffold proprio — tab dentro
// MainShell con extendBody:true. Stesso pattern di Home,
// Allenamenti e Storico.
// ─────────────────────────────────────────────────────────────

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final auth          = context.watch<AuthProvider>();
    final sysBottom     = MediaQuery.of(context).viewPadding.bottom;

    return CosmicBackground(
      child: SafeArea(
        bottom: false,
        child: Column(children: [

          // ── Glass AppBar ──────────────────────────────────────
          _SettingsAppBar(auth: auth),

          // ── Contenuto scrollabile ─────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.fromLTRB(16, 12, 16, 88 + sysBottom),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [

                  // Profilo
                  _GlassProfileCard(auth: auth),
                  const SizedBox(height: 20),

                  // Aspetto
                  _GlassSectionLabel('Aspetto'),
                  const SizedBox(height: 8),
                  _GlassThemeToggle(
                    isDark:   themeProvider.isDark,
                    onToggle: themeProvider.toggle),
                  const SizedBox(height: 18),

                  // Sincronizzazione
                  _GlassSectionLabel('Sincronizzazione'),
                  const SizedBox(height: 8),
                  _GlassSection(tiles: [
                    _GlassTile(
                      icon:     Icons.upload_file_rounded,
                      color:    _indigo,
                      title:    'Importa attività',
                      subtitle: 'Da file TCX o GPX (Garmin, Suunto, Polar...)',
                      onTap: () =>
                          pushPage(context, const ActivityImportScreen())),
                  ]),
                  const SizedBox(height: 18),

                  // Dati
                  _GlassSectionLabel('Dati'),
                  const SizedBox(height: 8),
                  _GlassSection(tiles: [
                    _GlassTile(
                      icon:     Icons.delete_sweep_outlined,
                      color:    _red,
                      title:    'Elimina sessioni',
                      subtitle: 'Rimuove lo storico allenamenti',
                      onTap: () => _confirmDeleteSessions(context)),
                    _GlassTileDivider(),
                    _GlassTile(
                      icon:     Icons.note_alt_outlined,
                      color:    _orange,
                      title:    'Elimina note esercizi',
                      subtitle: 'Rimuove tutte le note degli esercizi',
                      onTap: () => _confirmDeleteNotes(context)),
                  ]),
                  const SizedBox(height: 18),

                  // Account
                  _GlassSectionLabel('Account'),
                  const SizedBox(height: 8),
                  _GlassSection(tiles: [
                    if (auth.accounts.length > 1) ...[
                      _GlassTile(
                        icon:     Icons.switch_account_outlined,
                        color:    _blue,
                        title:    'Cambia account',
                        subtitle: '${auth.accounts.length} account salvati',
                        onTap: () => _showSwitchAccount(context)),
                      _GlassTileDivider(),
                    ],
                    _GlassTile(
                      icon:      Icons.logout_rounded,
                      color:     _red,
                      title:     'Logout',
                      titleColor: _red,
                      onTap: () => _confirmLogout(context)),
                  ]),
                  const SizedBox(height: 18),

                  // Info
                  _GlassSectionLabel('Info'),
                  const SizedBox(height: 8),
                  _GlassSection(tiles: [
                    _GlassTile(
                      icon:  Icons.info_outline_rounded,
                      color: _cyan,
                      title: 'Versione',
                      trailing: Text('1.0.0', style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 13, fontWeight: FontWeight.w500))),
                    _GlassTileDivider(),
                    _GlassTile(
                      icon:     Icons.fitness_center_rounded,
                      color:    _teal,
                      title:    'MarkFit',
                      subtitle: 'Traccia i tuoi allenamenti'),
                  ]),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  // ── Dialogs ───────────────────────────────────────────────────

  void _confirmLogout(BuildContext context) async {
    final ok = await showGlassDialog<bool>(
      context: context, accentColor: _red,
      icon: Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color: _red.withOpacity(0.12), shape: BoxShape.circle,
          border: Border.all(color: _red.withOpacity(0.4)),
          boxShadow: [BoxShadow(color: _red.withOpacity(0.2), blurRadius: 12)]),
        child: const Icon(Icons.logout_rounded, color: _red, size: 22)),
      title:   'Logout',
      message: "Vuoi uscire dall'account corrente?",
      actions: [
        GlassDialogAction(
            label: 'Annulla', onTap: () => Navigator.pop(context, false)),
        GlassDialogAction(
            label: 'Logout', isDestructive: true,
            onTap: () => Navigator.pop(context, true)),
      ]);
    if (ok == true && context.mounted) {
      context.read<AuthProvider>().logout();
    }
  }

  void _showSwitchAccount(BuildContext context) {
    final auth = context.read<AuthProvider>();
    showModalBottomSheet(
      context:         context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea:     true,
      builder: (ctx) => _SwitchAccountSheet(auth: auth));
  }

  void _confirmDeleteSessions(BuildContext context) async {
    final ok = await showGlassDialog<bool>(
      context: context, accentColor: _red,
      icon: Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color: _red.withOpacity(0.12), shape: BoxShape.circle,
          border: Border.all(color: _red.withOpacity(0.4))),
        child: const Icon(Icons.delete_sweep_outlined, color: _red, size: 22)),
      title:   'Elimina sessioni',
      message: 'Tutte le sessioni verranno rimosse definitivamente.',
      actions: [
        GlassDialogAction(
            label: 'Annulla', onTap: () => Navigator.pop(context, false)),
        GlassDialogAction(
            label: 'Elimina tutto', isDestructive: true,
            onTap: () => Navigator.pop(context, true)),
      ]);
    if (ok == true && context.mounted) {
      await HiveDatabase.instance.deleteAllSessions();
      if (context.mounted) _showSnack(context, 'Sessioni eliminate');
    }
  }

  void _confirmDeleteNotes(BuildContext context) async {
    final ok = await showGlassDialog<bool>(
      context: context, accentColor: _orange,
      icon: Container(width: 44, height: 44,
        decoration: BoxDecoration(
          color: _orange.withOpacity(0.12), shape: BoxShape.circle,
          border: Border.all(color: _orange.withOpacity(0.4))),
        child: const Icon(Icons.note_alt_outlined, color: _orange, size: 22)),
      title:   'Elimina note',
      message: 'Tutte le note degli esercizi verranno rimosse.',
      actions: [
        GlassDialogAction(
            label: 'Annulla', onTap: () => Navigator.pop(context, false)),
        GlassDialogAction(
            label: 'Elimina', isDestructive: true,
            onTap: () => Navigator.pop(context, true)),
      ]);
    if (ok == true && context.mounted) {
      await HiveDatabase.instance.deleteAllNotes();
      if (context.mounted) _showSnack(context, 'Note eliminate');
    }
  }

  void _showSnack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
      backgroundColor: const Color(0xFF0D1117),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.all(16)));
  }
}

// ─────────────────────────────────────────────────────────────
// _SettingsAppBar
// ─────────────────────────────────────────────────────────────

class _SettingsAppBar extends StatelessWidget {
  final AuthProvider auth;
  const _SettingsAppBar({required this.auth});

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            border: Border(bottom: BorderSide(
                color: _cyan.withOpacity(0.12), width: 0.6))),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(children: [
            Container(width: 32, height: 32,
              decoration: BoxDecoration(
                color: _indigo.withOpacity(0.12),
                borderRadius: BorderRadius.circular(9)),
              child: const Icon(Icons.settings_rounded,
                  size: 16, color: _indigo)),
            const SizedBox(width: 10),
            const Text('Impostazioni', style: TextStyle(
                color: Colors.white, fontSize: 17,
                fontWeight: FontWeight.w800, letterSpacing: -0.3)),
            const Spacer(),
            Text(auth.currentIdentifier ?? '',
                style: TextStyle(
                    color: Colors.white.withOpacity(0.35), fontSize: 11),
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _GlassProfileCard
// ─────────────────────────────────────────────────────────────

class _GlassProfileCard extends StatelessWidget {
  final AuthProvider auth;
  const _GlassProfileCard({required this.auth});

  @override
  Widget build(BuildContext context) {
    final account = auth.currentAccount;
    final name    = account?.fullName ?? auth.currentIdentifier ?? '';
    final bio     = account?.bio;
    final email   = auth.currentIdentifier ?? '';

    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: LinearGradient(begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.1),
                Colors.white.withOpacity(0.04)]),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
                color: _teal.withOpacity(0.3), width: 1),
            boxShadow: [BoxShadow(
                color: _teal.withOpacity(0.07),
                blurRadius: 24, spreadRadius: 2)]),
          child: Column(children: [
            Row(children: [
              // Avatar
              GestureDetector(
                onTap: () => _goToEditProfile(context),
                child: Stack(children: [
                  AvatarWidget(auth: auth, radius: 38),
                  Positioned(right: 0, bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                            colors: [_teal, _tealDk]),
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFF0A0A0E), width: 2),
                        boxShadow: [BoxShadow(
                            color: _teal.withOpacity(0.4), blurRadius: 6)]),
                      child: const Icon(Icons.edit_rounded,
                          size: 12, color: Colors.white))),
                ])),
              const SizedBox(width: 14),
              // Info
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Text(name, style: const TextStyle(
                    color: Colors.white, fontSize: 18,
                    fontWeight: FontWeight.w800, letterSpacing: -0.3),
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                if (bio != null && bio.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(bio, style: TextStyle(
                      color: Colors.white.withOpacity(0.5), fontSize: 12),
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
                const SizedBox(height: 3),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: _teal.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                          color: _teal.withOpacity(0.25), width: 0.7)),
                    child: Text(email, style: TextStyle(
                        color: _teal.withOpacity(0.85), fontSize: 10,
                        fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis)),
                ]),
              ])),
            ]),

            // Dettagli account
            if (account != null &&
                (account.firstName != null ||
                 account.birthDate != null ||
                 account.phone != null)) ...[
              const SizedBox(height: 12),
              Container(height: 0.6,
                  color: Colors.white.withOpacity(0.06)),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 6, children: [
                if (account.firstName != null)
                  _ProfileChip(
                      icon: Icons.person_rounded,
                      label: '${account.firstName} ${account.lastName ?? ''}'.trim()),
                if (account.birthDate != null)
                  _ProfileChip(
                      icon: Icons.cake_outlined,
                      label: account.birthDate!),
                if (account.phone != null)
                  _ProfileChip(
                      icon: Icons.phone_outlined,
                      label: account.phone!),
                if (account.birthPlace != null)
                  _ProfileChip(
                      icon: Icons.location_on_outlined,
                      label: account.birthPlace!),
              ]),
            ],

            const SizedBox(height: 14),
            // Pulsante Modifica
            GestureDetector(
              onTap: () => _goToEditProfile(context),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  color: _teal.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(13),
                  border: Border.all(
                      color: _teal.withOpacity(0.35), width: 1)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                  const Icon(Icons.edit_outlined,
                      size: 15, color: _teal),
                  const SizedBox(width: 7),
                  const Text('Modifica profilo',
                      style: TextStyle(color: _teal, fontSize: 13,
                          fontWeight: FontWeight.w700)),
                ])),
            ),
          ]),
        ),
      ),
    );
  }

  void _goToEditProfile(BuildContext context) {
    pushPage(context, ChangeNotifierProvider.value(
      value: context.read<AuthProvider>(),
      child: const EditProfileScreen()));
  }
}

class _ProfileChip extends StatelessWidget {
  final IconData icon; final String label;
  const _ProfileChip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
    decoration: BoxDecoration(
      color: Colors.white.withOpacity(0.06),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Colors.white.withOpacity(0.12), width: 0.7)),
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 11, color: Colors.white.withOpacity(0.5)),
      const SizedBox(width: 5),
      Text(label.trim(), style: TextStyle(
          fontSize: 11, color: Colors.white.withOpacity(0.65),
          fontWeight: FontWeight.w500)),
    ]));
}

// ─────────────────────────────────────────────────────────────
// _GlassSectionLabel
// ─────────────────────────────────────────────────────────────

class _GlassSectionLabel extends StatelessWidget {
  final String label;
  const _GlassSectionLabel(this.label);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(left: 4),
    child: Text(label.toUpperCase(), style: TextStyle(
        color: _cyan.withOpacity(0.65), fontSize: 10,
        fontWeight: FontWeight.w800, letterSpacing: 1.4)));
}

// ─────────────────────────────────────────────────────────────
// _GlassSection + _GlassTile + _GlassTileDivider
// ─────────────────────────────────────────────────────────────

class _GlassSection extends StatelessWidget {
  final List<Widget> tiles;
  const _GlassSection({required this.tiles});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white.withOpacity(0.07),
              Colors.white.withOpacity(0.02)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
                color: Colors.white.withOpacity(0.1), width: 0.8)),
          child: Column(children: tiles))));
  }
}

class _GlassTile extends StatelessWidget {
  final IconData  icon;
  final Color     color;
  final String    title;
  final Color?    titleColor;
  final String?   subtitle;
  final Widget?   trailing;
  final VoidCallback? onTap;

  const _GlassTile({
    required this.icon, required this.color, required this.title,
    this.titleColor, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap != null ? () {
        HapticFeedback.selectionClick();
        onTap!();
      } : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: 14, vertical: 13),
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
                color: titleColor ?? Colors.white,
                fontSize: 14, fontWeight: FontWeight.w600)),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: TextStyle(
                  fontSize: 11,
                  color: Colors.white.withOpacity(0.4))),
            ],
          ])),
          if (trailing != null)
            trailing!
          else if (onTap != null)
            Icon(Icons.chevron_right_rounded,
                color: Colors.white.withOpacity(0.25), size: 18),
        ])));
  }
}

class _GlassTileDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    height: 0.5, margin: const EdgeInsets.symmetric(horizontal: 14),
    color: Colors.white.withOpacity(0.07));
}

// ─────────────────────────────────────────────────────────────
// _GlassThemeToggle
// ─────────────────────────────────────────────────────────────

class _GlassThemeToggle extends StatelessWidget {
  final bool isDark; final VoidCallback onToggle;
  const _GlassThemeToggle({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: GestureDetector(
          onTap: () { HapticFeedback.selectionClick(); onToggle(); },
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.white.withOpacity(0.07),
                Colors.white.withOpacity(0.02)]),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                  color: Colors.white.withOpacity(0.1), width: 0.8)),
            child: Row(children: [
              Container(width: 36, height: 36,
                decoration: BoxDecoration(
                  color: (isDark ? _indigo : _orange).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10)),
                child: Icon(
                  isDark ? Icons.dark_mode_rounded
                         : Icons.light_mode_rounded,
                  color: isDark ? _indigo : _orange, size: 19)),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                const Text('Tema', style: TextStyle(
                    color: Colors.white, fontSize: 14,
                    fontWeight: FontWeight.w600)),
                Text(isDark ? 'Modalità scura' : 'Modalità chiara',
                    style: TextStyle(
                        fontSize: 11,
                        color: Colors.white.withOpacity(0.4))),
              ])),
              // Toggle pill animata
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeInOut,
                width: 50, height: 28,
                decoration: BoxDecoration(
                  color: isDark
                      ? _indigo.withOpacity(0.35)
                      : _orange.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isDark
                        ? _indigo.withOpacity(0.5)
                        : _orange.withOpacity(0.4),
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
                      color: isDark ? _indigo : _orange)))),
            ]),
          ),
        ),
      ),
    );
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
      title:       'Seleziona account',
      subtitle:    '${auth.accounts.length} account disponibili',
      accentColor: _blue,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        ...auth.accounts.map((a) {
          final isCurrent = a.identifier == auth.currentIdentifier;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: isCurrent ? null : () {
                Navigator.pop(context);
                _switchTo(context, a);
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isCurrent
                          ? _blue.withOpacity(0.1)
                          : Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isCurrent
                            ? _blue.withOpacity(0.4)
                            : Colors.white.withOpacity(0.1),
                        width: isCurrent ? 1 : 0.8)),
                    child: Row(children: [
                      Container(width: 40, height: 40,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: [
                            _blue.withOpacity(0.3), _indigo.withOpacity(0.2)]),
                          shape: BoxShape.circle),
                        child: Center(child: Text(a.initials,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 14,
                                fontWeight: FontWeight.w800)))),
                      const SizedBox(width: 12),
                      Expanded(child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                        Text(a.displayName ?? a.identifier,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: isCurrent
                                    ? FontWeight.w700 : FontWeight.w500),
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                        Text(a.identifier, style: TextStyle(
                            fontSize: 11,
                            color: Colors.white.withOpacity(0.4))),
                      ])),
                      if (isCurrent)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _blue.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                                color: _blue.withOpacity(0.35), width: 0.8)),
                          child: const Text('Attivo', style: TextStyle(
                              color: _blue, fontSize: 10,
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
      context:         context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useSafeArea:     true,
      builder: (ctx) {
        final kb = MediaQuery.of(ctx).viewInsets.bottom;
        return GlassSheetWrapper(
          title:       'Accedi come',
          subtitle:    account.identifier,
          accentColor: _teal,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            // Glass TextField
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                        color: _teal.withOpacity(0.2), width: 0.8)),
                  child: TextField(
                    controller:         pwCtrl,
                    obscureText:        true,
                    keyboardAppearance: Brightness.dark,
                    style: const TextStyle(
                        color: Colors.white, fontSize: 14),
                    decoration: InputDecoration(
                      hintText:  'Password',
                      hintStyle: TextStyle(
                          color: Colors.white.withOpacity(0.3)),
                      prefixIcon: Icon(Icons.lock_outline_rounded,
                          color: Colors.white.withOpacity(0.35), size: 18),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 13))))),
            ),
            SizedBox(height: kb > 0 ? 12 : 16),
            GestureDetector(
              onTap: () async {
                final err = await ctx.read<AuthProvider>().login(
                    identifier: account.identifier,
                    password:   pwCtrl.text);
                if (err != null && ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(
                    content: Text(err, style: const TextStyle(
                        color: Colors.white)),
                    backgroundColor: _red.withOpacity(0.85)));
                } else if (ctx.mounted) {
                  Navigator.pop(ctx);
                }
              },
              child: Container(
                width:   double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(colors: [_teal, _tealDk]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(
                      color: _teal.withOpacity(0.4), blurRadius: 12,
                      offset: const Offset(0, 3))]),
                child: const Text('Accedi', textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white,
                        fontSize: 15, fontWeight: FontWeight.w700)))),
            SizedBox(height: kb > 0 ? kb : 4),
          ]),
        );
      });
  }
}

// ─────────────────────────────────────────────────────────────
// AvatarWidget — condiviso con EditProfileScreen
// ─────────────────────────────────────────────────────────────

class AvatarWidget extends StatelessWidget {
  final AuthProvider auth;
  final double       radius;
  const AvatarWidget({super.key, required this.auth, required this.radius});

  @override
  Widget build(BuildContext context) {
    final b64 = auth.avatarBase64;
    if (b64 != null && b64.isNotEmpty) {
      try {
        final bytes = base64Decode(b64);
        return Container(
          width:  radius * 2, height: radius * 2,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: _teal.withOpacity(0.5), width: 2),
            boxShadow: [BoxShadow(
                color: _teal.withOpacity(0.25), blurRadius: 12)]),
          child: ClipOval(child: Image.memory(bytes, fit: BoxFit.cover)));
      } catch (_) {}
    }
    return Container(
      width: radius * 2, height: radius * 2,
      decoration: BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_teal.withOpacity(0.4), _cyan.withOpacity(0.15)]),
        shape: BoxShape.circle,
        border: Border.all(color: _teal.withOpacity(0.55), width: 2),
        boxShadow: [BoxShadow(
            color: _teal.withOpacity(0.3), blurRadius: 14)]),
      child: Center(child: Text(auth.initials, style: TextStyle(
          color: Colors.white, fontSize: radius * 0.55,
          fontWeight: FontWeight.w800))));
  }
}

// ─────────────────────────────────────────────────────────────
// EditProfileScreen — ha Scaffold proprio (è una pushed page)
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
  bool      _loading = false;

  @override
  void initState() {
    super.initState();
    final account     = context.read<AuthProvider>().currentAccount;
    _firstNameCtrl    = TextEditingController(text: account?.firstName ?? '');
    _lastNameCtrl     = TextEditingController(text: account?.lastName  ?? '');
    _phoneCtrl        = TextEditingController(text: account?.phone     ?? '');
    _birthPlaceCtrl   = TextEditingController(text: account?.birthPlace ?? '');
    _bioCtrl          = TextEditingController(text: account?.bio        ?? '');
    if (account?.birthDate != null) {
      try { _selectedDate = DateTime.parse(account!.birthDate!); } catch (_) {}
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose(); _lastNameCtrl.dispose();
    _phoneCtrl.dispose();     _birthPlaceCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final b64 = await ImagePickerHelper.pickImageAsBase64();
      if (b64 == null) return;
      if (mounted) {
        await context.read<AuthProvider>().updateProfile(avatarBase64: b64);
        setState(() {});
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Impossibile caricare immagine: $e',
              style: const TextStyle(color: Colors.white)),
          backgroundColor: _red.withOpacity(0.85)));
      }
    }
  }

  Future<void> _pickDate() async {
    final now    = DateTime.now();
    final picked = await showDatePicker(
      context:     context,
      initialDate: _selectedDate ?? DateTime(now.year - 25),
      firstDate:   DateTime(1920),
      lastDate:    now,
      helpText:    'Data di nascita',
      builder: (ctx, child) => Theme(
        data: ThemeData.dark().copyWith(
          colorScheme: const ColorScheme.dark(primary: _teal)),
        child: child!));
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    await context.read<AuthProvider>().updateProfile(
      firstName:  _firstNameCtrl.text.trim().isEmpty ? null : _firstNameCtrl.text.trim(),
      lastName:   _lastNameCtrl.text.trim().isEmpty  ? null : _lastNameCtrl.text.trim(),
      phone:      _phoneCtrl.text.trim().isEmpty     ? null : _phoneCtrl.text.trim(),
      birthPlace: _birthPlaceCtrl.text.trim().isEmpty ? null : _birthPlaceCtrl.text.trim(),
      bio:        _bioCtrl.text.trim().isEmpty        ? null : _bioCtrl.text.trim(),
      birthDate:  _selectedDate?.toIso8601String().split('T')[0]);
    setState(() => _loading = false);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Profilo aggiornato!',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        backgroundColor: Color(0xFF0D1117),
        behavior: SnackBarBehavior.floating));
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth      = context.watch<AuthProvider>();
    final kbHeight  = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor:          Colors.transparent,
      resizeToAvoidBottomInset: false,
      body: CosmicBackground(
        child: SafeArea(
          child: Column(children: [

            // Glass AppBar
            ClipRect(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    border: Border(bottom: BorderSide(
                        color: _cyan.withOpacity(0.12), width: 0.6))),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.07),
                          borderRadius: BorderRadius.circular(11),
                          border: Border.all(
                              color: Colors.white.withOpacity(0.12), width: 0.7)),
                        child: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 15, color: Colors.white))),
                    const SizedBox(width: 12),
                    const Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                      Text('Modifica profilo', style: TextStyle(
                          color: Colors.white, fontSize: 17,
                          fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                      Text('Aggiorna i tuoi dati', style: TextStyle(
                          color: Color(0x66FFFFFF), fontSize: 11)),
                    ])),
                    // Salva button
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
                              colors: [_teal, _tealDk]),
                          color: _loading
                              ? Colors.white.withOpacity(0.05) : null,
                          borderRadius: BorderRadius.circular(11),
                          boxShadow: _loading ? null : [BoxShadow(
                              color: _teal.withOpacity(0.4), blurRadius: 10,
                              offset: const Offset(0, 3))]),
                        child: _loading
                            ? SizedBox(width: 14, height: 14,
                                child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: _teal.withOpacity(0.7)))
                            : const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.check_rounded,
                                    color: Colors.white, size: 15),
                                SizedBox(width: 5),
                                Text('Salva', style: TextStyle(
                                    color: Colors.white, fontSize: 12,
                                    fontWeight: FontWeight.w700)),
                              ]))),
                  ]))),
            ),

            // Form
            Expanded(
              child: GestureDetector(
                onTap: () => FocusScope.of(context).unfocus(),
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: EdgeInsets.fromLTRB(16, 16, 16, 32 + kbHeight),
                  child: Column(children: [

                    // Avatar section
                    _EditAvatarSection(auth: auth, onPick: _pickImage),
                    const SizedBox(height: 20),

                    // Dati personali
                    _GlassFormSection(title: 'Dati personali',
                        icon: Icons.person_rounded, color: _teal,
                        children: [
                      Row(children: [
                        Expanded(child: _GlassFormField(
                            controller: _firstNameCtrl, hint: 'Nome',
                            icon: Icons.person_outline_rounded, accent: _teal)),
                        const SizedBox(width: 10),
                        Expanded(child: _GlassFormField(
                            controller: _lastNameCtrl, hint: 'Cognome',
                            accent: _teal)),
                      ]),
                      const SizedBox(height: 10),
                      GestureDetector(
                        onTap: _pickDate,
                        child: _DateDisplayField(
                          date: _selectedDate,
                          hint: 'Data di nascita',
                          icon: Icons.cake_outlined)),
                      const SizedBox(height: 10),
                      _GlassFormField(
                          controller: _birthPlaceCtrl,
                          hint: 'Luogo di nascita',
                          icon: Icons.location_on_outlined,
                          accent: _indigo),
                      const SizedBox(height: 10),
                      _GlassFormField(
                          controller: _phoneCtrl,
                          hint: 'Telefono',
                          icon: Icons.phone_outlined,
                          keyboardType: TextInputType.phone,
                          accent: _green),
                    ]),
                    const SizedBox(height: 14),

                    // Bio
                    _GlassFormSection(title: 'Su di me',
                        icon: Icons.notes_rounded, color: _cyan,
                        children: [
                      _GlassFormField(
                          controller: _bioCtrl,
                          hint: 'Raccontati in poche parole...',
                          accent: _cyan, maxLines: 3),
                    ]),
                    const SizedBox(height: 24),

                    // Salva bottom
                    GestureDetector(
                      onTap: _loading ? null : _save,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width:   double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        decoration: BoxDecoration(
                          gradient: _loading ? null : const LinearGradient(
                              colors: [_teal, _tealDk]),
                          color: _loading
                              ? Colors.white.withOpacity(0.04) : null,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: _loading ? null : [BoxShadow(
                              color: _teal.withOpacity(0.4),
                              blurRadius: 16, offset: const Offset(0, 4))]),
                        child: _loading
                            ? Row(mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                SizedBox(width: 16, height: 16,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white.withOpacity(0.7))),
                                const SizedBox(width: 10),
                                const Text('Salvataggio...',
                                    style: TextStyle(color: Colors.white,
                                        fontSize: 15, fontWeight: FontWeight.w600)),
                              ])
                            : const Row(mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                Icon(Icons.update_rounded,
                                    color: Colors.white, size: 18),
                                SizedBox(width: 8),
                                Text('Salva modifiche',
                                    style: TextStyle(color: Colors.white,
                                        fontSize: 15, fontWeight: FontWeight.w700)),
                              ])),
                    ),
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
// _EditAvatarSection
// ─────────────────────────────────────────────────────────────

class _EditAvatarSection extends StatelessWidget {
  final AuthProvider auth;
  final VoidCallback onPick;
  const _EditAvatarSection({required this.auth, required this.onPick});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              Colors.white.withOpacity(0.07),
              Colors.white.withOpacity(0.02)]),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _cyan.withOpacity(0.15), width: 0.8)),
          child: Column(children: [
            GestureDetector(
              onTap: onPick,
              child: Stack(children: [
                AvatarWidget(auth: auth, radius: 46),
                Positioned(right: 0, bottom: 0,
                  child: Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                          colors: [_teal, _tealDk]),
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFF0A0A0E), width: 2)),
                    child: const Icon(Icons.camera_alt_rounded,
                        size: 14, color: Colors.white))),
              ])),
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              _AvatarBtn(
                icon: Icons.photo_library_outlined,
                label: 'Cambia foto', color: _teal, onTap: onPick),
              if (auth.avatarBase64 != null) ...[
                const SizedBox(width: 10),
                _AvatarBtn(
                  icon: Icons.delete_outline_rounded,
                  label: 'Rimuovi', color: _red,
                  onTap: () async {
                    await context.read<AuthProvider>().clearAvatar();
                  }),
              ],
            ]),
          ]))));
  }
}

class _AvatarBtn extends StatelessWidget {
  final IconData icon; final String label;
  final Color color; final VoidCallback onTap;
  const _AvatarBtn({required this.icon, required this.label,
      required this.color, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.3), width: 0.8)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(color: color, fontSize: 12,
            fontWeight: FontWeight.w600)),
      ])));
}

// ─────────────────────────────────────────────────────────────
// _GlassFormSection + _GlassFormField + _DateDisplayField
// ─────────────────────────────────────────────────────────────

class _GlassFormSection extends StatelessWidget {
  final String title; final IconData icon;
  final Color color; final List<Widget> children;
  const _GlassFormSection({
    required this.title, required this.icon,
    required this.color, required this.children});

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
            color: color.withOpacity(0.8), fontSize: 10,
            fontWeight: FontWeight.w800, letterSpacing: 1.2)),
      ]),
      const SizedBox(height: 10),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [
                Colors.white.withOpacity(0.07),
                Colors.white.withOpacity(0.02)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                  color: color.withOpacity(0.15), width: 0.8)),
            child: Column(children: children)))),
    ]);
  }
}

class _GlassFormField extends StatelessWidget {
  final TextEditingController controller;
  final String hint; final Color accent;
  final IconData? icon;
  final TextInputType keyboardType;
  final int maxLines;
  const _GlassFormField({
    required this.controller, required this.hint,
    required this.accent, this.icon,
    this.keyboardType = TextInputType.text, this.maxLines = 1});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.2), width: 0.8)),
        child: TextField(
          controller:         controller,
          maxLines:           maxLines,
          keyboardType:       keyboardType,
          keyboardAppearance: Brightness.dark,
          textCapitalization: TextCapitalization.sentences,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          decoration: InputDecoration(
            hintText:  hint,
            hintStyle: TextStyle(
                color: Colors.white.withOpacity(0.3), fontSize: 14),
            prefixIcon: icon != null
                ? Icon(icon, color: Colors.white.withOpacity(0.35), size: 17)
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 14, vertical: 12))))));
}

class _DateDisplayField extends StatelessWidget {
  final DateTime? date; final String hint; final IconData icon;
  const _DateDisplayField({required this.date, required this.hint,
      required this.icon});

  String _fmt(DateTime? d) {
    if (d == null) return '';
    return '${d.day.toString().padLeft(2,'0')}/'
        '${d.month.toString().padLeft(2,'0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(12),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _orange.withOpacity(0.2), width: 0.8)),
        child: Row(children: [
          Icon(icon, color: Colors.white.withOpacity(0.35), size: 17),
          const SizedBox(width: 10),
          Expanded(child: Text(
              date != null ? _fmt(date) : hint,
              style: TextStyle(
                  color: date != null
                      ? Colors.white : Colors.white.withOpacity(0.3),
                  fontSize: 14))),
          Icon(Icons.calendar_today_outlined,
              color: Colors.white.withOpacity(0.25), size: 15),
        ]))));
}