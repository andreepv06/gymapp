import 'dart:io';
import 'package:flutter/material.dart';

import '../core/theme/markfit_colors.dart';
import 'shared_sheets.dart';

// ─────────────────────────────────────────────────────────────
// PALETTE LEGACY — backward compat (indici 0–7 dai dati vecchi)
// ─────────────────────────────────────────────────────────────
const List<Color> _kLegacyPalette = [
  Color(0xFF00D4AA), // 0 – teal
  Color(0xFF6366F1), // 1 – indigo
  Color(0xFF22C55E), // 2 – green
  Color(0xFFF59E0B), // 3 – amber
  Color(0xFFEC4899), // 4 – pink
  Color(0xFFEF4444), // 5 – red
  Color(0xFF3B82F6), // 6 – blue
  Color(0xFF8B5CF6), // 7 – purple
];

// ─────────────────────────────────────────────────────────────
// PALETTE ESTESA — nuova selezione colori
// Salvata come ARGB (color.value), non come indice.
// ─────────────────────────────────────────────────────────────
const List<Color> kWorkoutPaletteExtended = [
  // Verdi & teal
  Color(0xFF00D4AA), Color(0xFF0FD9B4), Color(0xFF14B8A6), Color(0xFF10B981),
  Color(0xFF22C55E), Color(0xFF4ADE80), Color(0xFF84CC16), Color(0xFFA3E635),
  // Blu & ciano
  Color(0xFF06B6D4), Color(0xFF38BDF8), Color(0xFF0EA5E9), Color(0xFF60A5FA),
  Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF3730A3),
  // Viola & indigo
  Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA855F7), Color(0xFFD946EF),
  // Rosa & rossi
  Color(0xFFEC4899), Color(0xFFF472B6), Color(0xFFF43F5E), Color(0xFFEF4444),
  Color(0xFFDC2626), Color(0xFFB91C1C),
  // Arancioni & gialli
  Color(0xFFF97316), Color(0xFFFB923C), Color(0xFFF59E0B), Color(0xFFEAB308),
  Color(0xFFD97706), Color(0xFFB45309),
  // Neutri
  Color(0xFF64748B), Color(0xFF475569), Color(0xFF334155), Color(0xFF1E293B),
];

