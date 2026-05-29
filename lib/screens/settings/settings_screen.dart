import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../db/hive_database.dart';
import '../../providers/auth_provider.dart';

// Import condizionale per web
import 'image_picker_helper.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Impostazioni'),
        backgroundColor: cs.surfaceContainerLowest,
      ),
      // FIX scroll: usa CustomScrollView con SliverList
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                _ProfileCard(auth: auth),
                const SizedBox(height: 24),

                _SectionLabel(title: 'Aspetto'),
                _SettingsCard(
                  children: [
                    _GlassThemeToggle(
                      isDark: themeProvider.isDark,
                      onToggle: themeProvider.toggle,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _SectionLabel(title: 'Dati'),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.delete_sweep_outlined,
                      iconColor: cs.error,
                      title: 'Elimina sessioni',
                      subtitle: 'Rimuove lo storico allenamenti',
                      onTap: () => _confirmDeleteSessions(context),
                    ),
                    const _Divider(),
                    _SettingsTile(
                      icon: Icons.note_alt_outlined,
                      iconColor: cs.tertiary,
                      title: 'Elimina note',
                      subtitle: 'Rimuove le note degli esercizi',
                      onTap: () => _confirmDeleteNotes(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _SectionLabel(title: 'Account'),
                _SettingsCard(
                  children: [
                    if (auth.accounts.length > 1) ...[
                      _SettingsTile(
                        icon: Icons.switch_account_outlined,
                        iconColor: cs.primary,
                        title: 'Cambia account',
                        subtitle:
                            '${auth.accounts.length} account salvati',
                        onTap: () => _showSwitchAccount(context),
                      ),
                      const _Divider(),
                    ],
                    _SettingsTile(
                      icon: Icons.logout,
                      iconColor: Colors.red,
                      title: 'Logout',
                      titleColor: Colors.red,
                      onTap: () => _confirmLogout(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                _SectionLabel(title: 'Info'),
                _SettingsCard(
                  children: [
                    _SettingsTile(
                      icon: Icons.info_outline,
                      iconColor: cs.primary,
                      title: 'Versione',
                      trailing: Text('1.0.0',
                          style:
                              TextStyle(color: cs.outline, fontSize: 13)),
                    ),
                    const _Divider(),
                    _SettingsTile(
                      icon: Icons.fitness_center,
                      iconColor: cs.primary,
                      title: 'MarkFit',
                      subtitle: 'Traccia i tuoi allenamenti',
                    ),
                  ],
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Vuoi uscire dall\'account?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              context.read<AuthProvider>().logout();
              Navigator.pop(context);
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  void _showSwitchAccount(BuildContext context) {
    final auth = context.read<AuthProvider>();
    showModalBottomSheet(
      context: context,
      builder: (_) => _SwitchAccountSheet(auth: auth),
    );
  }

  void _confirmDeleteSessions(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina sessioni'),
        content: const Text(
            'Sei sicuro? Tutte le sessioni verranno eliminate.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await HiveDatabase.instance.deleteAllSessions();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sessioni eliminate')),
                );
              }
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }

  void _confirmDeleteNotes(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina note'),
        content:
            const Text('Sei sicuro? Tutte le note verranno eliminate.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Annulla')),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              await HiveDatabase.instance.deleteAllNotes();
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Note eliminate')),
                );
              }
            },
            child: const Text('Elimina'),
          ),
        ],
      ),
    );
  }
}

// ---- Profile Card ----

