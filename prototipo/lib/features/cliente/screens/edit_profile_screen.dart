import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/api/api_helper.dart';

class _PhoneMaskFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'\D'), '');
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length && i < 11; i++) {
      if (i == 0) buffer.write('(');
      if (i == 2) buffer.write(') ');
      if (i == 7) buffer.write('-');
      buffer.write(digits[i]);
    }
    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class EditProfileScreen extends StatefulWidget {
  final String clientId;
  final String baseUrl;
  final VoidCallback? onSaved;

  const EditProfileScreen({
    super.key,
    required this.clientId,
    required this.baseUrl,
    this.onSaved,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final resp = await ApiHelper.get('${widget.baseUrl}/usuarios/${widget.clientId}');
      if (resp.statusCode == 200 && mounted) {
        final data = jsonDecode(resp.body);
        _nameCtrl.text = data['nome'] ?? '';
        _emailCtrl.text = data['email'] ?? '';
        final rawPhone = (data['telefone'] ?? '') as String;
        _phoneCtrl.text = _PhoneMaskFormatter().formatEditUpdate(
          const TextEditingValue(),
          TextEditingValue(text: rawPhone),
        ).text;
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    final email = _emailCtrl.text.trim();
    final phone = _phoneCtrl.text.trim();

    if (name.isEmpty) {
      _showError('O nome não pode estar vazio.');
      return;
    }
    if (email.isEmpty || !email.contains('@')) {
      _showError('Insira um e-mail válido.');
      return;
    }
    final phoneDigits = phone.replaceAll(RegExp(r'\D'), '');
    if (phoneDigits.length < 10) {
      _showError('Insira um telefone válido (mínimo 10 dígitos).');
      return;
    }

    setState(() => _saving = true);
    try {
      final resp = await ApiHelper.put(
        '${widget.baseUrl}/usuarios/${widget.clientId}',
        {'nome': name, 'email': email, 'telefone': phoneDigits},
      );
      if (!mounted) return;
      if (resp.statusCode == 200) {
        widget.onSaved?.call();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Dados atualizados com sucesso!', style: GoogleFonts.dmSans(color: Colors.white)),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      } else {
        _showError('Erro ao salvar. Tente novamente.');
      }
    } catch (_) {
      if (mounted) _showError('Erro de conexão. Tente novamente.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: GoogleFonts.dmSans(color: Colors.white)),
        backgroundColor: const Color(0xFFB71C1C),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: bgPage,
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.arrow_back_rounded, color: navyDark, size: 20),
          ),
        ),
        title: Text(
          'Alteração de Dados',
          style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: navyDark),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: orange))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: const [cardShadow],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Field(
                      label: 'Nome completo',
                      child: AppInput(placeholder: 'Seu nome', controller: _nameCtrl),
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      label: 'E-mail',
                      child: AppInput(
                        placeholder: 'seu@email.com',
                        controller: _emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _Field(
                      label: 'Telefone',
                      child: AppInput(
                        placeholder: '(00) 00000-0000',
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        inputFormatters: [_PhoneMaskFormatter()],
                      ),
                    ),
                    const SizedBox(height: 24),
                    AppButton(
                      label: _saving ? 'Salvando...' : 'Salvar alterações',
                      fullWidth: true,
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final Widget child;
  const _Field({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w600, color: navyDark)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
