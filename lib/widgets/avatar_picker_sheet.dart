import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../core/theme/markfit_colors.dart';
import '../providers/auth_provider.dart';
import '../services/image_picker_helper.dart';
import 'shared_sheets.dart';

// ─────────────────────────────────────────────────────────────
// showAvatarPickerSheet — FIX MODIFICA 1
//
// Punto UNICO condiviso per la gestione dell'immagine profilo,
// usato sia da Home (_ProfileAvatar) sia da Impostazioni
// (_ProfileCard / EditProfileScreen / _EditAvatar). Non esistono
// due sistemi separati: entrambe le UI leggono/scrivono
// esclusivamente AuthProvider.avatarBase64 tramite updateProfile/
// clearAvatar, quindi una modifica da un punto qualsiasi si
// riflette immediatamente ovunque (Provider + notifyListeners).
//
// Gestisce sempre: successo, annullamento (nessuna modifica,
// nessun errore mostrato), errore (immagine precedente
// conservata, loading terminato, messaggio leggibile).
// ─────────────────────────────────────────────────────────────
Future<void> showAvatarPickerSheet(BuildContext context) async {
  final auth = context.read<AuthProvider>();
  final hasAvatar =
      auth.avatarBase64 != null && auth.avatarBase64!.isNotEmpty;

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _AvatarPickerSheetContent(hasAvatar: hasAvatar),
  );
}

class _AvatarPickerSheetContent extends StatefulWidget {
  final bool hasAvatar;
  const _AvatarPickerSheetContent({required this.hasAvatar});

  @override
  State<_AvatarPickerSheetContent> createState() =>
      _AvatarPickerSheetContentState();
}

class _AvatarPickerSheetContentState
    extends State<_AvatarPickerSheetContent> {
  bool _loading = false;
  String? _error;

  Future<void> _pick(ImageSource source) async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final b64 = await ImagePickerHelper.pickImageAsBase64(source: source);
      if (b64 == null) {
        // Annullato dall'utente: nessuna modifica, nessun errore,
        // il loading termina comunque (Parte 5 del fix).
        if (mounted) setState(() => _loading = false);
        return;
      }
      if (!mounted) return;
      await context.read<AuthProvider>().updateProfile(avatarBase64: b64);
      if (!mounted) return;
      Navigator.pop(context);
    } catch (e) {
      // Errore: l'immagine precedente NON viene toccata (updateProfile
      // non è mai stato chiamato), il loading termina, messaggio mostrato.
      if (!mounted) return;
      final msg = e.toString().replaceAll('Exception: ', '');
      setState(() {
        _loading = false;
        _error = msg;
      });
    }
  }

  Future<void> _remove() async {
    if (_loading) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AuthProvider>().clearAvatar();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Impossibile rimuovere l\'immagine. Riprova.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return GlassSheetWrapper(
      title: 'Immagine profilo',
      subtitle: 'Aggiorna la tua foto',
      accentColor: MarkFitColors.teal,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: MarkFitColors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
                border:
                    Border.all(color: MarkFitColors.red.withOpacity(0.3)),
              ),
              child: Row(children: [
                const Icon(Icons.error_outline_rounded,
                    color: MarkFitColors.red, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_error!,
                      style: TextStyle(color: c.textPrimary, fontSize: 12)),
                ),
              ]),
            ),
            const SizedBox(height: 12),
          ],
          _OptionTile(
            icon: Icons.camera_alt_rounded,
            label: 'Scatta foto',
            color: MarkFitColors.teal,
            loading: _loading,
            onTap: () => _pick(ImageSource.camera),
          ),
          const SizedBox(height: 8),
          _OptionTile(
            icon: Icons.photo_library_outlined,
            label: 'Scegli dalla galleria',
            color: MarkFitColors.cyan,
            loading: _loading,
            onTap: () => _pick(ImageSource.gallery),
          ),
          if (widget.hasAvatar) ...[
            const SizedBox(height: 8),
            _OptionTile(
              icon: Icons.delete_outline_rounded,
              label: 'Rimuovi immagine',
              color: MarkFitColors.red,
              loading: _loading,
              onTap: _remove,
            ),
          ],
          if (_loading) ...[
            const SizedBox(height: 16),
            const Center(
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: MarkFitColors.teal),
              ),
            ),
          ],
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool loading;
  final VoidCallback onTap;
  const _OptionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.mfc;
    return GestureDetector(
      onTap: loading
          ? null
          : () {
              HapticFeedback.selectionClick();
              onTap();
            },
      child: Opacity(
        opacity: loading ? 0.5 : 1,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: c.glassBlur, sigmaY: c.glassBlur),
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: color.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: color.withOpacity(0.3), width: 0.8),
              ),
              child: Row(children: [
                Icon(icon, color: color, size: 19),
                const SizedBox(width: 12),
                Text(label,
                    style: TextStyle(
                        color: c.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600)),
              ]),
            ),
          ),
        ),
      ),
    );
  }
}