// ─────────────────────────────────────────────────────────────
// LIBRERIA ICONE ESTESA (56 voci)
// ─────────────────────────────────────────────────────────────
const List<(String, IconData)> kWorkoutIconLibrary = [
  // Palestra & forza
  ('dumbbell',      Icons.fitness_center_rounded),
  ('barbell',       Icons.sports_gymnastics_rounded),
  ('weight',        Icons.monitor_weight_rounded),
  ('flex',          Icons.back_hand_rounded),
  ('push',          Icons.arrow_upward_rounded),
  // Cardio
  ('run',           Icons.directions_run_rounded),
  ('walk',          Icons.directions_walk_rounded),
  ('bike',          Icons.directions_bike_rounded),
  ('ebike',         Icons.electric_bike_rounded),
  ('swim',          Icons.pool_rounded),
  ('rowing',        Icons.rowing_rounded),
  ('skate',         Icons.ice_skating_rounded),
  // Sport
  ('sports',        Icons.sports_rounded),
  ('soccer',        Icons.sports_soccer_rounded),
  ('basketball',    Icons.sports_basketball_rounded),
  ('tennis',        Icons.sports_tennis_rounded),
  ('volleyball',    Icons.sports_volleyball_rounded),
  ('boxing',        Icons.sports_mma_rounded),
  ('martial_arts',  Icons.sports_kabaddi_rounded),
  ('golf',          Icons.sports_golf_rounded),
  // Yoga & corpo
  ('yoga',          Icons.self_improvement_rounded),
  ('stretch',       Icons.emoji_people_rounded),
  ('meditation',    Icons.spa_rounded),
  ('accessibility', Icons.accessibility_new_rounded),
  // Salute
  ('heart',         Icons.favorite_rounded),
  ('heart_pulse',   Icons.monitor_heart_rounded),
  ('lungs',         Icons.air_rounded),
  ('health',        Icons.health_and_safety_rounded),
  // Movimento & velocità
  ('flash',         Icons.bolt_rounded),
  ('speed',         Icons.speed_rounded),
  ('timer',         Icons.timer_rounded),
  ('loop',          Icons.loop_rounded),
  ('trending',      Icons.trending_up_rounded),
  ('repeat',        Icons.repeat_rounded),
  // Outdoor
  ('mountain',      Icons.terrain_rounded),
  ('nature',        Icons.nature_rounded),
  ('hiking',        Icons.hiking_rounded),
  ('park',          Icons.park_rounded),
  ('camp',          Icons.fireplace_rounded),
  // Achievement & obiettivi
  ('target',        Icons.track_changes_rounded),
  ('flag',          Icons.flag_rounded),
  ('medal',         Icons.military_tech_rounded),
  ('trophy',        Icons.emoji_events_rounded),
  ('star',          Icons.star_rounded),
  ('crown',         Icons.workspace_premium_rounded),
  ('diamond',       Icons.diamond_rounded),
  ('grade',         Icons.grade_rounded),
  // Energia & fuoco
  ('fire',          Icons.local_fire_department_rounded),
  ('rocket',        Icons.rocket_launch_rounded),
  ('electric',      Icons.electric_bolt_rounded),
  ('power',         Icons.power_rounded),
  // Altro
  ('chart',         Icons.bar_chart_rounded),
  ('calendar',      Icons.calendar_today_rounded),
  ('person',        Icons.person_rounded),
  ('group',         Icons.group_rounded),
];

// ─────────────────────────────────────────────────────────────
// resolveWorkoutColor — PUNTO UNICO DI VERITÀ
//
// Backward compat:
//   null           → teal default
//   0–7            → _kLegacyPalette[value]
//   > 0xFFFF       → Color(value) — ARGB diretto (dati nuovi)
//   8..0xFFFF      → fallback sicuro
// ─────────────────────────────────────────────────────────────
Color resolveWorkoutColor(int? value) {
  if (value == null) return _kLegacyPalette.first;
  if (value >= 0 && value < _kLegacyPalette.length) {
    return _kLegacyPalette[value];
  }
  if (value > 0xFFFF) {
    return Color(value);
  }
  return _kLegacyPalette.first;
}

// ─────────────────────────────────────────────────────────────
// resolveWorkoutIcon — fallback sicuro
// ─────────────────────────────────────────────────────────────
IconData resolveWorkoutIcon(String? iconId) {
  if (iconId == null || iconId.isEmpty) {
    return Icons.fitness_center_rounded;
  }
  try {
    return kWorkoutIconLibrary.firstWhere((e) => e.$1 == iconId).$2;
  } catch (_) {
    return Icons.fitness_center_rounded;
  }
}

// ─────────────────────────────────────────────────────────────
// WorkoutAvatar
//
// FIX: ripristinato customImagePath per backward compat con
//      history_screen, home_screen, allenamenti_screen.
//      Se customImagePath è non-null e il file esiste, viene
//      mostrata l'immagine custom al posto dell'icona.
// ─────────────────────────────────────────────────────────────
class WorkoutAvatar extends StatelessWidget {
  final String? iconId;
  final int?    iconColorIndex; // ARGB o indice legacy
  final String? customImagePath; // FIX: ripristinato
  final double  size;
  final double  iconSize;
  final double  borderRadius;

