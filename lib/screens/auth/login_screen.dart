import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  final VoidCallback onLoginSuccess;
  const LoginScreen({super.key, required this.onLoginSuccess});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  bool _obscure = true;
  bool _loading = false;
  bool _isRegister = false;
  String? _error;

  @override
  void dispose() {
    _identifierCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final auth = context.read<AuthProvider>();
    String? error;

    if (_isRegister) {
      error = await auth.register(
        identifier: _identifierCtrl.text,
        password: _passwordCtrl.text,
      );
    } else {
      error = await auth.login(
        identifier: _identifierCtrl.text,
        password: _passwordCtrl.text,
      );
    }

    if (error != null) {
      setState(() {
        _error = error;
        _loading = false;
      });
      return;
    }

    widget.onLoginSuccess();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        children: [
          // Sfondo con gradiente
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [
                        const Color(0xFF0D0D1A),
                        const Color(0xFF1A1025),
                        const Color(0xFF0D1A1A),
                      ]
                    : [
                        cs.primary.withOpacity(0.15),
                        cs.secondary.withOpacity(0.1),
                        cs.tertiary.withOpacity(0.08),
                      ],
              ),
            ),
          ),

          // Cerchi decorativi sfocati
          Positioned(
            top: -80,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.primary.withOpacity(isDark ? 0.15 : 0.12),
              ),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -40,
            child: Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.secondary.withOpacity(isDark ? 0.12 : 0.1),
              ),
            ),
          ),
          Positioned(
            top: 200,
            left: -80,
            child: Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.tertiary.withOpacity(isDark ? 0.08 : 0.07),
              ),
            ),
          ),

          // Contenuto
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 32),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Logo glass
                      _GlassLogo(cs: cs, isDark: isDark),
                      const SizedBox(height: 32),

                      // Card glass principale
                      _GlassCard(
                        isDark: isDark,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Titolo
                              AnimatedSwitcher(
                                duration: const Duration(milliseconds: 200),
                                child: Column(
                                  key: ValueKey(_isRegister),
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isRegister ? 'Crea account' : 'Bentornato',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight: FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : cs.onSurface,
                                            letterSpacing: -0.5,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isRegister
                                          ? 'Inizia il tuo percorso fitness'
                                          : 'Accedi al tuo account',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white.withOpacity(0.6)
                                            : cs.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Campo email/username
                              _GlassTextField(
                                controller: _identifierCtrl,
                                label: 'Email o username',
                                hint: _isRegister
                                    ? 'mario@email.com o mario99'
                                    : 'Inserisci email o username',
                                icon: Icons.person_outline_rounded,
                                isDark: isDark,
                                keyboardType:
                                    TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null || v.trim().isEmpty) {
                                    return 'Campo obbligatorio';
                                  }
                                  if (_isRegister &&
                                      !v.contains('@') &&
                                      v.trim().length < 3) {
                                    return 'Username troppo corto';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 14),

                              // Campo password
                              _GlassTextField(
                                controller: _passwordCtrl,
                                label: 'Password',
                                icon: Icons.lock_outline_rounded,
                                isDark: isDark,
                                obscure: _obscure,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons.visibility_off_outlined,
                                    size: 20,
                                    color: isDark
                                        ? Colors.white.withOpacity(0.5)
                                        : cs.outline,
                                  ),
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Campo obbligatorio';
                                  }
                                  if (_isRegister && v.length < 6) {
                                    return 'Minimo 6 caratteri';
                                  }
                                  return null;
                                },
                              ),

                              // Errore
                              AnimatedSize(
                                duration: const Duration(milliseconds: 200),
                                child: _error != null
                                    ? Container(
                                        margin:
                                            const EdgeInsets.only(top: 12),
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 14, vertical: 10),
                                        decoration: BoxDecoration(
                                          color:
                                              cs.errorContainer.withOpacity(0.8),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                          border: Border.all(
                                              color: cs.error.withOpacity(0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(Icons.error_outline,
                                                color: cs.onErrorContainer,
                                                size: 16),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Text(_error!,
                                                  style: TextStyle(
                                                      color:
                                                          cs.onErrorContainer,
                                                      fontSize: 13)),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),

                              const SizedBox(height: 24),

                              // Bottone principale glass
                              _GlassPrimaryButton(
                                onTap: _loading ? null : _submit,
                                label: _isRegister
                                    ? 'Crea account'
                                    : 'Accedi',
                                loading: _loading,
                                isDark: isDark,
                                cs: cs,
                              ),

                              const SizedBox(height: 20),

                              // Switch login/register
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _isRegister
                                        ? 'Hai già un account?'
                                        : 'Non hai un account?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white.withOpacity(0.6)
                                          : cs.outline,
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () => setState(() {
                                      _isRegister = !_isRegister;
                                      _error = null;
                                      _identifierCtrl.clear();
                                      _passwordCtrl.clear();
                                    }),
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8),
                                    ),
                                    child: Text(
                                      _isRegister ? 'Accedi' : 'Registrati',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                        color: isDark
                                            ? Colors.white
                                            : cs.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (_isRegister) ...[
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: cs.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                        color: cs.primary.withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: 14,
                                          color: isDark
                                              ? Colors.white.withOpacity(0.7)
                                              : cs.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Completa il profilo nelle impostazioni dopo la registrazione.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.white.withOpacity(0.6)
                                                : cs.onSurfaceVariant,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ],
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

// ── Logo glass ──
class _GlassLogo extends StatelessWidget {
  final ColorScheme cs;
  final bool isDark;
  const _GlassLogo({required this.cs, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    cs.primary,
                    cs.secondary,
                  ],
                ),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.4),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 8,
                    left: 10,
                    right: 10,
                    child: Container(
                      height: 1,
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.4),
                        borderRadius: BorderRadius.circular(1),
                      ),
                    ),
                  ),
                  const Icon(Icons.fitness_center,
                      size: 44, color: Colors.white),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'MarkFit',
          style: TextStyle(
            fontSize: 30,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color: isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        Text(
          'Il tuo compagno di allenamento',
          style: TextStyle(
            fontSize: 13,
            color: isDark ? Colors.white.withOpacity(0.5) : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }
}

// ── Card glass contenitore form ──
class _GlassCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  const _GlassCard({required this.child, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final glassBg = isDark
        ? Colors.white.withOpacity(0.06)
        : Colors.white.withOpacity(0.65);
    final glassBorder = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.white.withOpacity(0.8);

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: glassBg,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: glassBorder, width: 1.2),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.08),
                blurRadius: 32,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── TextField glass ──
class _GlassTextField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final bool isDark;
  final bool obscure;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _GlassTextField({
    required this.controller,
    required this.label,
    required this.icon,
    required this.isDark,
    this.hint,
    this.obscure = false,
    this.suffixIcon,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fieldBg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.white.withOpacity(0.6);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.12)
        : Colors.white.withOpacity(0.7);
    final labelColor =
        isDark ? Colors.white.withOpacity(0.7) : cs.onSurfaceVariant;
    final textColor = isDark ? Colors.white : cs.onSurface;

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: TextFormField(
          controller: controller,
          obscureText: obscure,
          keyboardType: keyboardType,
          style: TextStyle(color: textColor, fontSize: 15),
          validator: validator,
          decoration: InputDecoration(
            labelText: label,
            hintText: hint,
          
            floatingLabelBehavior: FloatingLabelBehavior.auto,
            floatingLabelStyle: TextStyle(
              color: isDark
                  ? Colors.white.withOpacity(0.9)
                  : cs.primary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          
            labelStyle: TextStyle(
              color: labelColor,
              fontSize: 14,
            ),
          
            hintStyle: TextStyle(
              color: isDark
                  ? Colors.white.withOpacity(0.3)
                  : cs.outline.withOpacity(0.6),
            ),
          
            prefixIcon: Icon(
              icon,
              color: isDark
                  ? Colors.white.withOpacity(0.5)
                  : cs.outline,
              size: 20,
            ),
          
            suffixIcon: suffixIcon,
          
            filled: true,
            fillColor: fieldBg,
          
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor, width: 1),
              gapPadding: 8,
            ),
          
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: borderColor, width: 1),
              gapPadding: 8,
            ),
          
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(
                color: isDark
                    ? Colors.white.withOpacity(0.4)
                    : cs.primary,
                width: 1.5,
              ),
              gapPadding: 8,
            ),
          
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: cs.error, width: 1),
              gapPadding: 8,
            ),
          
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 20,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Bottone primario glass ──
class _GlassPrimaryButton extends StatelessWidget {
  final VoidCallback? onTap;
  final String label;
  final bool loading;
  final bool isDark;
  final ColorScheme cs;

  const _GlassPrimaryButton({
    required this.onTap,
    required this.label,
    required this.loading,
    required this.isDark,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            child: Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: cs.primary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: Colors.white.withOpacity(0.3),
                  width: 1,
                ),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
                boxShadow: [
                  BoxShadow(
                    color: cs.primary.withOpacity(0.45),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5, color: Colors.white),
                      )
                    : Text(
                        label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}