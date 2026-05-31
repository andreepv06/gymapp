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
    final isDark =
        Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF0D0D1A) : cs.surface,
      body: Stack(
        children: [
          // Sfondo gradiente
          Positioned.fill(
            child: Container(
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
                          cs.primary.withOpacity(0.1),
                          cs.secondary.withOpacity(0.07),
                          cs.surface,
                        ],
                ),
              ),
            ),
          ),

          // Cerchi decorativi sfumati
          Positioned(
            top: -100,
            right: -80,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    cs.primary.withOpacity(isDark ? 0.12 : 0.08),
              ),
            ),
          ),
          Positioned(
            bottom: -80,
            left: -60,
            child: Container(
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cs.secondary
                    .withOpacity(isDark ? 0.1 : 0.07),
              ),
            ),
          ),

          // Contenuto scrollabile
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 24),
                child: ConstrainedBox(
                  constraints:
                      const BoxConstraints(maxWidth: 420),
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.center,
                    children: [
                      // Logo
                      _buildLogo(cs, isDark, context),
                      const SizedBox(height: 32),

                      // Card form glass
                      _buildGlassCard(
                        isDark: isDark,
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              // Titolo animato
                              AnimatedSwitcher(
                                duration: const Duration(
                                    milliseconds: 200),
                                child: Column(
                                  key: ValueKey(_isRegister),
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isRegister
                                          ? 'Crea account'
                                          : 'Bentornato',
                                      style: Theme.of(context)
                                          .textTheme
                                          .headlineSmall
                                          ?.copyWith(
                                            fontWeight:
                                                FontWeight.w800,
                                            color: isDark
                                                ? Colors.white
                                                : cs.onSurface,
                                            letterSpacing: -0.5,
                                          ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      _isRegister
                                          ? 'Inizia il tuo percorso'
                                          : 'Accedi al tuo account',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: isDark
                                            ? Colors.white
                                                .withOpacity(0.55)
                                            : cs.outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 28),

                              // Campo identifier
                              // FIX label troncata: usa InputDecoration
                              // senza ClipRRect, contentPadding generoso
                              _buildField(
                                context: context,
                                controller: _identifierCtrl,
                                label: 'Email o username',
                                hint: _isRegister
                                    ? 'mario@email.com o mario99'
                                    : 'Inserisci email o username',
                                icon:
                                    Icons.person_outline_rounded,
                                isDark: isDark,
                                keyboardType:
                                    TextInputType.emailAddress,
                                validator: (v) {
                                  if (v == null ||
                                      v.trim().isEmpty) {
                                    return 'Campo obbligatorio';
                                  }
                                  if (_isRegister &&
                                      !v.contains('@') &&
                                      v.trim().length < 3) {
                                    return 'Username min 3 caratteri';
                                  }
                                  return null;
                                },
                              ),
                              const SizedBox(height: 16),

                              // Campo password
                              _buildField(
                                context: context,
                                controller: _passwordCtrl,
                                label: 'Password',
                                icon: Icons.lock_outline_rounded,
                                isDark: isDark,
                                obscure: _obscure,
                                suffixIcon: IconButton(
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility_outlined
                                        : Icons
                                            .visibility_off_outlined,
                                    size: 20,
                                    color: isDark
                                        ? Colors.white
                                            .withOpacity(0.5)
                                        : cs.outline,
                                  ),
                                  onPressed: () => setState(() =>
                                      _obscure = !_obscure),
                                ),
                                validator: (v) {
                                  if (v == null || v.isEmpty) {
                                    return 'Campo obbligatorio';
                                  }
                                  if (_isRegister &&
                                      v.length < 6) {
                                    return 'Minimo 6 caratteri';
                                  }
                                  return null;
                                },
                              ),

                              // Errore
                              AnimatedSize(
                                duration: const Duration(
                                    milliseconds: 200),
                                child: _error != null
                                    ? Container(
                                        margin:
                                            const EdgeInsets.only(
                                                top: 12),
                                        padding: const EdgeInsets
                                            .symmetric(
                                            horizontal: 14,
                                            vertical: 10),
                                        decoration: BoxDecoration(
                                          color: cs.errorContainer
                                              .withOpacity(0.9),
                                          borderRadius:
                                              BorderRadius.circular(
                                                  10),
                                          border: Border.all(
                                              color: cs.error
                                                  .withOpacity(
                                                      0.3)),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(
                                                Icons.error_outline,
                                                color: cs
                                                    .onErrorContainer,
                                                size: 16),
                                            const SizedBox(
                                                width: 8),
                                            Expanded(
                                              child: Text(
                                                _error!,
                                                style: TextStyle(
                                                    color: cs
                                                        .onErrorContainer,
                                                    fontSize: 13),
                                              ),
                                            ),
                                          ],
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),

                              const SizedBox(height: 24),

                              // Bottone principale
                              _buildPrimaryButton(cs),

                              const SizedBox(height: 20),

                              // Switch login/register
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _isRegister
                                        ? 'Hai già un account?'
                                        : 'Non hai un account?',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark
                                          ? Colors.white
                                              .withOpacity(0.55)
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
                                      padding:
                                          const EdgeInsets.symmetric(
                                              horizontal: 8),
                                    ),
                                    child: Text(
                                      _isRegister
                                          ? 'Accedi'
                                          : 'Registrati',
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
                                  padding:
                                      const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color:
                                        cs.primary.withOpacity(0.1),
                                    borderRadius:
                                        BorderRadius.circular(10),
                                    border: Border.all(
                                        color: cs.primary
                                            .withOpacity(0.2)),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.info_outline,
                                          size: 14,
                                          color: isDark
                                              ? Colors.white
                                                  .withOpacity(0.7)
                                              : cs.primary),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'Completa il profilo nelle impostazioni.',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: isDark
                                                ? Colors.white
                                                    .withOpacity(0.55)
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

  // ── Logo ──
  Widget _buildLogo(
      ColorScheme cs, bool isDark, BuildContext context) {
    return Column(
      children: [
        Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [cs.primary, cs.secondary],
            ),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: Colors.white.withOpacity(0.3), width: 1.5),
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
                  color: Colors.white.withOpacity(0.35),
                ),
              ),
              const Icon(Icons.fitness_center,
                  size: 42, color: Colors.white),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'MarkFit',
          style: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            letterSpacing: -1,
            color:
                isDark ? Colors.white : const Color(0xFF1A1A2E),
          ),
        ),
        Text(
          'Il tuo compagno di allenamento',
          style: TextStyle(
            fontSize: 13,
            color: isDark
                ? Colors.white.withOpacity(0.45)
                : Colors.grey.shade600,
          ),
        ),
      ],
    );
  }

  // ── Card glass ──
  Widget _buildGlassCard(
      {required bool isDark, required Widget child}) {
    final glassBg = isDark
        ? Colors.white.withOpacity(0.07)
        : Colors.white.withOpacity(0.72);
    final glassBorder = isDark
        ? Colors.white.withOpacity(0.1)
        : Colors.white.withOpacity(0.9);

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
                color:
                    Colors.black.withOpacity(isDark ? 0.25 : 0.05),
                blurRadius: 30,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }

  // ── TextField senza ClipRRect — FIX label troncata ──
  Widget _buildField({
    required BuildContext context,
    required TextEditingController controller,
    required String label,
    required IconData icon,
    required bool isDark,
    String? hint,
    bool obscure = false,
    Widget? suffixIcon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    final cs = Theme.of(context).colorScheme;

    final fieldBg = isDark
        ? Colors.white.withOpacity(0.09)
        : Colors.white.withOpacity(0.65);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.14)
        : cs.outline.withOpacity(0.25);
    final focusBorder =
        isDark ? Colors.white.withOpacity(0.45) : cs.primary;
    final labelColor = isDark
        ? Colors.white.withOpacity(0.65)
        : cs.onSurfaceVariant;
    final textColor = isDark ? Colors.white : cs.onSurface;

    // FIX: NON avvolgere in ClipRRect/BackdropFilter —
    // causa il taglio del floating label.
    // Il blur estetico è già dato dal _buildGlassCard sottostante.
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: keyboardType,
      style: TextStyle(color: textColor, fontSize: 15),
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        // FIX label troncata: floatingLabelStyle esplicito + padding top
        labelStyle: TextStyle(color: labelColor, fontSize: 15),
        floatingLabelStyle: TextStyle(
          color: isDark
              ? Colors.white.withOpacity(0.85)
              : cs.primary,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: isDark
              ? Colors.white.withOpacity(0.28)
              : cs.outline.withOpacity(0.5),
          fontSize: 14,
        ),
        prefixIcon: Icon(icon,
            color: isDark
                ? Colors.white.withOpacity(0.5)
                : cs.outline,
            size: 20),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: fieldBg,
        // FIX: contentPadding con top generoso lascia spazio
        // al floating label senza che venga tagliato
        contentPadding:
            const EdgeInsets.fromLTRB(16, 22, 16, 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: borderColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: focusBorder, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.error, width: 1.5),
        ),
      ),
    );
  }

  // ── Bottone primario glass ──
  Widget _buildPrimaryButton(ColorScheme cs) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _loading ? null : _submit,
            borderRadius: BorderRadius.circular(14),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                color: _loading
                    ? cs.primary.withOpacity(0.6)
                    : cs.primary,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: Colors.white.withOpacity(0.3)),
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.white.withOpacity(0.15),
                    Colors.transparent,
                  ],
                ),
                boxShadow: _loading
                    ? null
                    : [
                        BoxShadow(
                          color: cs.primary.withOpacity(0.4),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
              ),
              child: Center(
                child: _loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white),
                      )
                    : Text(
                        _isRegister ? 'Crea account' : 'Accedi',
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