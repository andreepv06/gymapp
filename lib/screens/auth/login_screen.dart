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

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
                horizontal: 28, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo
                    Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            cs.primary,
                            cs.secondary,
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: cs.primary.withOpacity(0.3),
                            blurRadius: 20,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.fitness_center,
                          size: 42, color: Colors.white),
                    ),
                    const SizedBox(height: 28),

                    Text(
                      'MarkFit',
                      style: Theme.of(context)
                          .textTheme
                          .headlineLarge
                          ?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -1,
                          ),
                    ),
                    const SizedBox(height: 8),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        _isRegister
                            ? 'Crea il tuo account gratuito'
                            : 'Bentornato! Accedi al tuo account',
                        key: ValueKey(_isRegister),
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: cs.outline),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Campo identifier
                    TextFormField(
                      controller: _identifierCtrl,
                      keyboardType: TextInputType.emailAddress,
                      decoration: InputDecoration(
                        labelText: 'Email o username',
                        hintText: _isRegister
                            ? 'mario@email.com oppure mario99'
                            : 'Inserisci email o username',
                        prefixIcon:
                            const Icon(Icons.person_outline),
                      ),
                      validator: (v) {
                        if (v == null || v.trim().isEmpty) {
                          return 'Inserisci email o username';
                        }
                        if (_isRegister &&
                            !v.contains('@') &&
                            v.trim().length < 3) {
                          return 'Username troppo corto (min 3 caratteri)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 14),

                    // Password
                    TextFormField(
                      controller: _passwordCtrl,
                      obscureText: _obscure,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(
                              () => _obscure = !_obscure),
                        ),
                      ),
                      validator: (v) {
                        if (v == null || v.isEmpty) {
                          return 'Inserisci la password';
                        }
                        if (_isRegister && v.length < 6) {
                          return 'Minimo 6 caratteri';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 12),

                    // Errore
                    AnimatedSize(
                      duration: const Duration(milliseconds: 200),
                      child: _error != null
                          ? Container(
                              width: double.infinity,
                              margin:
                                  const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 16, vertical: 12),
                              decoration: BoxDecoration(
                                color: cs.errorContainer,
                                borderRadius:
                                    BorderRadius.circular(12),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: cs.onErrorContainer,
                                      size: 18),
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

                    const SizedBox(height: 16),

                    // Bottone principale
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: SizedBox(
                        key: ValueKey(_isRegister),
                        width: double.infinity,
                        child: FilledButton(
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      color: Colors.white),
                                )
                              : Text(_isRegister
                                  ? 'Crea account'
                                  : 'Accedi'),
                        ),
                      ),
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
                          style: TextStyle(color: cs.outline),
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
                                color: cs.primary),
                          ),
                        ),
                      ],
                    ),

                    if (_isRegister) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cs.primaryContainer
                              .withOpacity(0.4),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.info_outline,
                                size: 16,
                                color: cs.onPrimaryContainer),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Potrai completare il tuo profilo nelle impostazioni dopo la registrazione.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: cs.onPrimaryContainer,
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
          ),
        ),
      ),
    );
  }
}