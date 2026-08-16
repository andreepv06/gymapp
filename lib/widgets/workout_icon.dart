import 'dart:io';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/markfit_colors.dart';

// ─────────────────────────────────────────────────────────────
// PALETTE LEGACY — backward compat (indici 0–7 dai dati vecchi)
// ─────────────────────────────────────────────────────────────
const List<Color> _kLegacyPalette = [
  Color(0xFF00D4AA), // 0
  Color(0xFF6366F1), // 1
  Color(0xFF22C55E), // 2
  Color(0xFFF59E0B), // 3
  Color(0xFFEC4899), // 4
  Color(0xFFEF4444), // 5
  Color(0xFF3B82F6), // 6
  Color(0xFF8B5CF6), // 7
];

// ─────────────────────────────────────────────────────────────
// PALETTE ESTESA
//
// Ampliata rispetto alla versione precedente con toni pastello
// chiari e toni scuri profondi, per offrire una selezione più
// ricca (standard, vivaci, scuri, chiari) come richiesto.
// L'ordine e i valori dei colori esistenti NON sono stati
// alterati: sono stati solo aggiunti nuovi valori in coda,
// quindi nessun mapping esistente viene rotto.
// ─────────────────────────────────────────────────────────────
const List<Color> kWorkoutPaletteExtended = [
  Color(0xFF00D4AA), Color(0xFF0FD9B4), Color(0xFF14B8A6), Color(0xFF10B981),
  Color(0xFF22C55E), Color(0xFF4ADE80), Color(0xFF84CC16), Color(0xFFA3E635),
  Color(0xFF06B6D4), Color(0xFF38BDF8), Color(0xFF0EA5E9), Color(0xFF60A5FA),
  Color(0xFF3B82F6), Color(0xFF2563EB), Color(0xFF1D4ED8), Color(0xFF3730A3),
  Color(0xFF6366F1), Color(0xFF8B5CF6), Color(0xFFA855F7), Color(0xFFD946EF),
  Color(0xFFEC4899), Color(0xFFF472B6), Color(0xFFF43F5E), Color(0xFFEF4444),
  Color(0xFFDC2626), Color(0xFFB91C1C),
  Color(0xFFF97316), Color(0xFFFB923C), Color(0xFFF59E0B), Color(0xFFEAB308),
  Color(0xFFD97706), Color(0xFFB45309),
  Color(0xFF64748B), Color(0xFF475569), Color(0xFF334155), Color(0xFF1E293B),
  // ── Toni pastello chiari (aggiunti) ──────────────────────
  Color(0xFFFFD3E0), Color(0xFFD1F2EB), Color(0xFFFFF3B0), Color(0xFFD0E8FF),
  // ── Toni scuri profondi (aggiunti) ───────────────────────
  Color(0xFF4A0E0E), Color(0xFF0B3D2E), Color(0xFF1B1B3A), Color(0xFF3D2645),
];

