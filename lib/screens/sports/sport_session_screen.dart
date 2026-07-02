import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/navigation/app_router.dart';
import '../../models/sport_models.dart';
import '../../providers/sport_provider.dart';
import '../../widgets/glass_action_buttons.dart';
import 'sport_stats_screen.dart';

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
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final sec = s % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.sport.label),
        actions: [
          IconButton(
            tooltip: 'Statistiche',
            icon: const Icon(Icons.bar_chart_rounded),
            onPressed: () => pushPage(
              context,
              ChangeNotifierProvider.value(
                value: context.read<SportProvider>(),
                child: SportStatsScreen(sport: widget.sport),
              ),
            ),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Spacer(),
            Text(_fmt(_seconds),
                style: const TextStyle(
                    fontSize: 64,
                    fontWeight: FontWeight.w200,
                    fontFeatures: [FontFeature.tabularFigures()])),
            const SizedBox(height: 8),
            Text(widget.sport.label,
                style: TextStyle(fontSize: 16, color: cs.outline)),
            const SizedBox(height: 32),
            GlassFilledButton(
              onPressed: _toggle,
              backgroundColor: _running ? Colors.red : cs.primary,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_running ? Icons.pause_rounded : Icons.play_arrow_rounded),
                  const SizedBox(width: 8),
                  Text(_running ? 'Pausa' : (_seconds == 0 ? 'Avvia' : 'Riprendi')),
                ],
              ),
            ),
            const Spacer(),
            TextField(
              controller: _distanceCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Distanza (km, opzionale)',
                prefixIcon: Icon(Icons.straighten),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (opzionale)',
                prefixIcon: Icon(Icons.sticky_note_2_outlined),
              ),
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