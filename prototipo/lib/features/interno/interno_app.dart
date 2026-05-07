import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:google_fonts/google_fonts.dart';
import '../../core/theme/colors.dart';
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
import 'screens/internal_notifications_screen.dart';
import 'screens/login_screen.dart';
import 'screens/internal_messages_screen.dart';
import '../shared/models/notification_item.dart';
import '../../services/firebase_messaging_service.dart';

// TODO(prod): substituir pela URL real de produção e autenticação adequada.
final _kApiBaseUrl = kIsWeb || !Platform.isAndroid
    ? 'http://localhost:3000'
    : 'http://10.0.2.2:3000';
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
  late final InternalFlowRepository _flowRepository;
  late final NotificationRepository _notificationRepository;
  late final SchedulingRepository _schedulingRepository;
  late final ReportRepository _reportRepository;
  List<NotificationItem> _internalNotifications = [];
  int _unreadInternalChatsCount = 0;

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
    _flowRepository.dispose();
    super.dispose();
  }

  void _logout() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (_) => false,
    );
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

  void _updateUnreadChatsCount(int count) {
    if (!mounted || _unreadInternalChatsCount == count) return;
    setState(() => _unreadInternalChatsCount = count);
  }

  List<Widget> get _screens {
    if (widget.isManager) {
      return [
        EmployeeDashboardScreen(
          repository: _flowRepository,
          isManager: true,
          onLogout: _logout,
          onOpenServices: () => setState(() => _currentIndex = 3),
          onOpenBudgets: () => setState(() => _currentIndex = 2),
        ),
        ScheduledServicesScreen(
          repository: _schedulingRepository,
          budgetRepository: _flowRepository,
          onOpenServices: () => setState(() => _currentIndex = 3),
          onOpenBudgets: () => setState(() => _currentIndex = 2),
        ),
        BudgetListScreen(repository: _flowRepository),
        ServiceListScreen(repository: _flowRepository, initialFilter: null),
        const InventoryScreen(),
        ReportsScreen(repository: _reportRepository),
        InternalNotificationsScreen(
          items: _internalNotifications,
          onMarkRead: _markNotificationAsRead,
          onMarkAllRead: _markAllNotificationsAsRead,
        ),
      ];
    }
    return [
      EmployeeDashboardScreen(
        repository: _flowRepository,
        isManager: false,
        onLogout: _logout,
        onOpenServices: () => setState(() => _currentIndex = 3),
        onOpenBudgets: () => setState(() => _currentIndex = 2),
      ),
      ScheduledServicesScreen(
        repository: _schedulingRepository,
        budgetRepository: _flowRepository,
        onOpenServices: () => setState(() => _currentIndex = 3),
        onOpenBudgets: () => setState(() => _currentIndex = 2),
      ),
      BudgetListScreen(repository: _flowRepository),
      ServiceListScreen(repository: _flowRepository, initialFilter: null),
      InternalMessagesScreen(onUnreadCountChanged: _updateUnreadChatsCount),
      InternalNotificationsScreen(
        items: _internalNotifications,
        onMarkRead: _markNotificationAsRead,
        onMarkAllRead: _markAllNotificationsAsRead,
      ),
    ];
  }

  List<_NavItem> get _navItems {
    if (widget.isManager) {
      return [
        _NavItem(label: 'Dashboard', icon: Icons.dashboard_rounded),
        _NavItem(label: 'Agendamentos', icon: Icons.event_note_rounded),
        _NavItem(label: 'Orçamentos', icon: Icons.receipt_long_rounded),
        _NavItem(label: 'Serviços', icon: Icons.build_rounded),
        _NavItem(label: 'Estoque', icon: Icons.inventory_2_rounded),
        _NavItem(label: 'Relatórios', icon: Icons.bar_chart_rounded),
        _NavItem(
          label: 'Alertas',
          icon: Icons.notifications_rounded,
          badgeCount: _unreadInternalNotificationsCount,
        ),
      ];
    }
    return [
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgPage,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(index: _currentIndex, children: _screens),
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
  final int badgeCount;

  const _NavItem({
    required this.label,
    required this.icon,
    this.badgeCount = 0,
  });
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
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
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
