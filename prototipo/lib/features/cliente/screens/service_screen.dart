import 'package:flutter/material.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';

import '../../../core/widgets/app_card.dart';

import '../../../core/widgets/app_progress_bar.dart';

import '../../../data/mock_data.dart';



class ServiceScreen extends StatefulWidget {

  const ServiceScreen({super.key});



  @override

  State<ServiceScreen> createState() => _ServiceScreenState();

}



class _ServiceScreenState extends State<ServiceScreen> {

  bool _sortAscending = false;



  DateTime _parseDate(String dateStr) {

    final parts = dateStr.split(' ');

    if (parts.length != 3) return DateTime.now();

    int day = int.tryParse(parts[0]) ?? 1;

    int year = int.tryParse(parts[2]) ?? 2000;

    int month = 1;

    switch (parts[1].toLowerCase()) {

      case 'jan': month = 1; break;

      case 'fev': month = 2; break;

      case 'mar': month = 3; break;

      case 'abr': month = 4; break;

      case 'mai': month = 5; break;

      case 'jun': month = 6; break;

      case 'jul': month = 7; break;

      case 'ago': month = 8; break;

      case 'set': month = 9; break;

      case 'out': month = 10; break;

      case 'nov': month = 11; break;

      case 'dez': month = 12; break;

    }

    return DateTime(year, month, day);

  }



  @override

