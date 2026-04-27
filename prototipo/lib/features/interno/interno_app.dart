import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import 'screens/employee_dashboard_screen.dart';
import 'screens/service_list_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/login_screen.dart';

class InternoApp extends StatefulWidget {
  final bool isManager;

  const InternoApp({super.key, required this.isManager});

  @override
  State<InternoApp> createState() => _InternoAppState();
}

class _InternoAppState extends State<InternoApp> {
  int _currentIndex = 0;

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  List<Widget> get _screens {
    if (widget.isManager) {
      return [
        EmployeeDashboardScreen(
            isManager: true, onLogout: _logout),
        const ServiceListScreen(initialFilter: null),
        const InventoryScreen(),
        const ReportsScreen(),
      ];
    }
    return [
      EmployeeDashboardScreen(
          isManager: false, onLogout: _logout),
      const ServiceListScreen(initialFilter: null),
      const _MessagesPlaceholder(),
    ];
  }

  List<_NavItem> get _navItems {
    if (widget.isManager) {
      return [
        _NavItem(label: 'Dashboard', icon: Icons.dashboard_rounded),
        _NavItem(label: 'Serviços', icon: Icons.build_rounded),
        _NavItem(label: 'Estoque', icon: Icons.inventory_2_rounded),
        _NavItem(label: 'Relatórios', icon: Icons.bar_chart_rounded),
      ];
    }
    return [
      _NavItem(label: 'Dashboard', icon: Icons.dashboard_rounded),
      _NavItem(label: 'Serviços', icon: Icons.build_rounded),
      _NavItem(label: 'Mensagens', icon: Icons.chat_bubble_rounded),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      bottomNavigationBar: _InternoNavBar(
        items: _navItems,
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
      ),
    );
  }
}

class _NavItem {
  final String label;
  final IconData icon;
  const _NavItem({required this.label, required this.icon});
}

class _InternoNavBar extends StatelessWidget {
  final List<_NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  const _InternoNavBar({
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: borderColor, width: 1)),
        boxShadow: const [
          BoxShadow(
              color: Color(0x0A000000),
              blurRadius: 16,
              offset: Offset(0, -4))
        ],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(items.length, (i) {
              final item = items[i];
              final isActive = i == currentIndex;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Stack(
                    alignment: Alignment.topCenter,
                    children: [
                      if (isActive)
                        Positioned(
                          top: 0,
                          left: 8,
                          right: 8,
                          child: Container(
                            height: 2.5,
                            decoration: BoxDecoration(
                              color: orange,
                              borderRadius: BorderRadius.circular(99),
                            ),
                          ),
                        ),
                      Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              size: 22,
                              color: isActive ? orange : textMuted,
                            ),
                            const SizedBox(height: 3),
                            Text(
                              item.label,
                              style: GoogleFonts.dmSans(
                                fontSize: 10,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: isActive ? orange : textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _MessagesPlaceholder extends StatelessWidget {
  const _MessagesPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
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
              Text(
                'Mensagens',
                style: GoogleFonts.dmSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat_bubble_outline_rounded,
                    size: 48, color: textMuted),
                const SizedBox(height: 12),
                Text(
                  'Selecione um atendimento\npara acessar o chat',
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
