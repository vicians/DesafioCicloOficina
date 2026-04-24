import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_input.dart';
import '../interno_app.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _isOtpMode = false;
  bool _otpSent = false;
  bool _loading = false;
  String? _errorText;

  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _otpEmailCtrl = TextEditingController();
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes =
      List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _otpEmailCtrl.dispose();
    for (final c in _otpCtrls) { c.dispose(); }
    for (final f in _otpFocusNodes) { f.dispose(); }
    super.dispose();
  }

  void _loginWithPassword() async {
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

    final isManager = email.toLowerCase().contains('gerente');
    _navigateToApp(isManager);
  }

  void _sendOtp() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    setState(() {
      _loading = false;
      _otpSent = true;
    });
  }

  void _onOtpDigit(int index, String value) {
    if (value.length == 1 && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    }
    final full = _otpCtrls.map((c) => c.text).join();
    if (full.length == 6) {
      _autoLoginOtp();
    }
  }

  void _autoLoginOtp() async {
    setState(() => _loading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    final email = _otpEmailCtrl.text.trim();
    final isManager = email.toLowerCase().contains('gerente');
    _navigateToApp(isManager);
  }

  void _navigateToApp(bool isManager) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => InternoApp(isManager: isManager),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      body: SingleChildScrollView(
        child: Column(
          children: [
            _Header(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ModeToggle(
                    isOtp: _isOtpMode,
                    onChanged: (v) => setState(() {
                      _isOtpMode = v;
                      _errorText = null;
                      _otpSent = false;
                    }),
                  ),
                  const SizedBox(height: 20),
                  if (!_isOtpMode) _PasswordForm(
                    emailCtrl: _emailCtrl,
                    passCtrl: _passCtrl,
                    errorText: _errorText,
                    loading: _loading,
                    onLogin: _loginWithPassword,
                  ),
                  if (_isOtpMode) _OtpForm(
                    emailCtrl: _otpEmailCtrl,
                    otpCtrls: _otpCtrls,
                    otpFocusNodes: _otpFocusNodes,
                    otpSent: _otpSent,
                    loading: _loading,
                    onSend: _sendOtp,
                    onDigit: _onOtpDigit,
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: Text(
                      'Use senha "1234" para entrar\n"gerente@..." para perfil gerente',
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: textMuted),
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
            'Sistema Interno',
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

class _ModeToggle extends StatelessWidget {
  final bool isOtp;
  final ValueChanged<bool> onChanged;

  const _ModeToggle({required this.isOtp, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: dividerColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _ToggleOption(
            label: 'Senha',
            isActive: !isOtp,
            onTap: () => onChanged(false),
          ),
          _ToggleOption(
            label: 'Código OTP',
            isActive: isOtp,
            onTap: () => onChanged(true),
          ),
        ],
      ),
    );
  }
}

class _ToggleOption extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _ToggleOption({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isActive ? cardWhite : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            boxShadow: isActive ? const [cardShadow] : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              color: isActive ? navyDark : textSecondary,
            ),
          ),
        ),
      ),
    );
  }
}

class _PasswordForm extends StatelessWidget {
  final TextEditingController emailCtrl;
  final TextEditingController passCtrl;
  final String? errorText;
  final bool loading;
  final VoidCallback onLogin;

  const _PasswordForm({
    required this.emailCtrl,
    required this.passCtrl,
    required this.errorText,
    required this.loading,
    required this.onLogin,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInput(
          label: 'E-mail ou telefone',
          placeholder: 'seu@email.com',
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        AppInput(
          label: 'Senha',
          placeholder: '••••••••',
          controller: passCtrl,
          obscureText: true,
        ),
        if (errorText != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(message: errorText!),
        ],
        const SizedBox(height: 20),
        AppButton(
          label: 'Entrar',
          fullWidth: true,
          loading: loading,
          onPressed: loading ? null : onLogin,
        ),
      ],
    );
  }
}

class _OtpForm extends StatelessWidget {
  final TextEditingController emailCtrl;
  final List<TextEditingController> otpCtrls;
  final List<FocusNode> otpFocusNodes;
  final bool otpSent;
  final bool loading;
  final VoidCallback onSend;
  final void Function(int, String) onDigit;

  const _OtpForm({
    required this.emailCtrl,
    required this.otpCtrls,
    required this.otpFocusNodes,
    required this.otpSent,
    required this.loading,
    required this.onSend,
    required this.onDigit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppInput(
          label: 'E-mail',
          placeholder: 'seu@email.com',
          controller: emailCtrl,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        if (!otpSent)
          AppButton(
            label: 'Enviar código por SMS',
            fullWidth: true,
            loading: loading,
            onPressed: loading ? null : onSend,
          ),
        if (otpSent) ...[
          Text(
            'Digite o código de 6 dígitos enviado ao seu celular',
            style: GoogleFonts.dmSans(fontSize: 13, color: textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(6, (i) {
              return Padding(
                padding: EdgeInsets.only(right: i < 5 ? 8 : 0),
                child: SizedBox(
                  width: 42,
                  height: 50,
                  child: TextFormField(
                    controller: otpCtrls[i],
                    focusNode: otpFocusNodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: GoogleFonts.dmSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: cardWhite,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: borderColor, width: 1.5),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: borderColor, width: 1.5),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide:
                            const BorderSide(color: navyDark, width: 1.5),
                      ),
                    ),
                    onChanged: (v) => onDigit(i, v),
                  ),
                ),
              );
            }),
          ),
          if (loading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator(color: orange)),
          ],
        ],
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