class _ProfileCard extends StatelessWidget {
  final AuthProvider auth;
  const _ProfileCard({required this.auth});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final account = auth.currentAccount;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [cs.primaryContainer, cs.secondaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => _showEditProfile(context),
                child: Stack(
                  children: [
                    AvatarWidget(auth: auth, radius: 36),
                    Positioned(
                      right: 0,
                      bottom: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          color: cs.primary,
                          shape: BoxShape.circle,
                          border:
                              Border.all(color: cs.surface, width: 2),
                        ),
                        child: const Icon(Icons.edit,
                            size: 12, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account?.fullName ?? auth.currentIdentifier ?? '',
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cs.onPrimaryContainer,
                          ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (account?.bio != null && account!.bio!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        account.bio!,
                        style: TextStyle(
                            fontSize: 13,
                            color: cs.onPrimaryContainer.withOpacity(0.75)),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 2),
                    Text(
                      auth.currentIdentifier ?? '',
                      style: TextStyle(
                          fontSize: 12,
                          color: cs.onPrimaryContainer.withOpacity(0.65)),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),

          if (account != null &&
              (account.firstName != null ||
                  account.birthDate != null ||
                  account.phone != null)) ...[
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                if (account.firstName != null)
                  _ProfileChip(
                      icon: Icons.person,
                      label:
                          '${account.firstName} ${account.lastName ?? ''}'),
                if (account.birthDate != null)
                  _ProfileChip(
                      icon: Icons.cake_outlined,
                      label: account.birthDate!),
                if (account.phone != null)
                  _ProfileChip(
                      icon: Icons.phone_outlined, label: account.phone!),
                if (account.birthPlace != null)
                  _ProfileChip(
                      icon: Icons.location_on_outlined,
                      label: account.birthPlace!),
              ],
            ),
          ],

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () => _showEditProfile(context),
              icon: const Icon(Icons.edit_outlined, size: 16),
              label: const Text('Modifica profilo'),
              style: OutlinedButton.styleFrom(
                foregroundColor: cs.onPrimaryContainer,
                side: BorderSide(
                    color: cs.onPrimaryContainer.withOpacity(0.4)),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
                padding: const EdgeInsets.symmetric(vertical: 10),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showEditProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChangeNotifierProvider.value(
          value: context.read<AuthProvider>(),
          child: const EditProfileScreen(),
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ProfileChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: cs.surface.withOpacity(0.6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: cs.onSurface.withOpacity(0.7)),
          const SizedBox(width: 4),
          Text(label.trim(),
              style: TextStyle(
                  fontSize: 11, color: cs.onSurface.withOpacity(0.85))),
        ],
      ),
    );
  }
}

// ---- Avatar Widget (pubblico per Edit Profile) ----

class AvatarWidget extends StatelessWidget {
  final AuthProvider auth;
  final double radius;
  const AvatarWidget({super.key, required this.auth, required this.radius});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final avatarB64 = auth.avatarBase64;

    if (avatarB64 != null && avatarB64.isNotEmpty) {
      try {
        final bytes = base64Decode(avatarB64);
        return CircleAvatar(
          radius: radius,
          backgroundImage: MemoryImage(bytes),
        );
      } catch (_) {}
    }

    return CircleAvatar(
      radius: radius,
      backgroundColor: cs.primary,
      child: Text(
        auth.initials,
        style: TextStyle(
          fontSize: radius * 0.55,
          fontWeight: FontWeight.w700,
          color: cs.onPrimary,
        ),
      ),
    );
  }
}

