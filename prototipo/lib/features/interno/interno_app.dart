import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
import '../../core/widgets/side_drawer.dart';
import 'data/internal_flow_api_repository.dart';
import 'data/internal_flow_repository.dart';
import 'data/notification_repository.dart';
import 'data/notification_api_repository.dart';
import 'data/scheduling_repository.dart';
import 'data/scheduling_api_repository.dart';
import 'data/report_repository.dart';
import 'data/report_api_repository.dart';
import 'screens/budget_list_screen.dart';
import 'screens/employee_dashboard_screen.dart';
import 'screens/service_list_screen.dart';
import 'screens/scheduled_services_screen.dart';
import 'screens/inventory_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/internal_notifications_screen.dart';
import 'screens/login_screen.dart';
import 'screens/internal_messages_screen.dart';
import 'screens/catalog_services_screen.dart';
import 'screens/users_screen.dart';
import '../../core/config/api_config.dart';
import '../shared/models/notification_item.dart';
import '../../services/firebase_messaging_service.dart';

// TODO(prod): substituir pela URL real de produção e autenticação adequada.
final _kApiBaseUrl = ApiConfig.baseUrl;
// TODO(prod): desativar seed DEV automático antes de publicar.
const _kEnableDevLowStockSeedOnStartup = true;

class InternoApp extends StatefulWidget {
  final bool isManager;
  final String userId;
  const InternoApp({super.key, required this.isManager, required this.userId});

  @override
  State<InternoApp> createState() => _InternoAppState();
}

class _InternoAppState extends State<InternoApp> {
  int _currentIndex = 0;
  final _schedulingRefresh = ValueNotifier<int>(0);
  final _servicesRefresh = ValueNotifier<int>(0);
  bool _drawerOpen = false;
  bool _showLogoutConfirm = false;
  Timer? _autoRefreshTimer;

  late final InternalFlowRepository _flowRepository;
  late final NotificationRepository _notificationRepository;
  late final SchedulingRepository _schedulingRepository;
  late final ReportRepository _reportRepository;
  List<NotificationItem> _internalNotifications = [];
  int _unreadInternalChatsCount = 0;

  // Manager nav indices for 4-tab layout:
  // 0=Dashboard 1=Agendamentos 2=Orçamentos 3=Serviços
  // Drawer: Estoque → _drawerNavTo('stock'), Relatórios → _drawerNavTo('reports')

  // For manager, we keep a secondary "virtual" screen index for drawer destinations
  String? _drawerScreen; // 'stock' | 'reports' | 'settings' | null

  @override
  void initState() {
    super.initState();
    _flowRepository = InternalFlowApiRepository(baseUrl: _kApiBaseUrl);
    _notificationRepository = NotificationApiRepository(
      baseUrl: _kApiBaseUrl,
      internalUserTypeId: widget.isManager ? 1 : 3,
    );
    _schedulingRepository = SchedulingApiRepository(baseUrl: _kApiBaseUrl);
    _reportRepository = ReportApiRepository(baseUrl: _kApiBaseUrl);
    _loadNotifications();
    _configurePushAndDevSeed();
    _startAutoRefresh();
  }

