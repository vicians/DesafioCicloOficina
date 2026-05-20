import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_input.dart';
import '../interno_app.dart';
import '../../cliente/cliente_app.dart';
import '../../../data/auth_repository.dart';
import '../../../core/config/api_config.dart';
import 'register_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _errorText;
  bool _darkMode = false;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

  late final _authRepository = AuthRepository(baseUrl: ApiConfig.baseUrl);

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  void _login() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text.trim();

    if (email.isEmpty || pass.isEmpty) {
      setState(() => _errorText = 'Preencha e-mail e senha.');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final user = await _authRepository.login(email, pass);

      if (user == null) {
        setState(() {
          _loading = false;
          _errorText = 'Erro desconhecido ao fazer login.';
        });
        return;
      }

      if (user.tipoId == 2) {
        _navigateToClienteApp(user.id);
      } else {
        _navigateToApp(user.tipoId == 1, user.id);
      }
    } catch (e) {
      setState(() {
        _loading = false;
        _errorText = e.toString();
      });
    }
  }

  void _navigateToApp(bool isManager, String userId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
          builder: (_) => InternoApp(isManager: isManager, userId: userId)),
    );
  }

  void _navigateToClienteApp(String clientId) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ClienteApp(clientId: clientId)),
    );
  }

  void _toggleDarkMode() => setState(() => _darkMode = !_darkMode);

  @override
  Widget build(BuildContext context) {
    final bg = _darkMode ? const Color(0xFF1C2F4A) : const Color(0xFFF4F5F7);
    final cardBg = _darkMode ? const Color(0xFF2A4268) : Colors.white;
    final titleColor = _darkMode ? Colors.white : const Color(0xFF1C2F4A);
    final footerColor =
        _darkMode ? const Color(0x80FFFFFF) : const Color(0x80584237);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          automaticallyImplyLeading: false,
          actions: [
            GestureDetector(
              onTap: _toggleDarkMode,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0E6),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                    color: const Color(0x1AF97316),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _darkMode
                          ? Icons.wb_sunny_rounded
                          : Icons.nightlight_round,
                      size: 15,
                      color: orange,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _darkMode ? 'Modo Claro' : 'Modo Escuro',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: orange,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        body: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 16),
              // Logo circular
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/images/icone.jpeg',
                    fit: BoxFit.cover,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: GoogleFonts.dmSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  letterSpacing: -0.6,
                ),
                child: const Text('Tião Oficina'),
              ),
              const SizedBox(height: 24),
              // Card principal
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.symmetric(horizontal: 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_errorText != null) ...[
                      _ErrorBanner(message: _errorText!),
                      const SizedBox(height: 16),
                    ],
                    _FormField(
                      label: 'E-mail',
                      darkMode: _darkMode,
                      child: AppInput(
                        placeholder: 'seu@email.com',
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _FormField(
                      label: 'Senha',
                      darkMode: _darkMode,
                      child: AppInput(
                        placeholder: '••••••••',
                        controller: _passCtrl,
                        obscureText: true,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Botão Entrar
                    GestureDetector(
                      onTap: _loading ? null : _login,
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: orange,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: orange.withValues(alpha: 0.35),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_loading)
                              const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor:
                                      AlwaysStoppedAnimation(Colors.white),
                                ),
                              )
                            else ...[
                              Text(
                                'Entrar',
                                style: GoogleFonts.dmSans(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.login_rounded,
                                  color: Colors.white, size: 18),
                            ],
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Botão Criar uma conta
                    GestureDetector(
                      onTap: _loading
                          ? null
                          : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => RegisterScreen(
                                    darkMode: _darkMode,
                                    onDarkModeChanged: (val) =>
                                        setState(() => _darkMode = val),
                                  ),
                                ),
                              ),
                      child: Container(
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: orange.withValues(alpha: 0.20),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            'Criar uma conta',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: orange,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              AnimatedDefaultTextStyle(
                duration: const Duration(milliseconds: 300),
                style: GoogleFonts.dmSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: footerColor,
                  height: 1.7,
                ),
                child: const Text(
                  '© 2024 Tião Oficina Automotive Services.\nTecnologia e precisão para o seu veículo.',
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _FormField extends StatelessWidget {
  final String label;
  final Widget child;
  final bool darkMode;

  const _FormField(
      {required this.label, required this.child, required this.darkMode});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: darkMode
                ? Colors.white.withValues(alpha: 0.7)
                : const Color(0xFF584237),
          ),
        ),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: redBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: red.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded, color: red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
