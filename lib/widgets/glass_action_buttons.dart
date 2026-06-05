import 'dart:ui';
import 'package:flutter/material.dart';

class GlassOutlinedButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? foregroundColor;
  final Color? borderColor;

  const GlassOutlinedButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.foregroundColor,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final fg = foregroundColor ?? cs.primary;
    final border = borderColor ??
        (isDark ? Colors.white.withOpacity(0.18) : cs.outlineVariant);

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDark
                    ? Colors.white.withOpacity(0.06)
                    : fg.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: border, width: 1.2),
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: onPressed == null
                      ? cs.onSurface.withOpacity(0.38)
                      : fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                child: IconTheme(
                  data: IconThemeData(
                    color: onPressed == null
                        ? cs.onSurface.withOpacity(0.38)
                        : fg,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassFilledButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const GlassFilledButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = backgroundColor ?? cs.primary;
    final fg = foregroundColor ?? cs.onPrimary;
    final isDisabled = onPressed == null;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(12),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              height: 50,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: isDisabled ? cs.onSurface.withOpacity(0.12) : bg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDisabled
                      ? Colors.transparent
                      : Colors.white.withOpacity(isDark ? 0.12 : 0.3),
                  width: 1,
                ),
                gradient: isDisabled
                    ? null
                    : LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.white.withOpacity(0.15),
                          Colors.transparent,
                        ],
                      ),
                boxShadow: isDisabled
                    ? null
                    : [
                        BoxShadow(
                          color: bg.withOpacity(0.35),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: DefaultTextStyle(
                style: TextStyle(
                  color: isDisabled
                      ? cs.onSurface.withOpacity(0.38)
                      : fg,
                  fontWeight: FontWeight.w600,
                  fontSize: 15,
                ),
                child: IconTheme(
                  data: IconThemeData(
                    color: isDisabled
                        ? cs.onSurface.withOpacity(0.38)
                        : fg,
                  ),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GlassTextButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final Widget child;
  final Color? foregroundColor;
  final EdgeInsetsGeometry padding;

  const GlassTextButton({
    super.key,
    required this.onPressed,
    required this.child,
    this.foregroundColor,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fg = foregroundColor ?? cs.primary;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: padding,
          child: DefaultTextStyle(
            style: TextStyle(
              color:
                  onPressed == null ? cs.onSurface.withOpacity(0.38) : fg,
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            child: IconTheme(
              data: IconThemeData(
                color: onPressed == null
                    ? cs.onSurface.withOpacity(0.38)
                    : fg,
                size: 18,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class GlassDialogActions extends StatelessWidget {
  final String cancelLabel;
  final String confirmLabel;
  final VoidCallback? onCancel;
  final VoidCallback? onConfirm;
  final Color? confirmColor;
  final bool isLoading;

  const GlassDialogActions({
    super.key,
    this.cancelLabel = 'Annulla',
    this.confirmLabel = 'Conferma',
    this.onCancel,
    this.onConfirm,
    this.confirmColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final confirmBg = confirmColor ?? cs.primary;

    return Row(
      children: [
        Expanded(
          child: GlassOutlinedButton(
            onPressed: onCancel ?? () => Navigator.pop(context),
            child: Text(cancelLabel),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GlassFilledButton(
            onPressed: isLoading ? null : onConfirm,
            backgroundColor: confirmBg,
            child: isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.5, color: cs.onPrimary),
                  )
                : Text(confirmLabel),
          ),
        ),
      ],
    );
  }
}

class GlassSheetHandle extends StatelessWidget {
  const GlassSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: Theme.of(context)
              .colorScheme
              .outlineVariant
              .withOpacity(0.7),
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}