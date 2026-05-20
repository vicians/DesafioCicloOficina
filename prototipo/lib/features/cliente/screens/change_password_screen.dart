import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_input.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/api/api_helper.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String clientId;
  final String baseUrl;

  const ChangePasswordScreen({
    super.key,
    required this.clientId,
    required this.baseUrl,
  });

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _saving = false;

  Future<void> _save() async {
    final current = _currentCtrl.text;
    final newPass = _newCtrl.text;
    final confirm = _confirmCtrl.text;

    if (current.isEmpty || newPass.isEmpty || confirm.isEmpty) {
      _showError('Preencha todos os campos.');
      return;
    }
    if (newPass.length < 6) {
      _showError('A nova senha deve ter ao menos 6 caracteres.');
      return;
    }
    if (newPass != confirm) {
      _showError('A nova senha e a confirmação não coincidem.');
      return;
    }

    setState(() => _saving = true);
    try {
      // Verify current password via login endpoint
      final userResp = await ApiHelper.get('${widget.baseUrl}/usuarios/${widget.clientId}');
      if (userResp.statusCode != 200) {
        _showError('Não foi possível verificar o usuário.');
        setState(() => _saving = false);
        return;
      }
      final userData = jsonDecode(userResp.body);
      final email = userData['email'] as String? ?? '';

      final loginResp = await ApiHelper.post('${widget.baseUrl}/auth/login', {
        'email': email,
        'senha': current,
      });
      if (loginResp.statusCode != 200) {
        _showError('Senha atual incorreta.');
        setState(() => _saving = false);
        return;
      }

      // Update password
      final updateResp = await ApiHelper.put(
        '${widget.baseUrl}/usuarios/${widget.clientId}',
        {'senha': newPass},
      );
      if (!mounted) return;
      if (updateResp.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Senha alterada com sucesso!', style: GoogleFonts.dmSans(color: Colors.white)),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        Navigator.pop(context);
      } else {
        _showError('Erro ao alterar senha. Tente novamente.');
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
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
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
            decoration: BoxDecoration(color: bgPage, borderRadius: BorderRadius.circular(10)),
            child: const Icon(Icons.arrow_back_rounded, color: navyDark, size: 20),
          ),
        ),
        title: Text(
          'Alteração de Senha',
          style: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: navyDark),
        ),
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: borderColor),
        ),
      ),
      body: SingleChildScrollView(
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
              _Field(label: 'Senha atual', child: AppInput(placeholder: '••••••••', controller: _currentCtrl, obscureText: true)),
              const SizedBox(height: 12),
              _Field(label: 'Nova senha', child: AppInput(placeholder: '••••••••', controller: _newCtrl, obscureText: true)),
              const SizedBox(height: 12),
              _Field(label: 'Confirmar nova senha', child: AppInput(placeholder: '••••••••', controller: _confirmCtrl, obscureText: true)),
              const SizedBox(height: 24),
              AppButton(
                label: _saving ? 'Alterando...' : 'Alterar senha',
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
