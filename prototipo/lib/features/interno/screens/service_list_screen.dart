import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/status_badge.dart';
import '../../../data/mock_data.dart';
import 'internal_service_detail_screen.dart';

class ServiceListScreen extends StatefulWidget {
  final String? initialFilter;

  const ServiceListScreen({super.key, this.initialFilter});

  @override
  State<ServiceListScreen> createState() => _ServiceListScreenState();
}

class _ServiceListScreenState extends State<ServiceListScreen> {
  String _filter = 'todos';
  String _search = '';

  final _filters = [
    ('todos', 'Todos'),
    ('andamento', 'Andamento'),
    ('orcamento', 'Orçamento'),
    ('aguardando', 'Aguardando'),
    ('concluido', 'Concluído'),
  ];

  @override
  void initState() {
    super.initState();
    _filter = widget.initialFilter ?? 'todos';
  }

  List<InternalService> get _filtered {
    var list = internalServices.where((s) {
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        return s.client.toLowerCase().contains(q) ||
            s.car.toLowerCase().contains(q) ||
            s.id.toLowerCase().contains(q);
      }
      return true;
    }).toList();
    if (_filter != 'todos') {
      list = list.where((s) => s.status == _filter).toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ListHeader(
          search: _search,
          onSearch: (v) => setState(() => _search = v),
        ),
        _FilterBar(
          filters: _filters,
          active: _filter,
          onSelect: (f) => setState(() => _filter = f),
        ),
        Expanded(
          child: _filtered.isEmpty
              ? Center(
                  child: Text(
                    'Nenhum atendimento encontrado',
                    style: GoogleFonts.dmSans(
                        fontSize: 14, color: textSecondary),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _filtered.length,
                  separatorBuilder: (ctx, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _ServiceListCard(svc: _filtered[i]),
                ),
        ),
      ],
    );
  }
}

class _ListHeader extends StatelessWidget {
  final String search;
  final ValueChanged<String> onSearch;

  const _ListHeader({required this.search, required this.onSearch});

  @override
  Widget build(BuildContext context) {
    return Container(
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
          Text(
            'Serviços',
            style: GoogleFonts.dmSans(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: onSearch,
            style: GoogleFonts.dmSans(fontSize: 14, color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Buscar cliente, carro ou OS...',
              hintStyle: GoogleFonts.dmSans(
                  fontSize: 14, color: Colors.white.withValues(alpha: 0.5)),
              prefixIcon:
                  Icon(Icons.search_rounded, color: Colors.white.withValues(alpha: 0.6)),
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
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 0, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final List<(String, String)> filters;
  final String active;
  final ValueChanged<String> onSelect;

  const _FilterBar({
    required this.filters,
    required this.active,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: bgPage,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: filters.map((f) {
            final isActive = f.$1 == active;
            return Padding(
              padding: const EdgeInsets.only(right: 6),
              child: GestureDetector(
                onTap: () => onSelect(f.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 7),
                  decoration: BoxDecoration(
                    color: isActive ? navyDark : cardWhite,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isActive ? navyDark : borderColor,
                    ),
                  ),
                  child: Text(
                    f.$2,
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: isActive ? Colors.white : textSecondary,
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

class _ServiceListCard extends StatelessWidget {
  final InternalService svc;
  const _ServiceListCard({required this.svc});

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => InternalServiceDetailScreen(service: svc),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      svc.client,
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: textPrimary,
                      ),
                    ),
                    Text(
                      '${svc.id} · ${svc.car} · ${svc.plate}',
                      style:
                          GoogleFonts.dmSans(fontSize: 11, color: textMuted),
                    ),
                  ],
                ),
              ),
              StatusBadge(status: svc.status),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            svc.service,
            style: GoogleFonts.dmSans(fontSize: 13, color: textSecondary),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  AppAvatar(
                    initials: svc.mechanic.isNotEmpty &&
                            svc.mechanic != '—'
                        ? svc.mechanic.substring(0, 1).toUpperCase()
                        : '?',
                    size: 24,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    svc.mechanic,
                    style:
                        GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
                  ),
                ],
              ),
              Text(
                'R\$ ${svc.value.toStringAsFixed(2).replaceAll('.', ',')}',
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: textPrimary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
