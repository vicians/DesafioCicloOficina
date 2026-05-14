import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/quick_action_fab.dart';
import '../../core/config/api_config.dart';
import '../shared/models/notification_item.dart';
import '../../services/firebase_messaging_service.dart';
import '../interno/screens/login_screen.dart';
import '../../core/widgets/side_drawer.dart' show LogoutConfirmSheet;
import 'data/client_notification_api_repository.dart';
import 'data/client_notification_repository.dart';
import 'data/client_schedule_api_repository.dart';
import 'data/client_flow_api_repository.dart';
import 'data/client_flow_repository.dart';
import 'data/models/client_models.dart';
import 'screens/home_screen.dart';
import 'screens/budget_approval_screen.dart';
import 'screens/history_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/schedule_service_sheet.dart';
import 'screens/client_side_drawer.dart';
import 'screens/edit_profile_screen.dart';
import 'screens/change_password_screen.dart';

final _kApiBaseUrl = ApiConfig.baseUrl;
const _kEnableDevClientSeedOnStartup = true;

class ClienteApp extends StatefulWidget {
  final String clientId;
  const ClienteApp({super.key, required this.clientId});

  @override
  State<ClienteApp> createState() => _ClienteAppState();
}

class _ClienteAppState extends State<ClienteApp> {
  int _currentIndex = 0;
  bool _drawerOpen = false;
  bool _showLogoutConfirm = false;

  late final ClientNotificationRepository _notificationRepository;
  late final ClientScheduleApiRepository _scheduleRepository;
  late final ClientFlowRepository _flowRepository;
  List<NotificationItem> _clientNotifications = [];
  ServiceModel? _currentService;

  @override
  void initState() {
    super.initState();
    _notificationRepository = ClientNotificationApiRepository(
      baseUrl: _kApiBaseUrl,
      clientId: widget.clientId,
    );
    _scheduleRepository = ClientScheduleApiRepository(
      baseUrl: _kApiBaseUrl,
      clientId: widget.clientId,
    );
    _flowRepository = ClientFlowApiRepository(
      baseUrl: _kApiBaseUrl,
      clientId: widget.clientId,
    );
    _loadNotifications();
    _loadCurrentService();
    _flowRepository.addListener(_loadCurrentService);
    _configureClientPushAndDevSeed();
  }

  Future<void> _loadCurrentService() async {
    final svc = await _flowRepository.fetchCurrentService();
    if (!mounted) return;
    setState(() => _currentService = svc);
  }

  Future<void> _openScheduleFlow() async {
    await showClientScheduleSheet(
      context,
      repository: _scheduleRepository,
    );
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

  Future<void> _markAllNotificationsAsRead() async {
    await _notificationRepository.markAllAsRead();
    await _loadNotifications();
  }

  Future<void> _configureClientPushAndDevSeed() async {
    await FirebaseMessagingService.configureClientNotifications(
      baseUrl: _kApiBaseUrl,
      clientId: widget.clientId,
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

  void _requestLogout() {
    setState(() {
      _drawerOpen = false;
      _showLogoutConfirm = true;
    });
  }

  int get _unreadCount => _clientNotifications.where((n) => n.unread).length;

  // The first 3 screens are cached to avoid rebuilds when drawer opens/closes (prevents flicker).
  // NotificationsScreen is rebuilt when _clientNotifications changes — that's intentional.
  late final BudgetApprovalScreen _budgetScreen = BudgetApprovalScreen(
    repository: _flowRepository,
    onOpenDrawer: () => setState(() => _drawerOpen = true),
  );
  late final HistoryScreen _historyScreen = HistoryScreen(
    repository: _flowRepository,
    onOpenDrawer: () => setState(() => _drawerOpen = true),
  );

  List<Widget> get _screens => [
    HomeScreen(
      onLogout: _logout,
      onOpenDrawer: () => setState(() => _drawerOpen = true),
      onOpenAlerts: () => setState(() => _currentIndex = 3),
      repository: _flowRepository,
      unreadCount: _unreadCount,
    ),
    _budgetScreen,
    _historyScreen,
    NotificationsScreen(
      items: _clientNotifications,
      onMarkRead: _markNotificationAsRead,
      onMarkAllRead: _markAllNotificationsAsRead,
      onOpenDrawer: () => setState(() => _drawerOpen = true),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final hasPendingBudget = _currentService?.status == 'orcamento' || _currentService?.status == 'enviado';

    return Scaffold(
      backgroundColor: bgPage,
      appBar: null,
      body: Stack(
        children: [
          // Main content
          IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),

          // Client side drawer overlay
          if (_drawerOpen)
            ClientSideDrawer(
              onClose: () => setState(() => _drawerOpen = false),
              onOpenEditProfile: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => EditProfileScreen(
                    clientId: widget.clientId,
                    baseUrl: _kApiBaseUrl,
                    onSaved: _flowRepository.invalidateProfile,
                  ),
                ),
              ),
              onOpenChangePassword: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ChangePasswordScreen(
                    clientId: widget.clientId,
                    baseUrl: _kApiBaseUrl,
                  ),
                ),
              ),
              onLogoutRequest: _requestLogout,
            ),

          // Logout confirmation sheet overlay
          if (_showLogoutConfirm) ...[
            GestureDetector(
              onTap: () => setState(() => _showLogoutConfirm = false),
              child: Container(color: Colors.black.withValues(alpha: 0.5)),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: LogoutConfirmSheet(
                onConfirm: () {
                  setState(() => _showLogoutConfirm = false);
                  _logout();
                },
                onCancel: () => setState(() => _showLogoutConfirm = false),
              ),
            ),
          ],
        ],
      ),
      floatingActionButton: _currentIndex == 0 && !_drawerOpen
          ? QuickActionFab(onScheduleTap: _openScheduleFlow)
          : null,
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: AbsorbPointer(
        absorbing: _drawerOpen,
        child: _ClienteNavBar(
          currentIndex: _currentIndex,
          onTap: (i) => setState(() => _currentIndex = i),
          unreadCount: _unreadCount,
          hasPendingBudget: hasPendingBudget,
        ),
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