  const WorkoutAvatar({
    super.key,
    this.iconId,
    this.iconColorIndex,
    this.customImagePath,  // FIX: ripristinato
    this.size         = 48,
    this.iconSize     = 24,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final color    = resolveWorkoutColor(iconColorIndex);
    final iconData = resolveWorkoutIcon(iconId);

    // Se esiste un'immagine custom, la mostra
    final hasCustomImage = customImagePath != null &&
        customImagePath!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width:  size,
        height: size,
        child: hasCustomImage
            ? _buildCustomImage(color, iconData)
            : _buildIconAvatar(color, iconData),
      ),
    );
  }

  Widget _buildIconAvatar(Color color, IconData iconData) {
    return Container(
      width:  size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end:   Alignment.bottomRight,
          colors: [
            color,
            Color.lerp(color, Colors.black, 0.25) ?? color,
          ],
        ),
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color:      color.withOpacity(0.35),
            blurRadius: 10,
            offset:     const Offset(0, 4),
          ),
        ],
      ),
      child: Icon(iconData, color: Colors.white, size: iconSize),
    );
  }

  Widget _buildCustomImage(Color fallbackColor, IconData fallbackIcon) {
    // Prova a caricare l'immagine; in caso di errore usa l'icona
    try {
      final file = File(customImagePath!);
      return Container(
        width:  size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(borderRadius),
          boxShadow: [
            BoxShadow(
              color:      fallbackColor.withOpacity(0.3),
              blurRadius: 10,
              offset:     const Offset(0, 4),
            ),
          ],
        ),
        child: Image.file(
          file,
          fit:          BoxFit.cover,
          errorBuilder: (_, __, ___) =>
              _buildIconAvatar(fallbackColor, fallbackIcon),
        ),
      );
    } catch (_) {
      return _buildIconAvatar(fallbackColor, fallbackIcon);
    }
  }
}

// ─────────────────────────────────────────────────────────────
// WorkoutIconColorSheet — componente condiviso per la selezione
// di icona e colore. Usato da workouts_screen e workout_detail.
//
// Salva il colore come ARGB (color.value), non come indice.
// resolveWorkoutColor() garantisce backward compat per dati vecchi.
//
// Callback onSelect restituisce:
//   iconId    : String  – ID icona da kWorkoutIconLibrary
//   colorArgb : int     – color.value (ARGB da salvare in Hive)
// ─────────────────────────────────────────────────────────────
class WorkoutIconColorSheet extends StatefulWidget {
  final String? initialIconId;
  final int?    initialColorValue;
  final void Function(String iconId, int colorArgb) onSelect;

  const WorkoutIconColorSheet({
    super.key,
    this.initialIconId,
    this.initialColorValue,
    required this.onSelect,
  });

  @override
  State<WorkoutIconColorSheet> createState() =>
      _WorkoutIconColorSheetState();
}

class _WorkoutIconColorSheetState extends State<WorkoutIconColorSheet> {
  late String   _iconId;
  late Color    _color;
  late HSVColor _hsv;
  bool          _showCustomPicker = false;

  @override
  void initState() {
    super.initState();
    _iconId = widget.initialIconId ?? 'dumbbell';
    // FIX: usa resolveWorkoutColor (NO .clamp che corrompeva ARGB)
    _color = resolveWorkoutColor(widget.initialColorValue);
    _hsv   = HSVColor.fromColor(_color);
  }

