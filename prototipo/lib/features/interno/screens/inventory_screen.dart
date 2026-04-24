import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_progress_bar.dart';
import '../../../data/mock_data.dart';

class InventoryScreen extends StatelessWidget {
  const InventoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lowItems = partsInventory.where((p) => p.status == 'low').toList();

    return Column(
      children: [
        _InventoryHeader(),
        if (lowItems.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: _LowStockBanner(count: lowItems.length),
          ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: partsInventory.length,
            separatorBuilder: (ctx, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _PartCard(part: partsInventory[i]),
          ),
        ),
      ],
    );
  }
}

class _InventoryHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
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
                  '${partsInventory.length} itens cadastrados',
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    color: Colors.white.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {},
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: orange,
                borderRadius: BorderRadius.circular(10),
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
}

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
              '$count ${count == 1 ? 'item está' : 'itens estão'} abaixo do estoque mínimo',
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

class _PartCard extends StatelessWidget {
  final PartItem part;
  const _PartCard({required this.part});

  @override
  Widget build(BuildContext context) {
    final isLow = part.status == 'low';
    final pct = ((part.qty / (part.min * 2)) * 100).clamp(0, 100).toDouble();
    final barColor = isLow ? red : green;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardWhite,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [cardShadow],
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
                    Text(
                      part.category,
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: textMuted),
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '${part.qty}',
                    style: GoogleFonts.dmSans(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: isLow ? red : textPrimary,
                    ),
                  ),
                  Text(
                    part.unit,
                    style: GoogleFonts.dmSans(
                        fontSize: 11, color: textMuted),
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
                style:
                    GoogleFonts.dmSans(fontSize: 11, color: textSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
