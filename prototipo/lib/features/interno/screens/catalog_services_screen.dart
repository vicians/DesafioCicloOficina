import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../services/catalog_service.dart';
import '../data/models/catalogo_servico_item.dart';

class CatalogServicesScreen extends StatefulWidget {
  final VoidCallback? onOpenDrawer;
  const CatalogServicesScreen({super.key, this.onOpenDrawer});

  @override
  State<CatalogServicesScreen> createState() => _CatalogServicesScreenState();
}

class _CatalogServicesScreenState extends State<CatalogServicesScreen> {
  List<CatalogoServicoItem> _services = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    final services = await CatalogService.getServices();
    if (!mounted) return;
    setState(() {
      _services = services;
      _isLoading = false;
    });
  }

  void _openEdit(CatalogoServicoItem service) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditServiceSheet(
        service: service,
        onSave: _handleSave,
        onDelete: _handleDelete,
      ),
    );
  }

  void _openAdd() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditServiceSheet(
        service: null,
        onSave: _handleAdd,
      ),
    );
  }

  Future<void> _handleDelete(String id) async {
    final ok = await CatalogService.deleteService(id);
    if (!mounted) return;
    if (ok) {
      setState(() => _services.removeWhere((s) => s.id == id));
      _showActionSnackbar(ok: true, msgSuccess: 'Serviço excluído', msgError: '');
    } else {
      _showActionSnackbar(ok: false, msgSuccess: '', msgError: 'Erro ao excluir serviço');
    }
  }

  Future<void> _handleSave(CatalogoServicoItem updated) async {
    final ok = await CatalogService.updateService(
      id: updated.id,
      nome: updated.nome,
      preco: updated.preco,
      descricao: updated.descricao,
      duracaoMinutos: updated.duracaoMinutos,
    );
    if (!mounted) return;
    if (ok) {
      await _fetchServices();
      _showActionSnackbar(ok: true, msgSuccess: 'Serviço salvo', msgError: '');
    } else {
      _showActionSnackbar(ok: false, msgSuccess: '', msgError: 'Erro ao salvar serviço');
    }
  }

  Future<void> _handleAdd(CatalogoServicoItem newService) async {
    final ok = await CatalogService.createService(
      nome: newService.nome,
      preco: newService.preco,
      descricao: newService.descricao,
      duracaoMinutos: newService.duracaoMinutos,
    );
    if (!mounted) return;
    if (ok) {
      await _fetchServices();
      _showActionSnackbar(ok: true, msgSuccess: 'Serviço criado', msgError: '');
    } else {
      _showActionSnackbar(ok: false, msgSuccess: '', msgError: 'Erro ao criar serviço');
    }
  }

  void _showActionSnackbar({required bool ok, required String msgSuccess, required String msgError}) {
    final msg = ok ? msgSuccess : msgError;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              ok ? Icons.check_circle_outline_rounded : Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: GoogleFonts.dmSans(color: Colors.white, fontSize: 13),
              ),
            ),
          ],
        ),
        backgroundColor: ok ? green : red,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _buildHeader(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(orange)))
              : _services.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _services.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _ServiceCard(
                        service: _services[i],
                        onEdit: () => _openEdit(_services[i]),
                      ),
                    ),
        ),
      ],
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [navyDark, navyMid],
        ),
      ),
      child: Row(
        children: [
          if (widget.onOpenDrawer != null) ...[
            Semantics(
              label: 'Abrir menu',
              button: true,
              child: GestureDetector(
                onTap: widget.onOpenDrawer,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.menu_rounded, size: 19, color: Colors.white),
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Catálogo de Serviços',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_services.length} ${_services.length == 1 ? 'serviço cadastrado' : 'serviços cadastrados'}',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: _openAdd,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: orange,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [orangeButtonShadow],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.add_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    'Adicionar',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.handyman_outlined, size: 48, color: textMuted),
          const SizedBox(height: 12),
          Text(
            'Nenhum serviço no catálogo',
            style: GoogleFonts.dmSans(fontSize: 14, color: textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final CatalogoServicoItem service;
  final VoidCallback onEdit;

  const _ServiceCard({
    required this.service,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [cardShadow],
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: blueBg,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.handyman_rounded,
                color: blue,
                size: 22,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    service.nome,
                    style: GoogleFonts.dmSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${service.duracaoMinutos} min${service.descricao != null && service.descricao!.isNotEmpty ? " • ${service.descricao}" : ""}',
                    style: GoogleFonts.dmSans(fontSize: 11, color: textSecondary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                const Icon(Icons.edit_rounded, size: 16, color: textMuted),
                const SizedBox(height: 6),
                Text(
                  'R\$ ${service.preco.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EditServiceSheet extends StatefulWidget {
  final CatalogoServicoItem? service;
  final void Function(CatalogoServicoItem) onSave;
  final void Function(String)? onDelete;

  const _EditServiceSheet({this.service, required this.onSave, this.onDelete});

  @override
  State<_EditServiceSheet> createState() => _EditServiceSheetState();
}

class _EditServiceSheetState extends State<_EditServiceSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _durationCtrl;

  @override
  void initState() {
    super.initState();
    final s = widget.service;
    _nameCtrl = TextEditingController(text: s?.nome ?? '');
    _descCtrl = TextEditingController(text: s?.descricao ?? '');
    _priceCtrl = TextEditingController(
      text: s != null ? s.preco.toStringAsFixed(2) : '',
    );
    _durationCtrl = TextEditingController(text: s != null ? '${s.duracaoMinutos}' : '60');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _priceCtrl.dispose();
    _durationCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final price = double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0;
    final duration = int.tryParse(_durationCtrl.text) ?? 60;

    final result = CatalogoServicoItem(
      id: widget.service?.id ?? 'LOCAL_${DateTime.now().millisecondsSinceEpoch}',
      nome: _nameCtrl.text.trim(),
      descricao: _descCtrl.text.trim(),
      preco: price,
      duracaoMinutos: duration,
    );

    Navigator.pop(context);
    widget.onSave(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.service != null;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: borderColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              child: Row(
                children: [
                  Text(
                    isEdit ? 'Editar Serviço' : 'Novo Serviço',
                    style: GoogleFonts.dmSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  if (isEdit && widget.onDelete != null)
                    GestureDetector(
                      onTap: () {
                        Navigator.pop(context);
                        widget.onDelete!(widget.service!.id);
                      },
                      child: const Icon(Icons.delete_outline_rounded, color: red, size: 22),
                    ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Field(
                        controller: _nameCtrl,
                        label: 'Nome do serviço',
                        hint: 'Ex: Troca de Óleo',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _descCtrl,
                        label: 'Descrição',
                        hint: 'Detalhes do serviço...',
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              controller: _priceCtrl,
                              label: 'Preço (R\$)',
                              hint: '0,00',
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (v) {
                                if (v == null || v.trim().isEmpty) return 'Obrigatório';
                                if (double.tryParse(v.replaceAll(',', '.')) == null) return 'Inválido';
                                return null;
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(
                              controller: _durationCtrl,
                              label: 'Duração (min)',
                              hint: '60',
                              keyboardType: TextInputType.number,
                              validator: (v) => (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      GestureDetector(
                        onTap: _submit,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: orange,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [orangeButtonShadow],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            'Salvar',
                            style: GoogleFonts.dmSans(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType keyboardType;
  final String? Function(String?)? validator;
  final int maxLines;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboardType = TextInputType.text,
    this.validator,
    this.maxLines = 1,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          validator: validator,
          maxLines: maxLines,
          style: GoogleFonts.dmSans(fontSize: 14, color: textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
            filled: true,
            fillColor: bgPage,
            contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: borderColor),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: borderColor),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: navyDark),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: red),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: red),
            ),
          ),
        ),
      ],
    );
  }
}