  void _pickPaletteColor(Color c) {
    setState(() {
      _color            = c;
      _hsv              = HSVColor.fromColor(c);
      _showCustomPicker = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;

    return GlassSheetWrapper(
      title:       'Icona e colore',
      accentColor: _color,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Anteprima ────────────────────────────────────
          Center(
            child: Column(children: [
              WorkoutAvatar(
                iconId:         _iconId,
                // Passa ARGB → risolto correttamente da resolveWorkoutColor
                iconColorIndex: _color.value,
                size:           72,
                iconSize:       36,
                borderRadius:   18,
              ),
              const SizedBox(height: 6),
              Text('Anteprima', style: TextStyle(
                  color: c.textTertiary, fontSize: 11)),
            ]),
          ),
          const SizedBox(height: 20),

          // ── Sezione Colore ───────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Colore', style: TextStyle(
                color:        c.textSecondary,
                fontSize:     12,
                fontWeight:   FontWeight.w600,
                letterSpacing: 0.4)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing:    10,
            runSpacing: 10,
            children: [
              // Palette estesa
              ...kWorkoutPaletteExtended.map((p) {
                final sel = !_showCustomPicker &&
                    _color.value == p.value;
                return GestureDetector(
                  onTap: () => _pickPaletteColor(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width:  34,
                    height: 34,
                    decoration: BoxDecoration(
                      color:  p,
                      shape:  BoxShape.circle,
                      border: sel
                          ? Border.all(color: Colors.white, width: 2.5)
                          : null,
                      boxShadow: sel
                          ? [BoxShadow(
                              color:      p.withOpacity(0.6),
                              blurRadius: 10)]
                          : null,
                    ),
                    child: sel
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 16)
                        : null,
                  ),
                );
              }),
              // Pulsante colore personalizzato (rainbow)
              GestureDetector(
                onTap: () => setState(
                    () => _showCustomPicker = !_showCustomPicker),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width:  34,
                  height: 34,
                  decoration: BoxDecoration(
                    gradient: const SweepGradient(
                      colors: [
                        Color(0xFFFF0000), Color(0xFFFF7F00),
                        Color(0xFFFFFF00), Color(0xFF00FF00),
                        Color(0xFF0000FF), Color(0xFF8B00FF),
                        Color(0xFFFF0000),
                      ],
                    ),
                    shape:  BoxShape.circle,
                    border: _showCustomPicker
                        ? Border.all(color: Colors.white, width: 2.5)
                        : null,
                    boxShadow: _showCustomPicker
                        ? [BoxShadow(
                            color:      _color.withOpacity(0.5),
                            blurRadius: 10)]
                        : null,
                  ),
                  child: Icon(
                    _showCustomPicker
                        ? Icons.check_rounded
                        : Icons.colorize_rounded,
                    color: Colors.white,
                    size:  16,
                  ),
                ),
              ),
            ],
          ),

