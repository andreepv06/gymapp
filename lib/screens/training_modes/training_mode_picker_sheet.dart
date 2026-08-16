import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme/markfit_colors.dart';
import '../../models/training_mode.dart';
import '../../providers/training_mode_provider.dart';
import '../../widgets/shared_sheets.dart';

// ─────────────────────────────────────────────────────────────
// TrainingModePickerSheet — popup di sola SELEZIONE (Parte 13).
//
// La struttura di una modalità NON può essere modificata da qui:
// per creare/modificare modalità si usa la Gestione modalità
// (training_modes_screen.dart). Questo popup mostra ricerca,
// filtro categoria e la lista delle modalità disponibili, con
// evidenziazione di quella attualmente selezionata. Il tap su una
// voce seleziona e chiude immediatamente: la persistenza del
// valore scelto è responsabilità del chiamante (che tipicamente
// mantiene uno stato temporaneo, applicato solo al proprio
// salvataggio finale).
// ─────────────────────────────────────────────────────────────

const Map<String, String> _pickerCategoryLabels = {
  'fixed': 'Serie fisse',
  'range': 'Intervallo',
  'pyramid': 'Piramidale',
  'custom': 'Custom',
  'other': 'Altro',
};

String _pickerCategoryLabel(String cat) =>
    _pickerCategoryLabels[cat] ??
    (cat.isEmpty ? 'Altro' : '${cat[0].toUpperCase()}${cat.substring(1)}');

class TrainingModePickerSheet extends StatefulWidget {
  final dynamic currentModeKey;
  final void Function(TrainingMode mode) onSelect;
  const TrainingModePickerSheet({
    super.key,
    this.currentModeKey,
    required this.onSelect,
  });

  @override
  State<TrainingModePickerSheet> createState() =>
      _TrainingModePickerSheetState();
}

class _TrainingModePickerSheetState extends State<TrainingModePickerSheet> {
  String _search = '';
  String _category = 'Tutti';

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    final tp = context.watch<TrainingModeProvider>();
    final categories = <String>['Tutti', ...tp.availableCategories];
    final filtered = tp.search(_search, category: _category)
      ..sort((a, b) => a.name.compareTo(b.name));

    return GlassSheetWrapper(
      title: 'Seleziona modalità',
      subtitle: '${filtered.length} disponibili',
      accentColor: MarkFitColors.indigo,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassTextField(
            hintText: 'Cerca modalità...',
            onChanged: (v) => setState(() => _search = v),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, __) => const SizedBox(width: 6),
              itemBuilder: (_, i) {
                final cat = categories[i];
                final sel = _category == cat;
                final label =
                    cat == 'Tutti' ? 'Tutti' : _pickerCategoryLabel(cat);
                return GestureDetector(
                  onTap: () => setState(() => _category = cat),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 7),
                    decoration: BoxDecoration(
                      color: sel
                          ? MarkFitColors.indigo.withOpacity(0.18)
                          : c.glassCardInset,
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                          color: sel
                              ? MarkFitColors.indigo.withOpacity(0.55)
                              : c.glassBorder,
                          width: sel ? 1.2 : 0.8),
                    ),
                    child: Text(label, style: TextStyle(
                        color: sel ? MarkFitColors.indigo : c.textTertiary,
                        fontSize: 12,
                        fontWeight:
                            sel ? FontWeight.w700 : FontWeight.w500)),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 300,
            child: filtered.isEmpty
                ? Center(child: Text('Nessuna modalità trovata', style: TextStyle(
                    color: c.textTertiary,
                    fontSize: 13,
                    fontStyle: FontStyle.italic)))
                : ListView.builder(
                    physics: const BouncingScrollPhysics(),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) {
                      final m = filtered[i];
                      final isSel = widget.currentModeKey != null &&
                          m.key == widget.currentModeKey;
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 34, height: 34,
                          decoration: BoxDecoration(
                              color: MarkFitColors.indigo.withOpacity(0.12),
                              borderRadius: BorderRadius.circular(9)),
                          child: Icon(
                              m.isDefault
                                  ? Icons.star_rounded
                                  : Icons.fitness_center_rounded,
                              size: 17,
                              color: MarkFitColors.indigo),
                        ),
                        title: Text(m.name, style: TextStyle(
                            color: c.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                        subtitle: Text(
                            '${m.structureLabel} · '
                            '${_pickerCategoryLabel(m.category)}',
                            style: TextStyle(
                                color: c.textTertiary, fontSize: 11)),
                        trailing: isSel
                            ? const Icon(Icons.check_circle_rounded,
                                color: MarkFitColors.teal, size: 20)
                            : null,
                        onTap: () {
                          widget.onSelect(m);
                          Navigator.pop(context);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}