import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/theme_provider.dart';
import '../../db/hive_database.dart';
import '../../providers/auth_provider.dart';

void _confirmLogout(BuildContext context) {
  showDialog(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Logout'),
      content: const Text('Vuoi uscire dall\'account?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annulla'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
              backgroundColor: Colors.red),
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

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(title: const Text('Impostazioni')),
      body: ListView(
        children: [
          // ASPETTO
          _SectionHeader(title: 'Aspetto'),
          Card(
            margin: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            elevation: 0,
            child: SwitchListTile(
              title: const Text('Tema scuro'),
              subtitle: const Text('Modalità notte'),
              secondary: Icon(
                themeProvider.isDark
                    ? Icons.dark_mode
                    : Icons.light_mode,
                color: Theme.of(context).colorScheme.primary,
              ),
              value: themeProvider.isDark,
              onChanged: (_) => themeProvider.toggle(),
            ),
          ),

          // DATI
          _SectionHeader(title: 'Dati'),
          Card(
            margin: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.delete_sweep_outlined,
                      color: Theme.of(context).colorScheme.error),
                  title: const Text('Elimina tutte le sessioni'),
                  subtitle: const Text(
                      'Rimuove lo storico allenamenti'),
                  onTap: () =>
                      _confirmDeleteSessions(context),
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: Icon(Icons.note_alt_outlined,
                      color: Theme.of(context).colorScheme.tertiary),
                  title: const Text('Elimina tutte le note'),
                  subtitle: const Text(
                      'Rimuove le note salvate per gli esercizi'),
                  onTap: () => _confirmDeleteNotes(context),
                ),
              ],
            ),
          ),

          // ACCOUNT
_SectionHeader(title: 'Account'),
Card(
  margin: const EdgeInsets.symmetric(
      horizontal: 16, vertical: 4),
  elevation: 0,
  child: Column(
    children: [
      ListTile(
        leading: Icon(Icons.person_outline,
            color: Theme.of(context).colorScheme.primary),
        title: const Text('Email'),
        trailing: Text(
          context.read<AuthProvider>().userEmail ?? '',
          style: TextStyle(
              color: Theme.of(context).colorScheme.outline),
        ),
      ),
      const Divider(height: 1, indent: 16),
      ListTile(
        leading: const Icon(Icons.logout, color: Colors.red),
        title: const Text('Logout',
            style: TextStyle(color: Colors.red)),
        onTap: () => _confirmLogout(context),
      ),
    ],
  ),
),

          // INFO
          _SectionHeader(title: 'Info'),
          Card(
            margin: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 4),
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: Icon(Icons.info_outline,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('Versione'),
                  trailing: Text('1.0.0',
                      style: TextStyle(
                          color:
                              Theme.of(context).colorScheme.outline)),
                ),
                const Divider(height: 1, indent: 16),
                ListTile(
                  leading: Icon(Icons.fitness_center,
                      color: Theme.of(context).colorScheme.primary),
                  title: const Text('GymApp'),
                  subtitle: const Text(
                      'Traccia i tuoi allenamenti'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  void _confirmDeleteSessions(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Elimina sessioni'),
        content: const Text(
            'Sei sicuro? Tutte le sessioni e i dati degli allenamenti verranno eliminati definitivamente.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
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
        content: const Text(
            'Sei sicuro? Tutte le note salvate per gli esercizi verranno eliminate.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annulla'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.red),
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

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 16, 6),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
            ),
      ),
    );
  }
}