// ─────────────────────────────────────────────────────────────
// LIBRERIA ICONE ESTESA
//
// Ampliata con nuove icone tematiche fitness/sport (nessuna
// nuova dipendenza: solo Icons.* già inclusi in Flutter).
// Gli id e le icone esistenti non sono stati toccati.
// ─────────────────────────────────────────────────────────────
const List<(String, IconData)> kWorkoutIconLibrary = [
  ('dumbbell',      Icons.fitness_center_rounded),
  ('barbell',       Icons.sports_gymnastics_rounded),
  ('weight',        Icons.monitor_weight_rounded),
  ('flex',          Icons.back_hand_rounded),
  ('push',          Icons.arrow_upward_rounded),
  ('run',           Icons.directions_run_rounded),
  ('walk',          Icons.directions_walk_rounded),
  ('bike',          Icons.directions_bike_rounded),
  ('ebike',         Icons.electric_bike_rounded),
  ('swim',          Icons.pool_rounded),
  ('rowing',        Icons.rowing_rounded),
  ('skate',         Icons.ice_skating_rounded),
  ('sports',        Icons.sports_rounded),
  ('soccer',        Icons.sports_soccer_rounded),
  ('basketball',    Icons.sports_basketball_rounded),
  ('tennis',        Icons.sports_tennis_rounded),
  ('volleyball',    Icons.sports_volleyball_rounded),
  ('boxing',        Icons.sports_mma_rounded),
  ('martial_arts',  Icons.sports_kabaddi_rounded),
  ('golf',          Icons.sports_golf_rounded),
  ('yoga',          Icons.self_improvement_rounded),
  ('stretch',       Icons.emoji_people_rounded),
  ('meditation',    Icons.spa_rounded),
  ('accessibility', Icons.accessibility_new_rounded),
  ('heart',         Icons.favorite_rounded),
  ('heart_pulse',   Icons.monitor_heart_rounded),
  ('lungs',         Icons.air_rounded),
  ('health',        Icons.health_and_safety_rounded),
  ('flash',         Icons.bolt_rounded),
  ('speed',         Icons.speed_rounded),
  ('timer',         Icons.timer_rounded),
  ('loop',          Icons.loop_rounded),
  ('trending',      Icons.trending_up_rounded),
  ('repeat',        Icons.repeat_rounded),
  ('mountain',      Icons.terrain_rounded),
  ('nature',        Icons.nature_rounded),
  ('hiking',        Icons.hiking_rounded),
  ('park',          Icons.park_rounded),
  ('camp',          Icons.fireplace_rounded),
  ('target',        Icons.track_changes_rounded),
  ('flag',          Icons.flag_rounded),
  ('medal',         Icons.military_tech_rounded),
  ('trophy',        Icons.emoji_events_rounded),
  ('star',          Icons.star_rounded),
  ('crown',         Icons.workspace_premium_rounded),
  ('diamond',       Icons.diamond_rounded),
  ('grade',         Icons.grade_rounded),
  ('fire',          Icons.local_fire_department_rounded),
  ('rocket',        Icons.rocket_launch_rounded),
  ('electric',      Icons.electric_bolt_rounded),
  ('power',         Icons.power_rounded),
  ('chart',         Icons.bar_chart_rounded),
  ('calendar',      Icons.calendar_today_rounded),
  ('person',        Icons.person_rounded),
  ('group',         Icons.group_rounded),
  // ── Nuove icone aggiunte ──────────────────────────────────
  ('handball',      Icons.sports_handball_rounded),
  ('football',      Icons.sports_football_rounded),
  ('rugby',         Icons.sports_rugby_rounded),
  ('hockey',        Icons.sports_hockey_rounded),
  ('cricket',       Icons.sports_cricket_rounded),
  ('baseball',      Icons.sports_baseball_rounded),
  ('snowboard',     Icons.snowboarding_rounded),
  ('surf',          Icons.surfing_rounded),
  ('skateboard',    Icons.skateboarding_rounded),
  ('rollerskate',   Icons.roller_skating_rounded),
  ('kayak',         Icons.kayaking_rounded),
  ('ski',           Icons.downhill_skiing_rounded),
  ('nutrition',     Icons.restaurant_rounded),
  ('hydration',     Icons.local_drink_rounded),
  ('recovery',      Icons.bedtime_rounded),
  ('shower',        Icons.shower_rounded),
];

