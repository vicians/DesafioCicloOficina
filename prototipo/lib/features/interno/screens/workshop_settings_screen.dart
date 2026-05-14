import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../services/workshop_service.dart';
import '../data/models/workshop_info.dart';

class WorkshopSettingsScreen extends StatefulWidget {
  final VoidCallback onOpenDrawer;

  const WorkshopSettingsScreen({super.key, required this.onOpenDrawer});

  @override
  State<WorkshopSettingsScreen> createState() => _WorkshopSettingsScreenState();
}

class _WorkshopSettingsScreenState extends State<WorkshopSettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _boxesController = TextEditingController();
  bool _isLoading = true;
  bool _isSaving = false;
  WorkshopInfo? _workshop;

  @override
  void initState() {
    super.initState();
    _loadWorkshop();
  }

  Future<void> _loadWorkshop() async {
    setState(() => _isLoading = true);
    final workshop = await WorkshopService.getWorkshop();
    if (mounted && workshop != null) {
      setState(() {
        _workshop = workshop;
        _nameController.text = workshop.name;
        _boxesController.text = workshop.boxes.toString();
        _isLoading = false;
      });
    } else if (mounted) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Falha ao carregar dados da oficina')),
      );
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate() || _workshop == null) return;

    setState(() => _isSaving = true);
    final success = await WorkshopService.updateWorkshop(
      _workshop!.id,
      _nameController.text,
      int.parse(_boxesController.text),
    );

    if (mounted) {
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? 'Dados atualizados com sucesso' : 'Falha ao atualizar dados'),
          backgroundColor: success ? Colors.green : Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(color: orange))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildSectionTitle('IDENTIFICAÇÃO'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Nome da Oficina',
                          controller: _nameController,
                          icon: Icons.store_rounded,
                          validator: (v) => v == null || v.isEmpty ? 'Obrigatório' : null,
                        ),
                        const SizedBox(height: 24),
                        _buildSectionTitle('CAPACIDADE OPERACIONAL'),
                        const SizedBox(height: 16),
                        _buildTextField(
                          label: 'Quantidade de Boxes',
                          controller: _boxesController,
                          icon: Icons.garage_rounded,
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Obrigatório';
                            final n = int.tryParse(v);
                            if (n == null || n <= 0) return 'Mínimo 1 box';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Aumentar o número de boxes libera mais horários simultâneos para agendamento automático.',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            color: textMuted,
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 40),
                        _buildSaveButton(),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 22),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyDark, navyMid],
        ),
      ),
      child: Row(
        children: [
          GestureDetector(
            onTap: widget.onOpenDrawer,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.10),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.menu_rounded, size: 19, color: Colors.white),
            ),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Dados da Oficina',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              Text(
                'Gestão de capacidade',
                style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: Colors.white.withOpacity(0.5),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: GoogleFonts.dmSans(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: textMuted,
        letterSpacing: 1.2,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required IconData icon,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
        boxShadow: const [cardShadow],
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        validator: validator,
        style: GoogleFonts.dmSans(fontSize: 15, color: textPrimary),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: GoogleFonts.dmSans(color: textMuted, fontSize: 14),
          prefixIcon: Icon(icon, color: navyDark, size: 20),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return GestureDetector(
      onTap: _isSaving ? null : _save,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: navyDark,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: navyDark.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Center(
          child: _isSaving
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
              : Text(
                  'Salvar Alterações',
                  style: GoogleFonts.dmSans(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
        ),
      ),
    );
  }
}
