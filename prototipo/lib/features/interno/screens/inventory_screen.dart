import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../data/mock_data.dart';
import '../../../services/inventory_service.dart';

class InventoryScreen extends StatefulWidget {
  const InventoryScreen({super.key});

  @override
  State<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends State<InventoryScreen> {
  List<PartItem> _parts = [];
  String? _activeCategory;
  String? _syncingPartId;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchProducts();
  }

  Future<void> _fetchProducts() async {
    final parts = await InventoryService.getProducts();
    if (!mounted) return;
    setState(() {
      _parts = parts;
      _isLoading = false;
    });
  }

  List<String> get _categories {
    final cats = _parts.map((p) => p.category).toSet().toList()..sort();
    return cats;
  }

  List<PartItem> get _filteredParts {
    if (_activeCategory == null) return _parts;
    return _parts.where((p) => p.category == _activeCategory).toList();
  }

  List<PartItem> get _lowStockParts => _parts.where((p) => p.qty < p.min).toList();

  void _openEdit(PartItem part) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EditPartSheet(
        part: part,
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
      builder: (_) => _EditPartSheet(
        part: null,
        onSave: _handleAdd,
      ),
    );
  }

  Future<void> _handleDelete(String id) async {
    setState(() => _syncingPartId = id);
    final ok = await InventoryService.deleteProduct(id);
    if (!mounted) return;
    setState(() {
      _syncingPartId = null;
      if (ok) {
        _parts.removeWhere((p) => p.id == id);
      }
    });
    _showActionSnackbar(ok: ok, msgSuccess: 'Item excluído', msgError: 'Erro ao excluir item');
  }

  Future<void> _handleAdjustStock(PartItem part, int delta) async {
    final newQty = part.qty + delta;
    if (newQty < 0) return;

    final updated = PartItem(
      id: part.id,
      name: part.name,
      category: part.category,
      qty: newQty,
      min: part.min,
      unit: part.unit,
      price: part.price,
      status: newQty < part.min ? 'low' : 'ok',
    );

    setState(() {
      final idx = _parts.indexWhere((p) => p.id == updated.id);
      if (idx != -1) _parts[idx] = updated;
      _syncingPartId = updated.id;
    });

    final ok = await InventoryService.syncProductWithRag(
      id: updated.id,
      nome: updated.name,
      categoria: updated.category,
      quantidade: updated.qty,
      min: updated.min,
      unit: updated.unit,
      preco: updated.price,
    );

    if (!mounted) return;
    setState(() => _syncingPartId = null);
    if (!ok) {
      _showActionSnackbar(ok: false, msgSuccess: '', msgError: 'Erro de conexão com o servidor');
    }
  }

  Future<void> _handleSave(PartItem updated) async {
    setState(() {
      final idx = _parts.indexWhere((p) => p.id == updated.id);
      if (idx != -1) _parts[idx] = updated;
      _syncingPartId = updated.id;
    });

    final ok = await InventoryService.syncProductWithRag(
      id: updated.id,
      nome: updated.name,
      categoria: updated.category,
      quantidade: updated.qty,
      min: updated.min,
      unit: updated.unit,
      preco: updated.price,
    );

    if (!mounted) return;
    setState(() => _syncingPartId = null);
    _showActionSnackbar(ok: ok, msgSuccess: 'Salvo e sincronizado', msgError: 'Erro ao salvar no servidor');
  }

  Future<void> _handleAdd(PartItem newPart) async {
    setState(() {
      _parts.add(newPart);
      _syncingPartId = newPart.id;
    });

    final ok = await InventoryService.createProduct(
      nome: newPart.name,
      quantidade: newPart.qty,
      preco: newPart.price,
      categoria: newPart.category,
      min: newPart.min,
      unit: newPart.unit,
    );

    if (!mounted) return;
    setState(() => _syncingPartId = null);
    if (ok) {
      _fetchProducts(); // refresh to get the actual ID
    }
    _showActionSnackbar(ok: ok, msgSuccess: 'Item criado', msgError: 'Erro ao criar no servidor');
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
    final lowStock = _lowStockParts;
    final filtered = _filteredParts;

    return Column(
      children: [
        _buildHeader(),
        if (lowStock.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _LowStockBanner(count: lowStock.length),
          ),
        _buildCategoryFilter(),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator(valueColor: AlwaysStoppedAnimation<Color>(orange)))
              : filtered.isEmpty
                  ? _buildEmpty()
                  : ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) => _PartCard(
                        part: filtered[i],
                        isSyncing: _syncingPartId == filtered[i].id,
                        onEdit: () => _openEdit(filtered[i]),
                        onAdjustStock: (delta) => _handleAdjustStock(filtered[i], delta),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Estoque',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_parts.length} ${_parts.length == 1 ? 'item cadastrado' : 'itens cadastrados'}',
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

  Widget _buildCategoryFilter() {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          _FilterChip(
            label: 'Todos',
            isActive: _activeCategory == null,
            onTap: () => setState(() => _activeCategory = null),
          ),
          ..._categories.map(
            (cat) => Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _FilterChip(
                label: cat,
                isActive: _activeCategory == cat,
                onTap: () => setState(() => _activeCategory = cat),
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
          const Icon(Icons.inventory_2_outlined, size: 48, color: textMuted),
          const SizedBox(height: 12),
          Text(
            'Nenhum item nesta categoria',
            style: GoogleFonts.dmSans(fontSize: 14, color: textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Filter Chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isActive ? navyDark : cardWhite,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: isActive ? navyDark : borderColor),
        ),
        child: Text(
          label,
          style: GoogleFonts.dmSans(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isActive ? Colors.white : textSecondary,
          ),
        ),
      ),
    );
  }
}

// ── Low Stock Banner ──────────────────────────────────────────────────────────

class _LowStockBanner extends StatelessWidget {
  final int count;
  const _LowStockBanner({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: redBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: red.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_rounded, color: red, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$count ${count == 1 ? 'item abaixo' : 'itens abaixo'} do mínimo recomendado — reposição necessária',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: red,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Part Card ─────────────────────────────────────────────────────────────────

class _PartCard extends StatelessWidget {
  final PartItem part;
  final bool isSyncing;
  final VoidCallback onEdit;
  final void Function(int)? onAdjustStock;

  const _PartCard({
    required this.part,
    required this.isSyncing,
    required this.onEdit,
    this.onAdjustStock,
  });

  @override
  Widget build(BuildContext context) {
    final isLow = part.qty < part.min;
    final pct = ((part.qty / (part.min * 2)) * 100).clamp(0.0, 100.0);
    final barColor = isLow ? red : green;

    return GestureDetector(
      onTap: onEdit,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardWhite,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [cardShadow],
          border: isLow ? Border.all(color: red.withValues(alpha: 0.2)) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: isLow ? redBg : greenBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.label_rounded,
                    color: isLow ? red : green,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        part.name,
                        style: GoogleFonts.dmSans(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(
                            part.category,
                            style: GoogleFonts.dmSans(
                                fontSize: 11, color: textMuted),
                          ),
                          if (isLow) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: redBg,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                'Repor',
                                style: GoogleFonts.dmSans(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: red,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    if (isSyncing)
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(orange),
                        ),
                      )
                    else
                      const Icon(Icons.edit_rounded,
                          size: 16, color: textMuted),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: (isSyncing || onAdjustStock == null) ? null : () => onAdjustStock!(-1),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: cardWhite,
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.remove_rounded, size: 14, color: textSecondary),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Text(
                              '${part.qty}',
                              style: GoogleFonts.dmSans(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: isLow ? red : textPrimary,
                              ),
                            ),
                            Text(
                              part.unit,
                              style: GoogleFonts.dmSans(fontSize: 10, color: textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: (isSyncing || onAdjustStock == null) ? null : () => onAdjustStock!(1),
                          child: Container(
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: cardWhite,
                              border: Border.all(color: borderColor),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Icon(Icons.add_rounded, size: 14, color: textSecondary),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            AppProgressBar(percent: pct, color: barColor),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Mínimo: ${part.min} ${part.unit}',
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: textSecondary),
                ),
                Text(
                  'R\$ ${part.price.toStringAsFixed(2).replaceAll('.', ',')}/${part.unit}',
                  style: GoogleFonts.dmSans(
                      fontSize: 11, color: textSecondary),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ── Edit / Add Bottom Sheet ───────────────────────────────────────────────────

class _EditPartSheet extends StatefulWidget {
  final PartItem? part;
  final void Function(PartItem) onSave;
  final void Function(String)? onDelete;

  const _EditPartSheet({this.part, required this.onSave, this.onDelete});

  @override
  State<_EditPartSheet> createState() => _EditPartSheetState();
}

class _EditPartSheetState extends State<_EditPartSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _categoryCtrl;
  late final TextEditingController _qtyCtrl;
  late final TextEditingController _minCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _unitCtrl;

  @override
  void initState() {
    super.initState();
    final p = widget.part;
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _categoryCtrl = TextEditingController(text: p?.category ?? '');
    _qtyCtrl = TextEditingController(text: p != null ? '${p.qty}' : '');
    _minCtrl = TextEditingController(text: p != null ? '${p.min}' : '10');
    _priceCtrl = TextEditingController(
      text: p != null ? p.price.toStringAsFixed(2) : '',
    );
    _unitCtrl = TextEditingController(text: p?.unit ?? 'unid.');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _categoryCtrl.dispose();
    _qtyCtrl.dispose();
    _minCtrl.dispose();
    _priceCtrl.dispose();
    _unitCtrl.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    final qty = int.tryParse(_qtyCtrl.text) ?? 0;
    final min = int.tryParse(_minCtrl.text) ?? 10;
    final price =
        double.tryParse(_priceCtrl.text.replaceAll(',', '.')) ?? 0.0;

    final result = PartItem(
      id: widget.part?.id ?? 'LOCAL_${DateTime.now().millisecondsSinceEpoch}',
      name: _nameCtrl.text.trim(),
      category: _categoryCtrl.text.trim(),
      qty: qty,
      min: min,
      unit: _unitCtrl.text.trim().isEmpty ? 'unid.' : _unitCtrl.text.trim(),
      price: price,
      status: qty < min ? 'low' : 'ok',
    );

    Navigator.pop(context);
    widget.onSave(result);
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.part != null;

    return Padding(
      padding:
          EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
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
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: Row(
                children: [
                  Text(
                    isEdit ? 'Editar item' : 'Novo item',
                    style: GoogleFonts.dmSans(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: blueBg,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.sync_rounded,
                            size: 12, color: blue),
                        const SizedBox(width: 4),
                        Text(
                          'Sincroniza com IA',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: blue,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Field(
                        controller: _nameCtrl,
                        label: 'Nome do item',
                        hint: 'Ex: Óleo Motor 5W30',
                        validator: (v) =>
                            (v == null || v.trim().isEmpty) ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: _Field(
                              controller: _categoryCtrl,
                              label: 'Categoria',
                              hint: 'Ex: Lubrificantes',
                              validator: (v) =>
                                  (v == null || v.trim().isEmpty)
                                      ? 'Obrigatório'
                                      : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: _Field(
                              controller: _unitCtrl,
                              label: 'Unidade',
                              hint: 'litro / unid.',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              controller: _qtyCtrl,
                              label: 'Quantidade',
                              hint: '0',
                              keyboard: TextInputType.number,
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                              validator: (v) =>
                                  (v == null || v.isEmpty) ? 'Obrigatório' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _Field(
                              controller: _minCtrl,
                              label: 'Mínimo (alerta)',
                              hint: '10',
                              keyboard: TextInputType.number,
                              formatters: [
                                FilteringTextInputFormatter.digitsOnly
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _priceCtrl,
                        label: 'Preço unitário (R\$)',
                        hint: '0,00',
                        keyboard: const TextInputType.numberWithOptions(
                            decimal: true),
                        validator: (v) =>
                            (v == null || v.isEmpty) ? 'Obrigatório' : null,
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: GestureDetector(
                          onTap: _submit,
                          child: Container(
                            padding:
                                const EdgeInsets.symmetric(vertical: 14),
                            decoration: BoxDecoration(
                              color: orange,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [orangeButtonShadow],
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  isEdit
                                      ? Icons.save_rounded
                                      : Icons.add_rounded,
                                  color: Colors.white,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  isEdit
                                      ? 'Salvar e sincronizar IA'
                                      : 'Adicionar ao estoque',
                                  style: GoogleFonts.dmSans(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (isEdit && widget.onDelete != null) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pop(context);
                              widget.onDelete!(widget.part!.id);
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              decoration: BoxDecoration(
                                color: redBg,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: red.withValues(alpha: 0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Icon(Icons.delete_rounded, color: red, size: 18),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Excluir item',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: red,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
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

// ── Reusable form field ───────────────────────────────────────────────────────

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final TextInputType? keyboard;
  final List<TextInputFormatter>? formatters;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    required this.hint,
    this.keyboard,
    this.formatters,
    this.validator,
  });

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
            color: textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          keyboardType: keyboard,
          inputFormatters: formatters,
          validator: validator,
          style: GoogleFonts.dmSans(fontSize: 14, color: textPrimary),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.dmSans(fontSize: 14, color: textMuted),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: borderColor, width: 1.5),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: borderColor, width: 1.5),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: navyDark, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: red, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: red, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }
}
