import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/sport_models.dart';
import '../../providers/sport_provider.dart';
import '../../widgets/glass_action_buttons.dart';

/// Schermata generica per sport non-palestra. Architettura pensata
/// per essere riusata da qualsiasi sport futuro senza modifiche.
class SportSessionScreen extends StatefulWidget {
  final SportType sport;
  const SportSessionScreen({super.key, required this.sport});

  @override
  State<SportSessionScreen> createState() => _SportSessionScreenState();
}

class _SportSessionScreenState extends State<SportSessionScreen> {
  Timer? _timer;
  int _seconds = 0;
  bool _running = false;
  final _distanceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  void _toggle() {
    setState(() => _running = !_running);
    if (_running) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        setState(() => _seconds++);
      });
    } else {
      _timer?.cancel();
    }
  }

  Future<void> _save() async {
    _timer?.cancel();
    await context.read<SportProvider>().addSession(
          type: widget.sport,
          durationSeconds: _seconds,
          distanceKm: double.tryParse(_distanceCtrl.text.replaceAll(',', '.')),
          notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        );
    if (mounted) Navigator.pop(context);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _distanceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  String _fmt(int s) {
    final m = (s ~/ 60).toString().padLeft(2, '0');
    final sec = (s % 60).toString().padLeft(2, '0');
    return '$m:$sec';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.sport.label)),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Text(_fmt(_seconds),
                style: const TextStyle(fontSize: 56, fontWeight: FontWeight.w200)),
            const SizedBox(height: 24),
            GlassFilledButton(
              onPressed: _toggle,
              backgroundColor: _running ? Colors.red : cs.primary,
              child: Text(_running ? 'Pausa' : 'Avvia'),
            ),
            const Spacer(),
            TextField(
              controller: _distanceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Distanza (km, opzionale)'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Note (opzionale)'),
            ),
            const SizedBox(height: 20),
            GlassFilledButton(
              onPressed: _seconds > 0 ? _save : null,
              child: const Text('Salva sessione'),
            ),
          ],
        ),
      ),
    );
  }
}