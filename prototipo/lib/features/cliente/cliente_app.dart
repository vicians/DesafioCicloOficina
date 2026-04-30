import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/quick_action_fab.dart';
import '../../data/mock_data.dart';
import '../../services/firebase_messaging_service.dart';
import '../interno/screens/login_screen.dart';
import 'data/client_notification_api_repository.dart';
import 'data/client_notification_fallback_repository.dart';
import 'data/client_notification_mock_repository.dart';
import 'data/client_notification_repository.dart';
import 'screens/home_screen.dart';
import 'screens/budget_approval_screen.dart';
import 'screens/history_screen.dart';
import 'screens/notifications_screen.dart';

const _kApiBaseUrl = 'http://10.0.2.2:3000'; // Android emulator → localhost
const _kEnableDevClientSeedOnStartup = true;

class ClienteApp extends StatefulWidget {
  const ClienteApp({super.key});

  @override
  State<ClienteApp> createState() => _ClienteAppState();
}

class _ClienteAppState extends State<ClienteApp> {
  int _currentIndex = 0;
  late final ClientNotificationRepository _notificationRepository;
  List<NotificationItem> _clientNotifications = [];

  @override
  void initState() {
    super.initState();
    _notificationRepository = ClientNotificationFallbackRepository(
      primary: ClientNotificationApiRepository(baseUrl: _kApiBaseUrl),
      fallback: ClientNotificationMockRepository(),
    );
    _loadNotifications();
    _configureClientPushAndDevSeed();
  }

  Future<void> _loadNotifications() async {
    final items = await _notificationRepository.fetchNotifications();
    if (!mounted) return;
    setState(() => _clientNotifications = List.of(items));
  }

  Future<void> _markNotificationAsRead(String id) async {
    await _notificationRepository.markAsRead(id);
    await _loadNotifications();
  }

  Future<void> _configureClientPushAndDevSeed() async {
    await FirebaseMessagingService.configureClientNotifications(
      baseUrl: _kApiBaseUrl,
      triggerDevClientSeed: _kEnableDevClientSeedOnStartup,
    );
    await _loadNotifications();
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
  }

  List<Widget> get _screens => [
    HomeScreen(onLogout: _logout),
    const BudgetApprovalScreen(),
    const HistoryScreen(),
    NotificationsScreen(
      items: _clientNotifications,
      onMarkRead: _markNotificationAsRead,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final unreadCount = _clientNotifications.where((n) => n.unread).length;
    final hasPendingBudget = currentService.status == 'orcamento';

    return Scaffold(
      backgroundColor: bgPage,
      appBar: null,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: _currentIndex,
          children: _screens,
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? const QuickActionFab()
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: _ClienteNavBar(
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        unreadCount: unreadCount,
        hasPendingBudget: hasPendingBudget,
      ),
    );
  }
}

class _ClienteNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final int unreadCount;
  final bool hasPendingBudget;

  const _ClienteNavBar({
    required this.currentIndex,
    required this.onTap,
    required this.unreadCount,
    required this.hasPendingBudget,
  });

  @override
  Widget build(BuildContext context) {
    final tabs = [
      _NavTab(id: 0, label: 'Início', icon: Icons.home_rounded),
      _NavTab(id: 1, label: 'Orçamento', icon: Icons.receipt_long_rounded),
      _NavTab(id: 2, label: 'Histórico', icon: Icons.history_rounded),
      _NavTab(id: 3, label: 'Alertas', icon: Icons.notifications_rounded),
    ];

    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.95),
        border: const Border(top: BorderSide(color: borderColor, width: 1)),
        boxShadow: const [BoxShadow(color: Color(0x0A000000), blurRadius: 16, offset: Offset(0, -4))],
      ),
      child: SafeArea(
        child: SizedBox(
          height: 60,
          child: Row(
            children: tabs.map((tab) {
              final isActive = currentIndex == tab.id;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onTap(tab.id),
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
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  tab.icon,
                                  size: 22,
                                  color: isActive ? orange : textMuted,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  tab.label,
                                  style: GoogleFonts.dmSans(
                                    fontSize: 11,
                                    fontWeight: isActive
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                    color: isActive ? orange : textMuted,
                                  ),
                                ),
                              ],
                            ),
                            // Badge para notificações
                            if (tab.id == 3 && unreadCount > 0)
                              Positioned(
                                top: -4,
                                right: -10,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: red,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '$unreadCount',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            // Badge para orçamento
                            if (tab.id == 1 && hasPendingBudget)
                              Positioned(
                                top: -4,
                                right: -10,
                                child: Container(
                                  width: 16,
                                  height: 16,
                                  decoration: const BoxDecoration(
                                    color: yellow,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Center(
                                    child: Text(
                                      '1',
                                      style: GoogleFonts.dmSans(
                                        fontSize: 9,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }
}

class _NavTab {
  final int id;
  final String label;
  final IconData icon;
  const _NavTab({required this.id, required this.label, required this.icon});
}
