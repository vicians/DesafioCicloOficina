import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../data/internal_flow_repository.dart';
import '../data/models/catalogo_servico_item.dart';
import '../data/models/internal_budget_item.dart';
import '../data/models/produto_item.dart';

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
  late List<BudgetLineItem> _services;
  late List<BudgetLineItem> _products;
  late final TextEditingController _obsCtrl;
  bool _saving = false;

  List<CatalogoServicoItem> _catalogoServicos = [];
  List<ProdutoItem> _produtosCatalog = [];
  bool _loadingCatalog = true;

  bool get _isCanceled => widget.budget.isCanceled;
  double get _total =>
      _services.fold(0.0, (s, e) => s + e.total) +
      _products.fold(0.0, (s, e) => s + e.total);

  @override
  void initState() {
    super.initState();
    _services = List.of(widget.budget.services);
    _products = List.of(widget.budget.products);
    _obsCtrl = TextEditingController(text: widget.budget.observation);
    _loadCatalog();
  }

  Future<void> _loadCatalog() async {
    final servicos = await widget.repository.fetchCatalogoServicos();
    final produtos = await widget.repository.fetchProdutos();
    if (!mounted) return;
    setState(() {
      _catalogoServicos = servicos;
      _produtosCatalog = produtos;
      _loadingCatalog = false;
    });
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = widget.budget.copyWith(
        services: _services,
        products: _products,
        observation: _obsCtrl.text.trim(),
      );
      await widget.repository.updateOrcamento(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Orçamento salvo com sucesso!')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao salvar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _cancelBudget() async {
    setState(() => _saving = true);
    try {
      await widget.repository.cancelOrcamento(widget.budget.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Orçamento cancelado.')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao cancelar: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _approveBudget() async {
    setState(() => _saving = true);
    try {
      final service = await widget.repository.approveOrcamento(widget.budget.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Orçamento aprovado! OS gerada.')),
      );
      Navigator.pop(context, service.id);
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().replaceFirst('Exception: ', '');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erro ao aprovar: $msg'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _addService() async {
    final picked = await showModalBottomSheet<CatalogoServicoItem>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CatalogPicker<CatalogoServicoItem>(
        title: 'Selecionar serviço',
        items: _catalogoServicos,
        labelOf: (s) => s.nome,
        priceOf: (s) => s.preco,
      ),
    );
    if (picked == null) return;
    setState(() {
      _services.add(BudgetLineItem(
        id: picked.id,
        name: picked.nome,
        unitPrice: picked.preco,
      ));
    });
  }

  Future<void> _addProduct() async {
    final picked = await showModalBottomSheet<ProdutoItem>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CatalogPicker<ProdutoItem>(
        title: 'Selecionar produto',
        items: _produtosCatalog,
        labelOf: (p) => p.marca != null ? '${p.nome} — ${p.marca}' : p.nome,
        priceOf: (p) => p.valor,
      ),
    );
    if (picked == null) return;
    setState(() {
      _products.add(BudgetLineItem(
        id: picked.id,
        name: picked.nome,
        unitPrice: picked.valor,
      ));
    });
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

            // Dados do cliente – sempre somente leitura
            _ReadOnlyField(label: 'Cliente', value: widget.budget.client),
            _ReadOnlyField(label: 'Veículo', value: widget.budget.car),
            _ReadOnlyField(label: 'Placa', value: widget.budget.plate),

            const SizedBox(height: 4),
            Text(
              _isCanceled
                  ? 'Cancelado em ${widget.budget.canceledAt ?? '-'}'
                  : 'Aberto em ${widget.budget.createdAt}',
              style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
            ),

            // Banner de avaliação do veículo
            if (widget.budget.isAvaliacao) ...[
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFEFF6FF),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF93C5FD)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.search_rounded,
                            color: Color(0xFF1D4ED8), size: 18),
                        const SizedBox(width: 8),
                        Text(
                          'Avaliação do veículo',
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1D4ED8),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'O cliente solicitou avaliação. Adicione os serviços necessários abaixo antes de aprovar.',
                      style: GoogleFonts.dmSans(
                          fontSize: 12, color: const Color(0xFF1E40AF)),
                    ),
                    if (widget.budget.notasCliente != null &&
                        widget.budget.notasCliente!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFF93C5FD)),
                        ),
                        child: Text(
                          '“${widget.budget.notasCliente}”',
                          style: GoogleFonts.dmSans(
                              fontSize: 12,
                              color: textPrimary,
                              fontStyle: FontStyle.italic),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            const SizedBox(height: 20),

            // Serviços
            _SectionLabel(text: 'Serviços'),
            const SizedBox(height: 8),
            if (_services.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Nenhum serviço adicionado.',
                  style: GoogleFonts.dmSans(fontSize: 13, color: textMuted),
                ),
              ),
            ..._services.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return _LineItemRow(
                item: item,
                enabled: !_isCanceled,
                onQtyChanged: (qty) => setState(() {
                  _services[i] = item.copyWith(qty: qty);
                }),
                onRemove: () => setState(() => _services.removeAt(i)),
              );
            }),
            if (!_isCanceled)
              _AddButton(
                label: 'Adicionar serviço',
                loading: _loadingCatalog,
                onTap: _addService,
              ),

            const SizedBox(height: 20),

            // Produtos
            _SectionLabel(text: 'Produtos'),
            const SizedBox(height: 8),
            if (_products.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  'Nenhum produto adicionado.',
                  style: GoogleFonts.dmSans(fontSize: 13, color: textMuted),
                ),
              ),
            ..._products.asMap().entries.map((entry) {
              final i = entry.key;
              final item = entry.value;
              return _LineItemRow(
                item: item,
                enabled: !_isCanceled,
                onQtyChanged: (qty) => setState(() {
                  _products[i] = item.copyWith(qty: qty);
                }),
                onRemove: () => setState(() => _products.removeAt(i)),
              );
            }),
            if (!_isCanceled)
              _AddButton(
                label: 'Adicionar produto',
                loading: _loadingCatalog,
                onTap: _addProduct,
              ),

            const SizedBox(height: 20),

            // Total
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Total',
                  style: GoogleFonts.dmSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textPrimary,
                  ),
                ),
                Text(
                  'R\$ ${_total.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: GoogleFonts.dmSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: navyDark,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // Observação
            if (!_isCanceled) ...[
              _SectionLabel(text: 'Observação'),
              const SizedBox(height: 8),
              TextField(
                controller: _obsCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  hintText: 'Alguma observação relevante...',
                  hintStyle: GoogleFonts.dmSans(fontSize: 13, color: textMuted),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: borderColor),
                  ),
                ),
              ),
              const SizedBox(height: 20),
            ] else if (widget.budget.observation.isNotEmpty) ...[
              _SectionLabel(text: 'Observação'),
              const SizedBox(height: 8),
              _ReadOnlyField(label: '', value: widget.budget.observation, showLabel: false),
              const SizedBox(height: 20),
            ],

            // Botões de ação
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
              // Para avaliação: só deixa aprovar se já tem serviços adicionados
              if (widget.budget.isAvaliacao && _services.isEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF8E1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: const Color(0xFFFFCC02)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded,
                          color: Color(0xFFF59E0B), size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Adicione pelo menos um serviço antes de gerar a OS.',
                          style: GoogleFonts.dmSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF92400E),
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
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
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Widgets auxiliares ────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;

  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: GoogleFonts.dmSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ),
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  final String label;
  final String value;
  final bool showLabel;

  const _ReadOnlyField({
    required this.label,
    required this.value,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showLabel && label.isNotEmpty) ...[
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 6),
          ],
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Text(
              value,
              style: GoogleFonts.dmSans(fontSize: 14, color: textPrimary),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineItemRow extends StatelessWidget {
  final BudgetLineItem item;
  final bool enabled;
  final ValueChanged<int> onQtyChanged;
  final VoidCallback onRemove;

  const _LineItemRow({
    required this.item,
    required this.enabled,
    required this.onQtyChanged,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'R\$ ${item.unitPrice.toStringAsFixed(2).replaceAll('.', ',')} × ${item.qty}  =  R\$ ${item.total.toStringAsFixed(2).replaceAll('.', ',')}',
                  style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
                ),
              ],
            ),
          ),
          if (enabled) ...[
            const SizedBox(width: 8),
            _QtyControl(
              qty: item.qty,
              onChanged: onQtyChanged,
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded, size: 18),
              color: red,
              onPressed: onRemove,
              visualDensity: VisualDensity.compact,
            ),
          ],
        ],
      ),
    );
  }
}