  void _startAutoRefresh() {
    _autoRefreshTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) {
        _schedulingRefresh.value++;
        _servicesRefresh.value++;
      }
    });
  }

  Future<void> _configurePushAndDevSeed() async {
    await FirebaseMessagingService.configureInternalNotifications(
      baseUrl: _kApiBaseUrl,
      internalUserTypeId: widget.isManager ? 1 : 3,
      triggerDevLowStockSeed: _kEnableDevLowStockSeedOnStartup,
    );
    await _loadNotifications();
  }

  Future<void> _loadNotifications() async {
    final items = await _notificationRepository.fetchNotifications();
    if (mounted) setState(() => _internalNotifications = List.of(items));
  }

  @override
  void dispose() {
    _autoRefreshTimer?.cancel();
    _flowRepository.dispose();
    _schedulingRefresh.dispose();
    _servicesRefresh.dispose();
    super.dispose();
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

  int get _unreadInternalNotificationsCount =>
      _internalNotifications.where((n) => n.unread).length;

  Future<void> _markNotificationAsRead(String id) async {
    await _notificationRepository.markAsRead(id);
    final items = await _notificationRepository.fetchNotifications();
    if (mounted) setState(() => _internalNotifications = List.of(items));
  }

  Future<void> _markAllNotificationsAsRead() async {
    await _notificationRepository.markAllAsRead();
    final items = await _notificationRepository.fetchNotifications();
    if (mounted) setState(() => _internalNotifications = List.of(items));
  }

  Future<void> _clearAllNotifications() async {
    await _notificationRepository.clearAll();
    if (mounted) setState(() => _internalNotifications = []);
  }

  void _updateUnreadChatsCount(int count) {
    if (!mounted || _unreadInternalChatsCount == count) return;
    setState(() => _unreadInternalChatsCount = count);
  }

  // Navigates to a drawer destination (manager only secondary screens)
  void _navigateDrawer(String screen) {
    setState(() {
      _drawerScreen = screen;
      _drawerOpen = false;
    });
  }

  Widget _buildManagerDrawerScreen() {
    switch (_drawerScreen) {
      case 'stock':
        return InventoryScreen(
          onOpenDrawer: () => setState(() => _drawerOpen = true),
        );
      case 'catalog':
        return CatalogServicesScreen(
          onOpenDrawer: () => setState(() => _drawerOpen = true),
        );
      case 'users':
        return UsersScreen(
          onOpenDrawer: () => setState(() => _drawerOpen = true),
        );
      case 'reports':
        return ReportsScreen(
          repository: _reportRepository,
          onOpenDrawer: () => setState(() => _drawerOpen = true),
        );
      case 'settings':
        return SettingsScreen(
          onOpenDrawer: () => setState(() => _drawerOpen = true),
        );
      case 'alerts':
        return InternalNotificationsScreen(
          items: _internalNotifications,
          onMarkRead: _markNotificationAsRead,
          onMarkAllRead: _markAllNotificationsAsRead,
          onClearAll: _clearAllNotifications,
          onOpenDrawer: () => setState(() => _drawerOpen = true),
        );
      default:
        return const SizedBox.shrink();
    }
  }

  List<Widget> get _managerScreens => [
        EmployeeDashboardScreen(
          repository: _flowRepository,
          schedulingRepository: _schedulingRepository,
          refreshSignal: _schedulingRefresh,
          isManager: true,
          onLogout: _requestLogout,
          onOpenDrawer: () => setState(() => _drawerOpen = true),
          onOpenServices: () => setState(() => _currentIndex = 3),
          onOpenBudgets: () => setState(() => _currentIndex = 2),
          onOpenAlerts: () => setState(() => _drawerScreen = 'alerts'),
          unreadAlertsCount: _unreadInternalNotificationsCount,
        ),
        ScheduledServicesScreen(
          repository: _schedulingRepository,
          budgetRepository: _flowRepository,
          onOpenDrawer: () => setState(() => _drawerOpen = true),
          onOpenServices: () => setState(() => _currentIndex = 3),
          onOpenBudgets: () => setState(() => _currentIndex = 2),
        ),
        BudgetListScreen(
          repository: _flowRepository,
          onOpenDrawer: () => setState(() => _drawerOpen = true),
        ),
        ServiceListScreen(
          repository: _flowRepository,
          initialFilter: null,
          refreshSignal: _servicesRefresh,
          onOpenDrawer: () => setState(() => _drawerOpen = true),
        ),
      ];

  List<Widget> get _employeeScreens => [
        EmployeeDashboardScreen(
          repository: _flowRepository,
          schedulingRepository: _schedulingRepository,
          refreshSignal: _schedulingRefresh,
          isManager: false,
          onLogout: _requestLogout,
          onOpenServices: () => setState(() => _currentIndex = 3),
          onOpenBudgets: () => setState(() => _currentIndex = 2),
        ),
        ScheduledServicesScreen(
          repository: _schedulingRepository,
          budgetRepository: _flowRepository,
          refreshSignal: _schedulingRefresh,
          servicesRefreshSignal: _servicesRefresh,
          onOpenServices: () => setState(() => _currentIndex = 3),
          onOpenBudgets: () => setState(() => _currentIndex = 2),
        ),
        BudgetListScreen(repository: _flowRepository),
        ServiceListScreen(repository: _flowRepository, initialFilter: null, refreshSignal: _servicesRefresh),
        InternalMessagesScreen(onUnreadCountChanged: _updateUnreadChatsCount),
        InternalNotificationsScreen(
          items: _internalNotifications,
          onMarkRead: _markNotificationAsRead,
          onMarkAllRead: _markAllNotificationsAsRead,
          onClearAll: _clearAllNotifications,
        ),
      ];

  List<_NavItem> get _managerNavItems => [
        _NavItem(label: 'Dashboard', icon: Icons.home_outlined),
        _NavItem(label: 'Agendamentos', icon: Icons.calendar_today_outlined),
        _NavItem(label: 'Orçamentos', icon: Icons.description_outlined),
        _NavItem(label: 'Serviços', icon: Icons.build_outlined),
      ];

  List<_NavItem> get _employeeNavItems => [
        _NavItem(label: 'Dashboard', icon: Icons.dashboard_rounded),
        _NavItem(label: 'Agendamentos', icon: Icons.event_note_rounded),
        _NavItem(label: 'Orçamentos', icon: Icons.receipt_long_rounded),
        _NavItem(label: 'Serviços', icon: Icons.build_rounded),
        _NavItem(
          label: 'Mensagens',
          icon: Icons.chat_bubble_rounded,
          badgeCount: _unreadInternalChatsCount,
        ),
        _NavItem(
          label: 'Alertas',
          icon: Icons.notifications_rounded,
          badgeCount: _unreadInternalNotificationsCount,
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final isManager = widget.isManager;
    final screens = isManager ? _managerScreens : _employeeScreens;
    final navItems = isManager ? _managerNavItems : _employeeNavItems;
    final showDrawerScreen = isManager && _drawerScreen != null;

    return Scaffold(
      backgroundColor: bgPage,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            // Main content: bottom nav tabs or drawer-destination screens
            showDrawerScreen
                ? _buildManagerDrawerScreen()
                : IndexedStack(index: _currentIndex, children: screens),

            // Side drawer overlay (manager only)
            if (isManager && _drawerOpen)
              SideDrawer(
                onClose: () => setState(() => _drawerOpen = false),
                onOpenInventory: () => _navigateDrawer('stock'),
                onOpenCatalog: () => _navigateDrawer('catalog'),
                onOpenUsers: () => _navigateDrawer('users'),
                onOpenReports: () => _navigateDrawer('reports'),
                onOpenSettings: () => _navigateDrawer('settings'),
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
                  onCancel: () =>
                      setState(() => _showLogoutConfirm = false),
                ),
              ),
            ],
          ],
        ),
      ),
      bottomNavigationBar: AbsorbPointer(
        absorbing: _drawerOpen,
        child: showDrawerScreen
            ? _InternoNavBar(
                items: navItems,
                currentIndex: -1,
                onTap: (i) => setState(() {
                  _drawerScreen = null;
                  _currentIndex = i;
                }),
              )
            : _InternoNavBar(
                items: navItems,
                currentIndex: _currentIndex,
                onTap: (i) {
                  setState(() => _currentIndex = i);
                  if (i == 1) _schedulingRefresh.value++;
                },
              ),
      ),
    );
  }
}

