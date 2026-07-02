import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:xml/xml.dart';
import '../../models/sport_models.dart';
import '../../providers/sport_provider.dart';
import '../../widgets/glass_action_buttons.dart';
import '../../widgets/glass_card.dart';

class ActivityImportScreen extends StatefulWidget {
  const ActivityImportScreen({super.key});

  @override
  State<ActivityImportScreen> createState() => _ActivityImportScreenState();
}

class _ActivityImportScreenState extends State<ActivityImportScreen> {
  bool _loading = false;
  bool _importing = false;
  final List<_ParsedActivity> _preview = [];
  String? _error;

  Future<void> _pickAndParse() async {
    setState(() {
      _loading = true;
      _error = null;
      _preview.clear();
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: true,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _loading = false);
        return;
      }

      final parsed = <_ParsedActivity>[];
      for (final file in result.files) {
        final bytes = file.bytes;
        if (bytes == null) continue;

        String content;
        try {
          content = utf8.decode(bytes);
        } catch (_) {
          continue;
        }

        final ext = (file.extension ?? '').toLowerCase();
        _ParsedActivity? activity;

        if (ext == 'tcx') {
          activity = _parseTcx(content, file.name);
        } else if (ext == 'gpx') {
          activity = _parseGpx(content, file.name);
        } else if (ext == 'fit') {
          parsed.add(_ParsedActivity.unsupported(file.name));
          continue;
        }

        if (activity != null) parsed.add(activity);
      }

      setState(() {
        _preview.addAll(parsed);
        _loading = false;
        if (parsed.isEmpty) {
          _error = 'Nessun file TCX o GPX valido trovato.\n'
              'Su Garmin Connect: Attività → ⋮ → Esporta come TCX\n'
              'Su Suunto: Allenamento → Condividi → Esporta GPX';
        }
      });
    } catch (e) {
      setState(() {
        _error = 'Errore durante la lettura: $e';
        _loading = false;
      });
    }
  }

  _ParsedActivity? _parseTcx(String content, String fileName) {
    try {
      final doc = XmlDocument.parse(content);
      final activities = doc.findAllElements('Activity');
      if (activities.isEmpty) return null;

      final activity = activities.first;
      final sport = activity.getAttribute('Sport') ?? 'Other';
      final sportType = _mapSportType(sport);

      final idEl = activity.findElements('Id').firstOrNull;
      final startTime =
          idEl != null ? DateTime.tryParse(idEl.innerText) : null;

      int totalSeconds = 0;
      double totalMeters = 0;
      int hrSum = 0, hrCount = 0, hrMax = 0;

      for (final lap in activity.findAllElements('Lap')) {
        final lapTime = lap.findElements('TotalTimeSeconds').firstOrNull;
        final lapDist = lap.findElements('DistanceMeters').firstOrNull;
        if (lapTime != null) {
          totalSeconds +=
              (double.tryParse(lapTime.innerText) ?? 0).toInt();
        }
        if (lapDist != null) {
          totalMeters += double.tryParse(lapDist.innerText) ?? 0;
        }
        for (final hr in lap.findAllElements('AverageHeartRateBpm')) {
          final v = int.tryParse(
              hr.findElements('Value').firstOrNull?.innerText ?? '');
          if (v != null) {
            hrSum += v;
            hrCount++;
          }
        }
        for (final hr in lap.findAllElements('MaximumHeartRateBpm')) {
          final v = int.tryParse(
              hr.findElements('Value').firstOrNull?.innerText ?? '');
          if (v != null && v > hrMax) hrMax = v;
        }
      }

      return _ParsedActivity(
        fileName: fileName,
        sportType: sportType,
        startTime: startTime,
        durationSeconds: totalSeconds,
        distanceKm: totalMeters > 0 ? totalMeters / 1000 : null,
        hrAvg: hrCount > 0 ? (hrSum / hrCount).round() : null,
        hrMax: hrMax > 0 ? hrMax : null,
      );
    } catch (_) {
      return null;
    }
  }

  _ParsedActivity? _parseGpx(String content, String fileName) {
    try {
      final doc = XmlDocument.parse(content);
      final tracks = doc.findAllElements('trk');
      if (tracks.isEmpty) return null;

      final track = tracks.first;
      final name = track.findElements('name').firstOrNull?.innerText;
      final sportType = _mapSportType(name ?? '');

      final points = doc.findAllElements('trkpt').toList();
      if (points.isEmpty) return null;

      DateTime? startTime, endTime;
      double totalMeters = 0;
      double? prevLat, prevLon;

      for (final pt in points) {
        final lat = double.tryParse(pt.getAttribute('lat') ?? '');
        final lon = double.tryParse(pt.getAttribute('lon') ?? '');
        final timeEl = pt.findElements('time').firstOrNull;
        final t =
            timeEl != null ? DateTime.tryParse(timeEl.innerText) : null;

        if (t != null) {
          startTime ??= t;
          endTime = t;
        }
        if (lat != null && lon != null && prevLat != null && prevLon != null) {
          totalMeters += _haversineMeters(prevLat, prevLon, lat, lon);
        }
        prevLat = lat;
        prevLon = lon;
      }

      return _ParsedActivity(
        fileName: fileName,
        sportType: sportType,
        startTime: startTime,
        durationSeconds: (startTime != null && endTime != null)
            ? endTime.difference(startTime).inSeconds
            : 0,
        distanceKm: totalMeters > 0 ? totalMeters / 1000 : null,
      );
    } catch (_) {
      return null;
    }
  }

  SportType _mapSportType(String raw) {
    final r = raw.toLowerCase();
    if (r.contains('run') || r.contains('trail') || r.contains('corsa')) {
      return SportType.running;
    }
    if (r.contains('bik') || r.contains('cycl') || r.contains('ride') ||
        r.contains('cicl')) {
      return SportType.cycling;
    }
    if (r.contains('swim') || r.contains('nuot')) {
      return SportType.swimming;
    }
    if (r.contains('walk') || r.contains('cammin')) {
      return SportType.walking;
    }
    if (r.contains('hik') || r.contains('trek')) {
      return SportType.hiking;
    }
    return SportType.running;
  }

  // FIX ENCODING: la versione precedente usava nomi di variabile con
  // caratteri greci (φ, Δ, λ) che vengono corrotti dall'encoding
  // Windows (code page 850/1252) in caratteri illeggibili. Dart
  // non permette caratteri non-ASCII negli identificatori.
  // Sostituiti con nomi ASCII puri: lat1Rad, lat2Rad, dLat, dLon.
  double _haversineMeters(
      double lat1, double lon1, double lat2, double lon2) {
    const R = 6371000.0;
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1Rad) *
            math.cos(lat2Rad) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return 2 * R * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  Future<void> _importSelected() async {
    final toImport =
        _preview.where((a) => a.selected && !a.unsupported).toList();
    if (toImport.isEmpty) return;

    setState(() => _importing = true);
    final provider = context.read<SportProvider>();
    int count = 0;

    for (final a in toImport) {
      await provider.addSession(
        type: a.sportType!,
        durationSeconds: a.durationSeconds,
        distanceKm: a.distanceKm,
        notes: 'Importato da ${a.fileName}',
      );
      count++;
    }

    setState(() => _importing = false);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$count attività importate con successo')),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final selectedCount =
        _preview.where((a) => a.selected && !a.unsupported).length;

    return Scaffold(
      appBar: AppBar(title: const Text('Importa attività')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          GlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.info_outline, color: cs.primary, size: 18),
                  const SizedBox(width: 8),
                  Text('Come esportare i file',
                      style: TextStyle(
                          fontWeight: FontWeight.w700, color: cs.primary)),
                ]),
                const SizedBox(height: 8),
                Text(
                  '• Garmin Connect (app) → Attività → ⋮ → Esporta come TCX\n'
                  '• Suunto (app) → Allenamento → Condividi → Esporta GPX\n'
                  '• Polar (web) → Training Diary → Export TCX\n'
                  '• Coros (app) → Attività → Condividi → GPX',
                  style: TextStyle(
                      fontSize: 12, color: cs.onSurface, height: 1.6),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          GlassFilledButton(
            onPressed: _loading ? null : _pickAndParse,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.upload_file_rounded),
                const SizedBox(width: 8),
                Text(_loading
                    ? 'Lettura in corso...'
                    : 'Seleziona file TCX / GPX'),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.red.withOpacity(0.3)),
              ),
              child: Text(_error!,
                  style: const TextStyle(color: Colors.red, fontSize: 13)),
            ),
          ],
          if (_preview.isNotEmpty) ...[
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('${_preview.length} file trovati',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
                TextButton(
                  onPressed: () => setState(() {
                    for (final a in _preview) {
                      if (!a.unsupported) a.selected = !a.selected;
                    }
                  }),
                  child: const Text('Seleziona/deseleziona tutti'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ..._preview.asMap().entries.map((e) {
              final a = e.value;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: GlassCard(
                  padding: EdgeInsets.zero,
                  child: CheckboxListTile(
                    value: a.selected,
                    onChanged: a.unsupported
                        ? null
                        : (v) => setState(() => a.selected = v ?? false),
                    title: Text(a.label,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: a.unsupported ? cs.outline : null,
                        )),
                    subtitle: Text(a.subtitle,
                        style: TextStyle(
                            fontSize: 11,
                            color: a.unsupported
                                ? Colors.orange
                                : cs.outline)),
                    secondary: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: a.unsupported
                            ? Colors.orange.withOpacity(0.1)
                            : cs.primaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        a.unsupported
                            ? Icons.warning_outlined
                            : a.icon,
                        color: a.unsupported
                            ? Colors.orange
                            : cs.onPrimaryContainer,
                        size: 20,
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 16),
            GlassFilledButton(
              onPressed:
                  (_importing || selectedCount == 0) ? null : _importSelected,
              child: Text(
                _importing
                    ? 'Importazione in corso...'
                    : 'Importa $selectedCount attività',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ParsedActivity {
  final String fileName;
  final SportType? sportType;
  final DateTime? startTime;
  final int durationSeconds;
  final double? distanceKm;
  final int? hrAvg;
  final int? hrMax;
  final bool unsupported;
  bool selected;

  _ParsedActivity({
    required this.fileName,
    required this.sportType,
    required this.startTime,
    required this.durationSeconds,
    this.distanceKm,
    this.hrAvg,
    this.hrMax,
    this.unsupported = false,
    this.selected = true,
  });

  factory _ParsedActivity.unsupported(String fileName) => _ParsedActivity(
        fileName: fileName,
        sportType: null,
        startTime: null,
        durationSeconds: 0,
        unsupported: true,
        selected: false,
      );

  String get label {
    if (unsupported) return 'Formato non supportato: $fileName';
    final date = startTime != null
        ? '${startTime!.day}/${startTime!.month}/${startTime!.year}'
        : 'Data sconosciuta';
    return '${sportType?.label ?? 'Sport'} — $date';
  }

  String get subtitle {
    if (unsupported) {
      return 'File FIT: esporta come TCX o GPX dall\'app del dispositivo';
    }
    final parts = <String>[];
    if (durationSeconds > 0) {
      final m = durationSeconds ~/ 60;
      parts.add(m >= 60 ? '${m ~/ 60}h ${m % 60}min' : '${m}min');
    }
    if (distanceKm != null && distanceKm! > 0) {
      parts.add('${distanceKm!.toStringAsFixed(1)} km');
    }
    if (hrAvg != null) parts.add('FC: $hrAvg bpm');
    return parts.isEmpty ? fileName : parts.join(' · ');
  }

  IconData get icon {
    switch (sportType) {
      case SportType.running:  return Icons.directions_run;
      case SportType.cycling:  return Icons.directions_bike;
      case SportType.swimming: return Icons.pool;
      case SportType.walking:  return Icons.directions_walk;
      case SportType.hiking:   return Icons.terrain;
      default:                 return Icons.sports;
    }
  }
}