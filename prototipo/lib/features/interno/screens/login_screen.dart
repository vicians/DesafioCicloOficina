import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_input.dart';
import '../interno_app.dart';
import '../../cliente/cliente_app.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _errorText;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();

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

    await Future.delayed(const Duration(milliseconds: 1200));

    if (pass != '1234') {
      setState(() {
        _loading = false;
        _errorText = 'E-mail ou senha inválidos.';
      });
      return;
    }

    final emailLower = email.toLowerCase();
    if (emailLower.contains('cliente')) {
      _navigateToClienteApp();
    } else {
      _navigateToApp(emailLower.contains('gerente'));
    }
  }

  void _navigateToApp(bool isManager) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => InternoApp(isManager: isManager)),
    );
  }

  void _navigateToClienteApp() {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const ClienteApp()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      body: SingleChildScrollView(
        child: Column(
          children: [
            const _Header(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  AppInput(
                    label: 'E-mail',
                    placeholder: 'seu@email.com',
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  AppInput(
                    label: 'Senha',
                    placeholder: '••••••••',
                    controller: _passCtrl,
                    obscureText: true,
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: _errorText!),
                  ],
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Entrar',
                    fullWidth: true,
                    loading: _loading,
                    onPressed: _loading ? null : _login,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Senha: 1234 para todos\ncliente@tiao.com → App do Cliente\nfuncionario@tiao.com → Funcionário\ngerente@tiao.com → Gerente',
                      style: GoogleFonts.dmSans(fontSize: 11, color: textMuted),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 32),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyDark, navyMid],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.build_rounded, color: Colors.white, size: 32),
          ),
          const SizedBox(height: 16),
          Text(
            'Tião Oficina',
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          Text(
            'Faça seu login',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: Colors.white.withValues(alpha: 0.55),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: redBg,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: red, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.dmSans(fontSize: 13, color: red),
            ),
          ),
        ],
      ),
    );
  }
}