// ── Placeholder screen for unimplemented manager screens ─────────────────────

// ── Nav item model ─────────────────────────────────────────────────────────────

class _NavItem {
  final String label;
  final IconData icon;
  final int badgeCount;

  const _NavItem({
    required this.label,
    required this.icon,
    this.badgeCount = 0,
  });
}

// ── Bottom navigation bar ─────────────────────────────────────────────────────

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
            offset: Offset(0, -4),
          ),
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
                            SizedBox(
                              width: 28,
                              height: 22,
                              child: Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  Align(
                                    alignment: Alignment.center,
                                    child: Icon(
                                      item.icon,
                                      size: 22,
                                      color: isActive ? orange : textMuted,
                                    ),
                                  ),
                                  if (item.badgeCount > 0)
                                    Positioned(
                                      right: -4,
                                      top: -2,
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 5,
                                          vertical: 1,
                                        ),
                                        decoration: BoxDecoration(
                                          color: red,
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        constraints: const BoxConstraints(
                                          minWidth: 16,
                                          minHeight: 16,
                                        ),
                                        child: Text(
                                          item.badgeCount > 9
                                              ? '9+'
                                              : item.badgeCount.toString(),
                                          textAlign: TextAlign.center,
                                          style: GoogleFonts.dmSans(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
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