class _QtyControl extends StatelessWidget {
  final int qty;
  final ValueChanged<int> onChanged;

  const _QtyControl({required this.qty, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _QtyButton(
          icon: Icons.remove,
          onTap: qty > 1 ? () => onChanged(qty - 1) : null,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Text(
            '$qty',
            style: GoogleFonts.dmSans(
                fontSize: 13, fontWeight: FontWeight.w600, color: textPrimary),
          ),
        ),
        _QtyButton(icon: Icons.add, onTap: () => onChanged(qty + 1)),
      ],
    );
  }
}

class _QtyButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;

  const _QtyButton({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 26,
        height: 26,
        decoration: BoxDecoration(
          color: onTap != null
              ? navyDark.withValues(alpha: 0.1)
              : const Color(0xFFE5E7EB),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: 14,
          color: onTap != null ? navyDark : textMuted,
        ),
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback onTap;

  const _AddButton({
    required this.label,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(top: 4, bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(
            color: loading ? borderColor : navyDark,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              const SizedBox(
                width: 14,
                height: 14,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else
              Icon(Icons.add_rounded, size: 16, color: navyDark),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.dmSans(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: loading ? textMuted : navyDark,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogPicker<T> extends StatelessWidget {
  final String title;
  final List<T> items;
  final String Function(T) labelOf;
  final double Function(T) priceOf;

  const _CatalogPicker({
    required this.title,
    required this.items,
    required this.labelOf,
    required this.priceOf,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              title,
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
          ),
          const Divider(height: 1),
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.5,
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: items.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final item = items[i];
                return ListTile(
                  title: Text(
                    labelOf(item),
                    style: GoogleFonts.dmSans(
                        fontSize: 14, color: textPrimary),
                  ),
                  trailing: Text(
                    'R\$ ${priceOf(item).toStringAsFixed(2).replaceAll('.', ',')}',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: navyDark,
                    ),
                  ),
                  onTap: () => Navigator.pop(context, item),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
