import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_card.dart';
import '../data/internal_flow_repository.dart';
import '../data/models/internal_budget_item.dart';
import 'budget_detail_screen.dart';

class BudgetListScreen extends StatefulWidget {
  final InternalFlowRepository repository;
  final VoidCallback? onOpenDrawer;

  const BudgetListScreen({super.key, required this.repository, this.onOpenDrawer});

  @override
  State<BudgetListScreen> createState() => _BudgetListScreenState();
}

class _BudgetListScreenState extends State<BudgetListScreen>
  with SingleTickerProviderStateMixin {
  String _search = '';
  late Future<List<InternalBudgetItem>> _future;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _future = widget.repository.fetchOrcamentos();
    _tabController = TabController(length: 2, vsync: this);
    widget.repository.addListener(_reload);
  }

  @override
  void dispose() {
    _tabController.dispose();
    widget.repository.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    setState(() {
      _future = widget.repository.fetchOrcamentos();
    });
  }

  Future<void> _openBudget(InternalBudgetItem item) async {
    final result = await Navigator.push<Object?>(
      context,
      MaterialPageRoute(
        builder: (_) => BudgetDetailScreen(
          repository: widget.repository,
          budget: item,
        ),
      ),
    );

    if (!mounted || result == null) return;
    if (result is String) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Agendamento concluído. OS gerada: $result')),
      );
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Orçamento atualizado com sucesso.')),
    );
  }

  Future<void> _approve(InternalBudgetItem item) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Aprovar orçamento'),
        content: Text(
          'Deseja aprovar ${item.id} manualmente?',
          style: GoogleFonts.dmSans(fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Aprovar'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await widget.repository.approveOrcamento(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Orçamento ${item.id} marcado como aprovado.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao aprovar orçamento: $error')),
      );
    }
  }

  Future<void> _conclude(InternalBudgetItem item) async {
    try {
      final created = await widget.repository.concludeAgendamento(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Agendamento concluído. OS gerada: ${created.id}')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao concluir agendamento: $error')),
      );
    }
  }

  Future<void> _send(InternalBudgetItem item) async {
    try {
      await widget.repository.sendBudgetToClient(item.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Orçamento ${item.id} enviado para o cliente.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Falha ao enviar orçamento: $error')),
      );
    }
  }

  bool _matchesSearch(InternalBudgetItem b) {
    if (_search.isEmpty) return true;
    final q = _search.toLowerCase();
    return b.client.toLowerCase().contains(q) ||
        b.car.toLowerCase().contains(q) ||
        b.plate.toLowerCase().contains(q) ||
        b.id.toLowerCase().contains(q);
  }

  List<InternalBudgetItem> _itemsForTab(
    List<InternalBudgetItem> items,
    bool canceled,
  ) {
    return items.where((item) {
      final matchTab = canceled ? item.isCanceled : item.isPending;
      if (!matchTab) return false;

      // REGRA: Ocultar rascunhos vazios (Agendamentos em análise) da lista de orçamentos.
      // Eles devem ser editados via tela de Agendamentos.
      if (item.status == 'rascunho' &&
          item.services.isEmpty &&
          item.products.isEmpty) {
        return false;
      }

      return _matchesSearch(item);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [navyDark, navyMid],
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
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
                  Text(
                    'Orçamentos',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                onChanged: (v) => setState(() => _search = v),
                style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Buscar por cliente, veículo, placa ou ID...',
                  hintStyle: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: Colors.white.withValues(alpha: 0.6),
                  ),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 0,
                    vertical: 12,
                  ),
                ),
              ),
            ],
          ),
        ),
        Container(
          color: navyDark,
          child: TabBar(
            controller: _tabController,
            indicatorColor: orange,
            indicatorWeight: 2.5,
            labelColor: orange,
            unselectedLabelColor: Colors.white.withValues(alpha: 0.55),
            labelStyle: GoogleFonts.dmSans(
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
            tabs: const [
              Tab(text: 'Pendentes'),
              Tab(text: 'Cancelados'),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<InternalBudgetItem>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }

              if (snapshot.hasError) {
                return Center(
                  child: Text(
                    'Erro ao carregar orçamentos',
                    style: GoogleFonts.dmSans(fontSize: 14, color: textSecondary),
                  ),
                );
              }

              final allItems = snapshot.data ?? const <InternalBudgetItem>[];
              return TabBarView(
                controller: _tabController,
                children: [
                  _BudgetListView(
                    items: _itemsForTab(allItems, false),
                    emptyMessage: 'Nenhum orçamento pendente',
                    onApprove: _approve,
                    onConclude: _conclude,
                    onSend: _send,
                    onOpen: _openBudget,
                    onRefresh: _reload,
                  ),
                  _BudgetListView(
                    items: _itemsForTab(allItems, true),
                    emptyMessage: 'Nenhum orçamento cancelado',
                    onApprove: null,
                    onOpen: _openBudget,
                    onRefresh: _reload,
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

class _BudgetCard extends StatelessWidget {
  final InternalBudgetItem item;
  final VoidCallback? onApprove;
  final VoidCallback? onConclude;
  final VoidCallback? onSend;
  final VoidCallback onOpen;

  const _BudgetCard({
    required this.item,
    required this.onOpen,
    this.onApprove,
    this.onConclude,
    this.onSend,
  });

  String _statusLabel(String status) {
    switch (status) {
      case 'rascunho':
        return 'Rascunho';
      case 'enviado':
        return 'Enviado';
      case 'cancelado':
        return 'Cancelado';
      case 'rejeitado':
        return 'Rejeitado';
      case 'aprovado':
        return 'Aprovado';
      default:
        return status.isEmpty
            ? 'Pendente'
            : status[0].toUpperCase() + status.substring(1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onOpen,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.client,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.id} · ${item.car} · ${item.plate}',
                      style: GoogleFonts.dmSans(fontSize: 11, color: textMuted),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: item.isCanceled ? redBg : (item.status == 'aprovado' ? const Color(0xFFD1FAE5) : yellowBg),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  _statusLabel(item.status),
                  style: GoogleFonts.dmSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: item.isCanceled ? red : (item.status == 'aprovado' ? const Color(0xFF059669) : yellow),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            item.services.isNotEmpty
                ? item.services.map((s) => s.name).join(', ')
                : 'Sem serviços',
            style: GoogleFonts.dmSans(fontSize: 13, color: textSecondary),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                item.isCanceled
                    ? 'Cancelado em ${item.canceledAt ?? '-'}'
                    : 'Aberto em ${item.createdAt}',
                style: GoogleFonts.dmSans(fontSize: 12, color: textMuted),
              ),
              Text(
                'R\$ ${item.value.toStringAsFixed(2).replaceAll('.', ',')}',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
            ],
          ),
          if (!item.isCanceled) ...[
            const SizedBox(height: 12),
            if (item.status == 'rascunho')
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onSend,
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: const Text('Enviar para Cliente'),
                ),
              )
            else if (item.status == 'enviado')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: blueBg,
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: blue.withValues(alpha: 0.3)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hourglass_empty_rounded, color: blue, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      'Aguardando aprovação do cliente',
                      style: GoogleFonts.dmSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: blue,
                      ),
                    ),
                  ],
                ),
              )
            else if (item.status == 'aprovado')
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onConclude,
                  icon: const Icon(Icons.check_circle_rounded, size: 18),
                  style: FilledButton.styleFrom(backgroundColor: const Color(0xFF10B981)),
                  label: const Text('Concluir e Abrir OS'),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _BudgetListView extends StatelessWidget {
  final List<InternalBudgetItem> items;
  final String emptyMessage;
  final Future<void> Function(InternalBudgetItem)? onApprove;
  final Future<void> Function(InternalBudgetItem)? onConclude;
  final Future<void> Function(InternalBudgetItem)? onSend;
  final Future<void> Function(InternalBudgetItem) onOpen;
  final VoidCallback onRefresh;

  const _BudgetListView({
    required this.items,
    required this.emptyMessage,
    this.onApprove,
    this.onConclude,
    this.onSend,
    required this.onOpen,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          emptyMessage,
          style: GoogleFonts.dmSans(fontSize: 14, color: textSecondary),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => onRefresh(),
      color: orange,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        physics: const AlwaysScrollableScrollPhysics(),
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, i) {
          final item = items[i];
          return _BudgetCard(
            item: item,
            onOpen: () => onOpen(item),
            onApprove: onApprove == null ? null : () => onApprove!(item),
            onConclude: onConclude == null ? null : () => onConclude!(item),
            onSend: onSend == null ? null : () => onSend!(item),
          );
        },
      ),
    );
  }
}