// ---- Edit Profile Screen ----

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
    final account = context.read<AuthProvider>().currentAccount;
    _firstNameCtrl = TextEditingController(text: account?.firstName ?? '');
    _lastNameCtrl = TextEditingController(text: account?.lastName ?? '');
    _phoneCtrl = TextEditingController(text: account?.phone ?? '');
    _birthPlaceCtrl = TextEditingController(text: account?.birthPlace ?? '');
    _bioCtrl = TextEditingController(text: account?.bio ?? '');

    if (account?.birthDate != null) {
      try {
        _selectedDate = DateTime.parse(account!.birthDate!);
      } catch (_) {}
    }
  }

  @override
  void dispose() {
    _firstNameCtrl.dispose();
    _lastNameCtrl.dispose();
    _phoneCtrl.dispose();
    _birthPlaceCtrl.dispose();
    _bioCtrl.dispose();
    super.dispose();
  }

  // FIX immagine: usa helper che funziona su web con dart:html
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Impossibile caricare immagine: $e')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate:
          _selectedDate ?? DateTime(now.year - 25, now.month, now.day),
      firstDate: DateTime(1920),
      lastDate: now,
      helpText: 'Data di nascita',
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    await context.read<AuthProvider>().updateProfile(
          firstName: _firstNameCtrl.text.trim().isEmpty
              ? null
              : _firstNameCtrl.text.trim(),
          lastName: _lastNameCtrl.text.trim().isEmpty
              ? null
              : _lastNameCtrl.text.trim(),
          phone: _phoneCtrl.text.trim().isEmpty
              ? null
              : _phoneCtrl.text.trim(),
          birthPlace: _birthPlaceCtrl.text.trim().isEmpty
              ? null
              : _birthPlaceCtrl.text.trim(),
          bio: _bioCtrl.text.trim().isEmpty ? null : _bioCtrl.text.trim(),
          birthDate: _selectedDate?.toIso8601String().split('T')[0],
        );
    setState(() => _loading = false);
    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profilo aggiornato!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: const Text('Modifica profilo'),
        backgroundColor: cs.surface,
        actions: [
          TextButton(
            onPressed: _loading ? null : _save,
            child: _loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Text('Salva',
                    style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Center(
              child: Column(
                children: [
                  GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        AvatarWidget(auth: auth, radius: 52),
                        Positioned(
                          right: 0,
                          bottom: 0,
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: cs.primary,
                              shape: BoxShape.circle,
                              border:
                                  Border.all(color: cs.surface, width: 2),
                            ),
                            child: const Icon(Icons.camera_alt,
                                size: 16, color: Colors.white),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _pickImage,
                    icon: const Icon(Icons.photo_library_outlined, size: 16),
                    label: const Text('Cambia foto'),
                  ),
                  if (auth.avatarBase64 != null)
                    TextButton.icon(
                      onPressed: () async {
                        await auth.clearAvatar();
                        setState(() {});
                      },
                      icon: const Icon(Icons.delete_outline,
                          size: 16, color: Colors.red),
                      label: const Text('Rimuovi foto',
                          style: TextStyle(color: Colors.red)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 28),

            _FormSection(
              title: 'Dati personali',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _firstNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Nome',
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _lastNameCtrl,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          labelText: 'Cognome',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                GestureDetector(
                  onTap: _pickDate,
                  child: AbsorbPointer(
                    child: TextFormField(
                      decoration: InputDecoration(
                        labelText: 'Data di nascita',
                        prefixIcon: const Icon(Icons.cake_outlined),
                        hintText: 'Seleziona data',
                        suffixIcon: const Icon(
                            Icons.calendar_today_outlined,
                            size: 18),
                      ),
                      controller: TextEditingController(
                        text: _selectedDate != null
                            ? '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}'
                            : '',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _birthPlaceCtrl,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Luogo di nascita',
                    prefixIcon: Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numero di telefono',
                    prefixIcon: Icon(Icons.phone_outlined),
                    hintText: '+39 000 000 0000',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            _FormSection(
              title: 'Su di me',
              children: [
                TextFormField(
                  controller: _bioCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Bio',
                    hintText: 'Raccontati in poche parole...',
                    alignLabelWithHint: true,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _loading ? null : _save,
                child: _loading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white))
                    : const Text('Salva modifiche'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---- Switch Account Sheet ----

class _SwitchAccountSheet extends StatelessWidget {
  final AuthProvider auth;
  const _SwitchAccountSheet({required this.auth});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                  color: cs.outlineVariant,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 16),
          Text('Seleziona account',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          ...auth.accounts.map((a) {
            final isCurrent = a.identifier == auth.currentIdentifier;
            return ListTile(
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                backgroundColor: isCurrent
                    ? cs.primaryContainer
                    : cs.surfaceContainerHighest,
                child: Text(a.initials,
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isCurrent
                            ? cs.onPrimaryContainer
                            : cs.onSurface)),
              ),
              title: Text(a.displayName ?? a.identifier,
                  style: TextStyle(
                      fontWeight: isCurrent
                          ? FontWeight.w700
                          : FontWeight.normal)),
              subtitle: Text(a.identifier,
                  style: TextStyle(color: cs.outline, fontSize: 12)),
              trailing: isCurrent
                  ? Icon(Icons.check_circle, color: cs.primary)
                  : null,
              onTap: isCurrent
                  ? null
                  : () {
                      Navigator.pop(context);
                      _switchTo(context, a);
                    },
            );
          }),
        ],
      ),
    );
  }

  void _switchTo(BuildContext context, UserAccount account) {
    final pwCtrl = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Accedi come ${account.identifier}',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: pwCtrl,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Password'),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () async {
                  final error = await ctx.read<AuthProvider>().login(
                        identifier: account.identifier,
                        password: pwCtrl.text,
                      );
                  if (error != null) {
                    if (ctx.mounted) {
                      ScaffoldMessenger.of(ctx).showSnackBar(
                          SnackBar(content: Text(error)));
                    }
                  } else {
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
                child: const Text('Accedi'),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ---- Helper Widgets ----

class _FormSection extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _FormSection({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  letterSpacing: 1.2,
                  color: cs.primary,
                  fontWeight: FontWeight.w700,
                )),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cs.surfaceContainer,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children),
        ),
      ],
    );
  }
}

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(children: children),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    this.titleColor,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: iconColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(title,
          style: TextStyle(
              fontWeight: FontWeight.w500, color: titleColor)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: TextStyle(fontSize: 12, color: cs.outline))
          : null,
      trailing: trailing ??
          (onTap != null
              ? Icon(Icons.chevron_right, color: cs.outline, size: 20)
              : null),
      onTap: onTap,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 56,
      color: Theme.of(context).colorScheme.outlineVariant,
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String title;
  const _SectionLabel({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 0, 0, 8),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
      ),
    );
  }
}
class _GlassThemeToggle extends StatelessWidget {
  final bool isDark;
  final VoidCallback onToggle;

  const _GlassThemeToggle({required this.isDark, required this.onToggle});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    // Tema chiaro: sfondo primary (viola) → testo onPrimary (bianco) ✓
    // Tema scuro: sfondo quasi nero → testo bianco ✓
    final baseColor = isDark ? const Color(0xFF2A2A2E) : cs.primary;
    final fgColor = Colors.white; // sempre bianco su entrambi i fondali
    final fgSubColor = Colors.white.withOpacity(0.7);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.white.withOpacity(0.3);
    final iconBg = Colors.white.withOpacity(isDark ? 0.1 : 0.2);

    return Padding(
      padding: const EdgeInsets.all(4),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: GestureDetector(
            onTap: onToggle,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor, width: 1),
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withOpacity(isDark ? 0.05 : 0.15),
                    Colors.transparent,
                  ],
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: iconBg,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isDark ? Icons.dark_mode : Icons.light_mode_outlined,
                      color: fgColor,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tema',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: fgColor,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          isDark ? 'Modalità scura' : 'Modalità chiara',
                          style: TextStyle(fontSize: 12, color: fgSubColor),
                        ),
                      ],
                    ),
                  ),
                  // Toggle pill
                  Container(
                    width: 52,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                          color: Colors.white.withOpacity(0.3), width: 1),
                    ),
                    child: AnimatedAlign(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeInOut,
                      alignment: isDark
                          ? Alignment.centerRight
                          : Alignment.centerLeft,
                      child: Container(
                        width: 22,
                        height: 22,
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Icon(
                          isDark ? Icons.dark_mode : Icons.light_mode,
                          size: 12,
                          color: baseColor,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
