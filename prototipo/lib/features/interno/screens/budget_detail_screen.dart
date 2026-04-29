import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../data/internal_flow_repository.dart';
import '../data/models/internal_budget_item.dart';

class BudgetDetailScreen extends StatefulWidget {
  final InternalFlowRepository repository;
  final InternalBudgetItem budget;

  const BudgetDetailScreen({
    super.key,
    required this.repository,
    required this.budget,
  });

  @override
  State<BudgetDetailScreen> createState() => _BudgetDetailScreenState();
}

class _BudgetDetailScreenState extends State<BudgetDetailScreen> {
  late final TextEditingController _clientCtrl;
  late final TextEditingController _carCtrl;
  late final TextEditingController _plateCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _valueCtrl;
  bool _saving = false;

  bool get _isCanceled => widget.budget.isCanceled;

  @override
  void initState() {
    super.initState();
    _clientCtrl = TextEditingController(text: widget.budget.client);
    _carCtrl = TextEditingController(text: widget.budget.car);
    _plateCtrl = TextEditingController(text: widget.budget.plate);
    _descCtrl = TextEditingController(text: widget.budget.description);
    _valueCtrl = TextEditingController(
      text: widget.budget.value.toStringAsFixed(2).replaceAll('.', ','),
    );
  }

  @override
  void dispose() {
    _clientCtrl.dispose();
    _carCtrl.dispose();
    _plateCtrl.dispose();
    _descCtrl.dispose();
    _valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final parsedValue = double.tryParse(_valueCtrl.text.replaceAll(',', '.'));
    if (parsedValue == null) {
      _showMessage('Informe um valor valido.');
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = widget.budget.copyWith(
        client: _clientCtrl.text.trim(),
        car: _carCtrl.text.trim(),
        plate: _plateCtrl.text.trim().toUpperCase(),
        description: _descCtrl.text.trim(),
        value: parsedValue,
      );
      await widget.repository.updateOrcamento(updated);
      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancelBudget() async {
    setState(() => _saving = true);
    try {
      await widget.repository.cancelOrcamento(widget.budget.id);
      if (!mounted) return;
      Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _approveBudget() async {
    setState(() => _saving = true);
    try {
      final service = await widget.repository.approveOrcamento(widget.budget.id);
      if (!mounted) return;
      Navigator.pop(context, service.id);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      appBar: AppBar(
        backgroundColor: navyDark,
        foregroundColor: Colors.white,
        title: Text(
          widget.budget.id,
          style: GoogleFonts.dmSans(fontWeight: FontWeight.w700),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionLabel(text: _isCanceled ? 'Orçamento cancelado' : 'Editar orçamento'),
            const SizedBox(height: 12),
            _Field(label: 'Cliente', controller: _clientCtrl, enabled: !_isCanceled),
            _Field(label: 'Veículo', controller: _carCtrl, enabled: !_isCanceled),
            _Field(label: 'Placa', controller: _plateCtrl, enabled: !_isCanceled),
            _Field(label: 'Descrição', controller: _descCtrl, enabled: !_isCanceled, maxLines: 3),
            _Field(label: 'Valor', controller: _valueCtrl, enabled: !_isCanceled),
            const SizedBox(height: 8),
            Text(
              _isCanceled
                  ? 'Cancelado em ${widget.budget.canceledAt ?? '-'}'
                  : 'Aberto em ${widget.budget.createdAt}',
              style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
            ),
            const SizedBox(height: 20),
            if (_isCanceled)
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
                  child: const Text('Fechar'),
                ),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _save,
                  child: const Text('Salvar alterações'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _saving ? null : _approveBudget,
                  child: const Text('Aprovar e gerar OS'),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: _saving ? null : _cancelBudget,
                  child: Text(
                    'Cancelar orçamento',
                    style: GoogleFonts.dmSans(
                      color: red,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final bool enabled;
  final int maxLines;

  const _Field({
    required this.label,
    required this.controller,
    required this.enabled,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.dmSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: enabled,
            maxLines: maxLines,
            decoration: InputDecoration(
              filled: true,
              fillColor: enabled ? Colors.white : const Color(0xFFF3F4F6),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: borderColor),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: borderColor),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: borderColor),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
