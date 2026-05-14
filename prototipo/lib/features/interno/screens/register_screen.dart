import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_input.dart';
import '../../../data/auth_repository.dart';
import '../../../core/config/api_config.dart';
import '../../cliente/cliente_app.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  bool _loading = false;
  String? _errorText;

  final _nomeCtrl = TextEditingController();
  final _sobrenomeCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _senhaCtrl = TextEditingController();
  final _confirmaSenhaCtrl = TextEditingController();

  late final _authRepository = AuthRepository(baseUrl: ApiConfig.baseUrl);

  @override
  void dispose() {
    _nomeCtrl.dispose();
    _sobrenomeCtrl.dispose();
    _emailCtrl.dispose();
    _senhaCtrl.dispose();
    _confirmaSenhaCtrl.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: bgPage,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Header(onBack: () => Navigator.pop(context)),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  AppInput(
                    label: 'Nome',
                    placeholder: 'Seu nome',
                    controller: _nomeCtrl,
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 12),
                  AppInput(
                    label: 'Sobrenome',
                    placeholder: 'Seu sobrenome',
                    controller: _sobrenomeCtrl,
                    keyboardType: TextInputType.name,
                  ),
                  const SizedBox(height: 12),
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
                    controller: _senhaCtrl,
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  AppInput(
                    label: 'Confirmar senha',
                    placeholder: '••••••••',
                    controller: _confirmaSenhaCtrl,
                    obscureText: true,
                  ),
                  if (_errorText != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: _errorText!),
                  ],
                  const SizedBox(height: 20),
                  AppButton(
                    label: 'Criar conta',
                    fullWidth: true,
                    loading: _loading,
                    onPressed: _loading ? null : _register,
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Text(
                      'Já tem uma conta? Entrar',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.dmSans(
                        fontSize: 13,
                        color: textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
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
  final VoidCallback onBack;
  const _Header({required this.onBack});

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
      child: Stack(
        children: [
          GestureDetector(
            onTap: onBack,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: Image.asset(
                      'assets/images/icone.jpeg',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Criar conta',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'Preencha seus dados para se cadastrar',
                textAlign: TextAlign.center,
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: Colors.white.withValues(alpha: 0.55),
                ),
              ),
            ],
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