  Widget build(BuildContext context) {

    // Active services

    List<ServiceModel> activeServices = [currentService];

    activeServices.sort((a, b) {

      final da = _parseDate(a.startDate);

      final db = _parseDate(b.startDate);

      return _sortAscending ? da.compareTo(db) : db.compareTo(da);

    });



    // Completed services

    List<HistoryItem> completedServices = List.from(serviceHistory);

    completedServices.sort((a, b) {

      final da = _parseDate(a.date);

      final db = _parseDate(b.date);

      return _sortAscending ? da.compareTo(db) : db.compareTo(da);

    });



    return SingleChildScrollView(

      child: Column(

        crossAxisAlignment: CrossAxisAlignment.stretch,

        children: [

          _buildHeader(),

          Padding(

            padding: const EdgeInsets.all(20),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [

                if (activeServices.isNotEmpty) ...[

                  Text(

                    'EM ANDAMENTO',

                    style: GoogleFonts.dmSans(

                      fontSize: 12,

                      fontWeight: FontWeight.w700,

                      color: textMuted,

                      letterSpacing: 1.0,

                    ),

                  ),

                  const SizedBox(height: 12),

                  ...activeServices.map((svc) => _buildActiveCard(svc)),

                  const SizedBox(height: 24),

                ],

                if (completedServices.isNotEmpty) ...[

                  Text(

                    'CONCLUÍDOS',

                    style: GoogleFonts.dmSans(

                      fontSize: 12,

                      fontWeight: FontWeight.w700,

                      color: textMuted,

                      letterSpacing: 1.0,

                    ),

                  ),

                  const SizedBox(height: 12),

                  ...completedServices.map((item) => _buildCompletedCard(item)),

                ],

              ],

            ),

          ),

        ],

      ),

    );

  }



  Widget _buildHeader() {

    return Container(

      decoration: const BoxDecoration(

        gradient: LinearGradient(

          begin: Alignment.topLeft,

          end: Alignment.bottomRight,

          colors: [navyDark, navyMid],

        ),

      ),

      child: SafeArea(

        bottom: false,

        child: Padding(

          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),

          child: Column(

            crossAxisAlignment: CrossAxisAlignment.start,

            children: [

              Row(

                mainAxisAlignment: MainAxisAlignment.spaceBetween,

                children: [

                  Text(

                    'Histórico',

                    style: GoogleFonts.dmSans(

                      fontSize: 24,

                      fontWeight: FontWeight.w700,

                      color: Colors.white,

                    ),

                  ),

                  InkWell(

                    onTap: () {

                      setState(() {

                        _sortAscending = !_sortAscending;

                      });

                    },

                    borderRadius: BorderRadius.circular(8),

                    child: Container(

                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),

                      decoration: BoxDecoration(

                        color: Colors.white.withValues(alpha: 0.1),

                        borderRadius: BorderRadius.circular(8),

                        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),

                      ),

                      child: Row(

                        mainAxisSize: MainAxisSize.min,

                        children: [

                          Icon(

                            _sortAscending ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,

                            color: Colors.white,

                            size: 16,

                          ),

                          const SizedBox(width: 6),

                          Text(

                            'Data',

                            style: GoogleFonts.dmSans(

                              fontSize: 12,

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

              const SizedBox(height: 4),

              Text(

                'Todos os serviços do veículo',

                style: GoogleFonts.dmSans(

                  fontSize: 14,

                  color: Colors.white.withValues(alpha: 0.7),

                ),

              ),

            ],

          ),

        ),

      ),

    );

  }



  Widget _buildActiveCard(ServiceModel svc) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 12),

      child: AppCard(

        child: Column(

          crossAxisAlignment: CrossAxisAlignment.start,

          children: [

            Row(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Container(

                  width: 48,

                  height: 48,

                  decoration: BoxDecoration(

                    color: blueBg,

                    borderRadius: BorderRadius.circular(12),

                  ),

                  child: const Icon(Icons.build_outlined, color: blue, size: 24),

                ),

                const SizedBox(width: 16),

                Expanded(

                  child: Column(

                    crossAxisAlignment: CrossAxisAlignment.start,

                    children: [

                      Text(

                        svc.title,

                        style: GoogleFonts.dmSans(

                          fontSize: 15,

                          fontWeight: FontWeight.w700,

                          color: textPrimary,

                        ),

                      ),

                      const SizedBox(height: 8),

                      Container(

                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),

                        decoration: BoxDecoration(

                          color: blueBg,

                          borderRadius: BorderRadius.circular(20),

                        ),

                        child: Row(

                          mainAxisSize: MainAxisSize.min,

                          children: [

                            Container(

                              width: 6,

                              height: 6,

                              decoration: const BoxDecoration(

                                color: blue,

                                shape: BoxShape.circle,

                              ),

                            ),

                            const SizedBox(width: 6),

                            Text(

                              'Em andamento',

                              style: GoogleFonts.dmSans(

                                fontSize: 11,

                                fontWeight: FontWeight.w700,

                                color: blue,

                              ),

                            ),

                          ],

                        ),

                      ),

                    ],

                  ),

                ),

              ],

            ),

            const SizedBox(height: 16),

            AppProgressBar(percent: svc.progress.toDouble()),

            const SizedBox(height: 8),

            Text(

              '${svc.progress}% • ${svc.estimatedEnd}',

              style: GoogleFonts.dmSans(

                fontSize: 12,

                color: textSecondary,

              ),

            ),

          ],

        ),

      ),

    );

  }



  Widget _buildCompletedCard(HistoryItem item) {

    return Padding(

      padding: const EdgeInsets.only(bottom: 12),

      child: AppCard(

        child: Row(

          children: [

            Container(

              width: 48,

              height: 48,

              decoration: BoxDecoration(

                color: greenBg,

                borderRadius: BorderRadius.circular(12),

              ),

              child: const Icon(Icons.check_rounded, color: green, size: 24),

            ),

            const SizedBox(width: 16),

            Expanded(

              child: Column(

                crossAxisAlignment: CrossAxisAlignment.start,

                children: [

                  Text(

                    item.title,

                    style: GoogleFonts.dmSans(

                      fontSize: 14,

                      fontWeight: FontWeight.w700,

                      color: textPrimary,

                    ),

                  ),

                  const SizedBox(height: 4),

                  Text(

                    '${item.date} • ${item.id}',

                    style: GoogleFonts.dmSans(

                      fontSize: 12,

                      color: textMuted,

                    ),

                  ),

                ],

              ),

            ),

            const SizedBox(width: 12),

            Text(

              item.total,

              style: GoogleFonts.dmSans(

                fontSize: 14,

                fontWeight: FontWeight.w700,

                color: textPrimary,

              ),

            ),

          ],

        ),

      ),

    );

  }

}