// ─────────────────────────────────────────────────────────────
// resolveWorkoutColor — PUNTO UNICO DI VERITÀ
//
// INVARIATO: gestisce sia i vecchi indici legacy (0-7) sia gli
// ARGB pieni (> 0xFFFF) salvati dal popup. Questo è il motivo
// per cui non esiste un bug di mapping tra selezione e salvataggio:
// il popup salva sempre color.value (ARGB pieno), che ricade
// sempre nel ramo `Color(value)`.
// ─────────────────────────────────────────────────────────────
Color resolveWorkoutColor(int? value) {
  if (value == null) return _kLegacyPalette.first;
  if (value >= 0 && value < _kLegacyPalette.length) {
    return _kLegacyPalette[value];
  }
  if (value > 0xFFFF) return Color(value);
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
// WorkoutAvatar — usa resolveWorkoutColor (PUNTO UNICO)
// customImagePath ripristinato per backward compat
// ─────────────────────────────────────────────────────────────
class WorkoutAvatar extends StatelessWidget {
  final String? iconId;
  final int?    iconColorIndex;
  final String? customImagePath;
  final double  size;
  final double  iconSize;
  final double  borderRadius;

  const WorkoutAvatar({
    super.key,
    this.iconId,
    this.iconColorIndex,
    this.customImagePath,
    this.size         = 48,
    this.iconSize     = 24,
    this.borderRadius = 14,
  });

  @override
  Widget build(BuildContext context) {
    final color    = resolveWorkoutColor(iconColorIndex);
    final iconData = resolveWorkoutIcon(iconId);
    final hasCustom = customImagePath != null &&
        customImagePath!.isNotEmpty;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width:  size,
        height: size,
        child: hasCustom
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
// showWorkoutIconColorSheet
//
// Punto unico di apertura del popup. Usa showModalBottomSheet
// direttamente (invece di passare per i wrapper generici
// _openSheet / showKeyboardSafeSheet usati altrove nell'app),
// perché questo popup ha bisogno di un layout a ALTEZZA FISSA
// con header/anteprima e footer/pulsanti ancorati e una sola
// area centrale scrollabile — cosa incompatibile con l'essere
// annidato in un SingleChildScrollView esterno.
//
// enableDrag: true (default) + isDismissible: true forniscono
// nativamente lo swipe-down-to-dismiss richiesto: se l'utente
// chiude trascinando verso il basso, `onSelect` NON viene mai
// invocato, quindi nessuna modifica temporanea viene salvata.
// ─────────────────────────────────────────────────────────────
Future<void> showWorkoutIconColorSheet(
  BuildContext context, {
  String? initialIconId,
  int? initialColorValue,
  required void Function(String iconId, int colorArgb) onSelect,
}) {
  return showModalBottomSheet<void>(
    context:            context,
    isScrollControlled: true,
    useSafeArea:        true,
    backgroundColor:    Colors.transparent,
    isDismissible:      true,
    enableDrag:         true,
    builder: (ctx) => WorkoutIconColorSheet(
      initialIconId:     initialIconId,
      initialColorValue: initialColorValue,
      onSelect:          onSelect,
    ),
  );
}

// ─────────────────────────────────────────────────────────────
// WorkoutIconColorSheet — componente condiviso
//
// LAYOUT (richiesto):
//   ┌ handle ─────────────────────────────┐
//   │ ANTEPRIMA (fissa)                    │
//   │ TAB Icona | Colore (fisso)           │
//   ├───────────────────────────────────────┤
//   │      AREA SCORRIBILE                  │
//   │  (griglia icone OPPURE griglia colori)│
//   ├───────────────────────────────────────┤
//   │  ANNULLA           APPLICA (fissi)    │
//   └───────────────────────────────────────┘
//
// STATO TEMPORANEO:
//   _iconId / _color sono inizializzati dai valori correnti
//   della scheda e modificati liberamente durante l'uso del
//   popup. Il valore definitivo cambia SOLO quando l'utente
//   preme "Applica" (viene chiamato widget.onSelect). Se preme
//   "Annulla" o chiude con swipe-down, il popup si chiude e
//   _iconId/_color vengono scartati senza alcuna chiamata a
//   onSelect: nessun salvataggio parziale/accidentale.
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

enum _IconColorTab { icon, color }

class _WorkoutIconColorSheetState extends State<WorkoutIconColorSheet> {
  late String   _iconId;
  late Color    _color;
  late HSVColor _hsv;
  bool          _showCustomPicker = false;
  _IconColorTab _tab              = _IconColorTab.icon;

  @override
  void initState() {
    super.initState();
    _iconId = widget.initialIconId ?? 'dumbbell';
    _color  = resolveWorkoutColor(widget.initialColorValue);
    _hsv    = HSVColor.fromColor(_color);
  }

  void _pickPaletteColor(Color c) {
    setState(() {
      _color            = c;
      _hsv              = HSVColor.fromColor(c);
      _showCustomPicker = false;
    });
  }

  // Applica: qui e SOLO qui il valore temporaneo diventa
  // definitivo, tramite la callback del chiamante.
  void _apply() {
    widget.onSelect(_iconId, _color.value);
  }

  @override
  Widget build(BuildContext context) {
    final c       = context.mfc;
    final isDark  = context.isDarkMode;

    // Stessa filosofia di opacità/blur di GlassSheetWrapper (usata
    // in tutto il resto dell'app): superficie OPACA (94-97%) +
    // BackdropFilter per la texture glass, in modo che il popup
    // non risulti mai trasparente al punto da rivelare la pagina
    // sottostante.
    final sheetBg = isDark
        ? const Color(0xEF060B14)
        : Colors.white.withOpacity(0.97);

    final maxHeight = MediaQuery.of(context).size.height * 0.86;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          constraints: BoxConstraints(maxHeight: maxHeight),
          decoration: BoxDecoration(
            color:        sheetBg,
            borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24)),
            border: Border.all(
                color: _color.withOpacity(0.3), width: 0.8),
            boxShadow: c.showElevation
                ? [BoxShadow(
                    color:      c.elevationColor,
                    blurRadius: 20,
                    offset:     const Offset(0, -2))]
                : null,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 12),
              _buildHandle(),
              const SizedBox(height: 16),
              _buildPreviewHeader(c),
              const SizedBox(height: 16),
              _buildTabSelector(c),
              const SizedBox(height: 8),
              Expanded(
                child: _tab == _IconColorTab.icon
                    ? _buildIconGrid(c)
                    : _buildColorContent(c),
              ),
              _buildFooter(c),
            ],
          ),
        ),
      ),
    );
  }

  // ── Handle (drag indicator) ─────────────────────────────────

  Widget _buildHandle() {
    return Center(
      child: Container(
        width:  40,
        height: 4,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            _color.withOpacity(0.3),
            _color.withOpacity(0.6),
            _color.withOpacity(0.3),
          ]),
          borderRadius: BorderRadius.circular(2),
          boxShadow: [
            BoxShadow(color: _color.withOpacity(0.3), blurRadius: 6),
          ],
        ),
      ),
    );
  }

  // ── Anteprima sempre visibile ───────────────────────────────

  Widget _buildPreviewHeader(MarkFitColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(children: [
        WorkoutAvatar(
          iconId:         _iconId,
          iconColorIndex: _color.value,
          size:           64,
          iconSize:       32,
          borderRadius:   16,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Icona e colore', style: TextStyle(
                  color:      c.textPrimary,
                  fontSize:   17,
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 3),
              Text('Anteprima aggiornata in tempo reale', style: TextStyle(
                  color: c.textTertiary, fontSize: 12)),
            ],
          ),
        ),
      ]),
    );
  }

  // ── Tab selector Icona / Colore ─────────────────────────────

  Widget _buildTabSelector(MarkFitColors c) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
          child: Container(
            height: 42,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: c.glassCardInset,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: c.glassBorder, width: 0.8),
            ),
            child: Row(children: [
              Expanded(child: _tabButton(
                  c, _IconColorTab.icon, 'Icona',
                  Icons.category_rounded)),
              Expanded(child: _tabButton(
                  c, _IconColorTab.color, 'Colore',
                  Icons.palette_rounded)),
            ]),
          ),
        ),
      ),
    );
  }

  Widget _tabButton(
      MarkFitColors c, _IconColorTab tab, String label, IconData icon) {
    final sel = _tab == tab;
    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _tab = tab);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: sel ? _color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(9),
          border: sel
              ? Border.all(color: _color.withOpacity(0.55), width: 1)
              : null,
          boxShadow: sel
              ? [BoxShadow(color: _color.withOpacity(0.2), blurRadius: 6)]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: sel ? _color : c.textTertiary),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(
                color:      sel ? _color : c.textTertiary,
                fontSize:   13,
                fontWeight: sel ? FontWeight.w700 : FontWeight.w500)),
          ],
        ),
      ),
    );
  }

  // ── Tab "Icona" — griglia scrollabile ───────────────────────

  Widget _buildIconGrid(MarkFitColors c) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Wrap(
        spacing:    10,
        runSpacing: 10,
        children: kWorkoutIconLibrary.map((icon) {
          final sel = _iconId == icon.$1;
          return GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _iconId = icon.$1);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width:  54,
              height: 54,
              decoration: BoxDecoration(
                color: sel ? _color.withOpacity(0.2) : c.glassCardInset,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: sel ? _color.withOpacity(0.75) : c.glassBorder,
                  width: sel ? 1.6 : 1,
                ),
                boxShadow: sel
                    ? [BoxShadow(
                        color:      _color.withOpacity(0.3),
                        blurRadius: 10)]
                    : null,
              ),
              child: Icon(icon.$2,
                  color: sel ? _color : c.iconSecondary, size: 24),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ── Tab "Colore" — palette + custom scrollabile ─────────────

  Widget _buildColorContent(MarkFitColors c) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing:    10,
            runSpacing: 10,
            children: [
              ...kWorkoutPaletteExtended.map((p) {
                final sel = !_showCustomPicker && _color.value == p.value;
                return GestureDetector(
                  onTap: () => _pickPaletteColor(p),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width:  44,
                    height: 44,
                    decoration: BoxDecoration(
                      color:  p,
                      shape:  BoxShape.circle,
                      border: sel
                          ? Border.all(color: Colors.white, width: 2.6)
                          : Border.all(
                              color: Colors.black.withOpacity(0.08),
                              width: 0.6),
                      boxShadow: sel
                          ? [BoxShadow(
                              color:      p.withOpacity(0.6),
                              blurRadius: 10)]
                          : null,
                    ),
                    child: sel
                        ? const Icon(Icons.check_rounded,
                            color: Colors.white, size: 18)
                        : null,
                  ),
                );
              }),
              // Colore personalizzato (rainbow) — architettura
              // preservata per eventuale estensione futura.
              GestureDetector(
                onTap: () => setState(
                    () => _showCustomPicker = !_showCustomPicker),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  width:  44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const SweepGradient(colors: [
                      Color(0xFFFF0000), Color(0xFFFF7F00),
                      Color(0xFFFFFF00), Color(0xFF00FF00),
                      Color(0xFF0000FF), Color(0xFF8B00FF),
                      Color(0xFFFF0000),
                    ]),
                    shape:  BoxShape.circle,
                    border: _showCustomPicker
                        ? Border.all(color: Colors.white, width: 2.6)
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
                    size:  18,
                  ),
                ),
              ),
            ],
          ),
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
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  // ── Footer sempre visibile: Annulla / Applica ───────────────

  Widget _buildFooter(MarkFitColors c) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 18),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: c.divider, width: 0.7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color:        c.glassCardInset,
                  borderRadius: BorderRadius.circular(14),
                  border:       Border.all(color: c.glassBorder),
                ),
                child: Text(
                  'Annulla',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:      c.textSecondary,
                    fontSize:   15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: _apply,
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    _color,
                    Color.lerp(_color, Colors.black, 0.2) ?? _color,
                  ]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color:      _color.withOpacity(0.4),
                      blurRadius: 14,
                      offset:     const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Text(
                  'Applica',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color:      Colors.white,
                    fontSize:   15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// _HsvPickerWidget — Color picker puro Flutter (no deps)
// INVARIATO
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
    canvas.drawRect(rect,
        Paint()
          ..shader = const LinearGradient(
            colors: [Colors.white, Colors.transparent],
          ).createShader(rect));
    canvas.drawRect(rect,
        Paint()
          ..shader = const LinearGradient(
            begin:  Alignment.topCenter,
            end:    Alignment.bottomCenter,
            colors: [Colors.transparent, Colors.black],
          ).createShader(rect));
    final cx = saturation * size.width;
    final cy = (1 - value) * size.height;
    canvas.drawCircle(Offset(cx, cy), 11,
        Paint()
          ..color       = Colors.white
          ..style       = PaintingStyle.stroke
          ..strokeWidth = 2.5);
    canvas.drawCircle(Offset(cx, cy), 9,
        Paint()
          ..color = HSVColor.fromAHSV(1, hue, saturation, value).toColor());
  }

  @override
  bool shouldRepaint(covariant _SatValPainter old) =>
      old.hue != hue || old.saturation != saturation || old.value != value;
}

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