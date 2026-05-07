import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_input.dart';
import '../data/client_flow_repository.dart';

class RegisterVehicleScreen extends StatefulWidget {
  final ClientFlowRepository repository;

  const RegisterVehicleScreen({super.key, required this.repository});

  @override
  State<RegisterVehicleScreen> createState() => _RegisterVehicleScreenState();
}

class _RegisterVehicleScreenState extends State<RegisterVehicleScreen> {
  final _marcaCtrl = TextEditingController();
  final _modeloCtrl = TextEditingController();
  final _placaCtrl = TextEditingController();
  final _anoCtrl = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _marcaCtrl.dispose();
    _modeloCtrl.dispose();
    _placaCtrl.dispose();
    _anoCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final marca = _marcaCtrl.text.trim();
    final modelo = _modeloCtrl.text.trim();
    final placa = _placaCtrl.text.trim();
    final ano = int.tryParse(_anoCtrl.text.trim());

    if (marca.isEmpty || modelo.isEmpty || placa.isEmpty || ano == null) {
      setState(() => _error = 'Preencha todos os campos corretamente.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      await widget.repository.createVeiculo(marca, modelo, placa, ano);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Erro ao cadastrar: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        title: Text('Cadastrar Veículo', style: GoogleFonts.dmSans(fontWeight: FontWeight.w600)),
        backgroundColor: Colors.white,
        foregroundColor: textPrimary,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppInput(label: 'Marca', placeholder: 'Ex: Honda', controller: _marcaCtrl),
            const SizedBox(height: 16),
            AppInput(label: 'Modelo', placeholder: 'Ex: Civic', controller: _modeloCtrl),
            const SizedBox(height: 16),
            AppInput(label: 'Placa', placeholder: 'Ex: ABC-1234', controller: _placaCtrl),
            const SizedBox(height: 16),
            AppInput(
              label: 'Ano',
              placeholder: 'Ex: 2020',
              controller: _anoCtrl,
              keyboardType: TextInputType.number,
            ),
            if (_error != null) ...[
              const SizedBox(height: 20),
              Text(_error!, style: GoogleFonts.dmSans(color: red, fontSize: 13)),
            ],
            const SizedBox(height: 32),
            AppButton(
              label: 'Salvar Veículo',
              loading: _loading,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