          // ── Custom picker inline ─────────────────────────
          AnimatedCrossFade(
            firstChild:  const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.only(top: 16),
              child: _HsvPickerWidget(
                hsv: _hsv,
                onChanged: (newHsv) => setState(() {
                  _hsv   = newHsv;
                  _color = newHsv.toColor();
                }),
              ),
            ),
            crossFadeState: _showCustomPicker
                ? CrossFadeState.showSecond
                : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),

          const SizedBox(height: 20),

          // ── Sezione Icona ────────────────────────────────
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Icona', style: TextStyle(
                color:        c.textSecondary,
                fontSize:     12,
                fontWeight:   FontWeight.w600,
                letterSpacing: 0.4)),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing:    8,
            runSpacing: 8,
            children: kWorkoutIconLibrary.map((icon) {
              final sel = _iconId == icon.$1;
              return GestureDetector(
                onTap: () => setState(() => _iconId = icon.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width:  48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: sel
                        ? _color.withOpacity(0.2)
                        : c.glassCardInset,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: sel
                          ? _color.withOpacity(0.7)
                          : c.glassBorder,
                      width: sel ? 1.5 : 1,
                    ),
                    boxShadow: sel
                        ? [BoxShadow(
                            color:      _color.withOpacity(0.25),
                            blurRadius: 8)]
                        : null,
                  ),
                  child: Icon(
                    icon.$2,
                    color: sel ? _color : c.iconSecondary,
                    size:  22,
                  ),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 22),
          GlassPrimaryButton(
            label: 'Applica',
            color: _color,
            // FIX: passa ARGB (color.value), non un indice
            onTap: () => widget.onSelect(_iconId, _color.value),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _HsvPickerWidget — Color picker puro Flutter (nessuna dep)
// ─────────────────────────────────────────────────────────────
class _HsvPickerWidget extends StatelessWidget {
  final HSVColor                hsv;
  final void Function(HSVColor) onChanged;
  const _HsvPickerWidget({required this.hsv, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return Column(
      children: [
        // SV selector 2D
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: LayoutBuilder(builder: (_, constraints) {
            const h = 180.0;
            final w = constraints.maxWidth;
            return GestureDetector(
              onPanUpdate: (d) => _updateSV(d.localPosition, w, h),
              onTapDown:   (d) => _updateSV(d.localPosition, w, h),
              child: CustomPaint(
                size: Size(w, h),
                painter: _SatValPainter(
                  hue:        hsv.hue,
                  saturation: hsv.saturation,
                  value:      hsv.value,
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),
        // Hue strip
        LayoutBuilder(builder: (_, constraints) {
          final w = constraints.maxWidth;
          return GestureDetector(
            onPanUpdate: (d) => _updateHue(d.localPosition.dx, w),
            onTapDown:   (d) => _updateHue(d.localPosition.dx, w),
            child: CustomPaint(
              size: Size(w, 30),
              painter: _HuePainter(hue: hsv.hue),
            ),
          );
        }),
        const SizedBox(height: 12),
        // Preview + hex
        Row(
          children: [
            Container(
              width:  50,
              height: 36,
              decoration: BoxDecoration(
                color:        hsv.toColor(),
                borderRadius: BorderRadius.circular(9),
                border: Border.all(color: c.glassBorder, width: 0.8),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '#${hsv.toColor().value.toRadixString(16).substring(2).toUpperCase()}',
              style: TextStyle(
                color:      c.textSecondary,
                fontSize:   13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _updateSV(Offset pos, double w, double h) {
    final s = (pos.dx / w).clamp(0.0, 1.0);
    final v = (1.0 - pos.dy / h).clamp(0.01, 1.0);
    onChanged(HSVColor.fromAHSV(1, hsv.hue, s, v));
  }

  void _updateHue(double dx, double w) {
    final hue = (dx / w * 360).clamp(0.0, 359.9);
    onChanged(HSVColor.fromAHSV(1, hue, hsv.saturation, hsv.value));
  }
}

// ─────────────────────────────────────────────────────────────
// CustomPainter — SV selector 2D
// ─────────────────────────────────────────────────────────────
class _SatValPainter extends CustomPainter {
  final double hue, saturation, value;
  const _SatValPainter({
    required this.hue,
    required this.saturation,
    required this.value,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    canvas.drawRect(rect,
        Paint()..color = HSVColor.fromAHSV(1, hue, 1, 1).toColor());

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          colors: [Colors.white, Colors.transparent],
        ).createShader(rect),
    );

    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin:  Alignment.topCenter,
          end:    Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );

    final cx = saturation * size.width;
    final cy = (1 - value) * size.height;

    canvas.drawCircle(
        Offset(cx, cy), 11,
        Paint()
          ..color       = Colors.white
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    canvas.drawCircle(
        Offset(cx, cy), 9,
        Paint()
          ..color = HSVColor.fromAHSV(1, hue, saturation, value).toColor());
  }

  @override
  bool shouldRepaint(covariant _SatValPainter old) =>
      old.hue != hue || old.saturation != saturation || old.value != value;
}

// ─────────────────────────────────────────────────────────────
// CustomPainter — Hue strip
// ─────────────────────────────────────────────────────────────
class _HuePainter extends CustomPainter {
  final double hue;
  const _HuePainter({required this.hue});

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;

    final colors = List<Color>.generate(
        7, (i) => HSVColor.fromAHSV(1, i * 60.0, 1, 1).toColor())
      ..add(HSVColor.fromAHSV(1, 0, 1, 1).toColor());

    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(6)),
      Paint()..shader = LinearGradient(colors: colors).createShader(rect),
    );

    final cx = (hue / 360) * size.width;
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, size.height / 2),
          width:  4,
          height: size.height + 4,
        ),
        const Radius.circular(2),
      ),
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _HuePainter old) => old.hue != hue;
}