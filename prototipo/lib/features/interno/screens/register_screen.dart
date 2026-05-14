import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_input.dart';
import '../../../data/auth_repository.dart';
import '../../../core/config/api_config.dart';
import '../../cliente/cliente_app.dart';

class RegisterScreen extends StatefulWidget {
  final bool darkMode;
  final ValueChanged<bool> onDarkModeChanged;

  const RegisterScreen({
    super.key,
    required this.darkMode,
    required this.onDarkModeChanged,
  });

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _loading = false;
  String? _errorText;
  late bool _darkMode;

  final _nomeCtrl = TextEditingController();
  final _sobrenomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmaSenhaCtrl = TextEditingController();

  late final _authRepository = AuthRepository(baseUrl: ApiConfig.baseUrl);

  @override
  void initState() {
    super.initState();
    _darkMode = widget.darkMode;
  }

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _sobrenomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmaSenhaCtrl.dispose();
    super.dispose();
  }

  void _toggleDarkMode() {
    setState(() => _darkMode = !_darkMode);
    widget.onDarkModeChanged(_darkMode);
  }

  void _register() async {
    final nome = _nomeCtrl.text.trim();
    final sobrenome = _sobrenomeCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final senha = _senhaCtrl.text;
    final confirmaSenha = _confirmaSenhaCtrl.text;

    if (nome.isEmpty || sobrenome.isEmpty || email.isEmpty || senha.isEmpty) {
      setState(() => _errorText = 'Preencha todos os campos.');
      return;
    }

    if (senha != confirmaSenha) {
      setState(() => _errorText = 'As senhas não coincidem.');
      return;
    }

    if (senha.length < 6) {
      setState(() => _errorText = 'A senha deve ter pelo menos 6 caracteres.');
      return;
    }

    setState(() {
      _loading = true;
      _errorText = null;
    });

    try {
      final nomeCompleto = '$nome $sobrenome';
      final user = await _authRepository.register(nomeCompleto, email, senha);

      if (user == null) {
        setState(() {
          _loading = false;
          _errorText = 'Erro desconhecido ao criar conta.';
        });
        return;
      }

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => ClienteApp(clientId: user.id)),
      );
    } catch (e) {
      setState(() {
        _loading = false;
        _errorText = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bg = _darkMode ? const Color(0xFF1C2F4A) : const Color(0xFFF4F5F7);
    final cardBg = _darkMode ? const Color(0xFF2A4268) : Colors.white;
    final titleColor = _darkMode ? Colors.white : const Color(0xFF1C2F4A);
    final subtitleColor = _darkMode
        ? Colors.white.withValues(alpha: 0.55)
        : const Color(0xFF584237).withValues(alpha: 0.6);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      color: bg,
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _darkMode
                    ? Colors.white.withValues(alpha: 0.12)
                    : Colors.black.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                Icons.arrow_back_ios_new_rounded,
                color: _darkMode ? Colors.white : const Color(0xFF1C2F4A),
                size: 16,
              ),
            ),
          ),
          actions: [
            GestureDetector(
              onTap: _toggleDarkMode,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                margin: const EdgeInsets.only(right: 16, top: 8, bottom: 8),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
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
              const SizedBox(height: 8),
              // Logo circular
              Container(
                width: 80,
                height: 80,
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
              const SizedBox(height: 14),
              Text(
                'Criar conta',
                style: GoogleFonts.dmSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: titleColor,
                  letterSpacing: -0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Preencha seus dados para se cadastrar',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: subtitleColor,
                ),
              ),
              const SizedBox(height: 20),
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
                      label: 'Nome',
                      darkMode: _darkMode,
                      child: AppInput(
                        placeholder: 'Seu nome',
                        controller: _nomeCtrl,
                        keyboardType: TextInputType.name,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _FormField(
                      label: 'Sobrenome',
                      darkMode: _darkMode,
                      child: AppInput(
                        placeholder: 'Seu sobrenome',
                        controller: _sobrenomeCtrl,
                        keyboardType: TextInputType.name,
                      ),
                    ),
                    const SizedBox(height: 8),
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
                        controller: _senhaCtrl,
                        obscureText: true,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _FormField(
                      label: 'Confirmar senha',
                      darkMode: _darkMode,
                      child: AppInput(
                        placeholder: '••••••••',
                        controller: _confirmaSenhaCtrl,
                        obscureText: true,
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Botão Criar conta
                    GestureDetector(
                      onTap: _loading ? null : _register,
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 120),
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
                        child: Center(
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation(
                                        Colors.white),
                                  ),
                                )
                              : Text(
                                  'Criar conta',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Text(
                        'Já tem uma conta? Entrar',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          color: _darkMode
                              ? Colors.white.withValues(alpha: 0.6)
                              : const Color(0x80584237),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                  ],
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
