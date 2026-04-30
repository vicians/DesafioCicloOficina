import '../../../data/mock_data.dart';
import 'notification_repository.dart';

/// Tenta executar cada operação no [primary] (API real).
/// Se houver qualquer erro de rede/servidor, cai silenciosamente no [fallback] (mock).
///
// TODO(prod): remover fallback antes de ir para produção — erros da API devem
//             ser propagados e tratados corretamente na UI.
class NotificationFallbackRepository implements NotificationRepository {
  final NotificationRepository primary;
  final NotificationRepository fallback;

  NotificationFallbackRepository({
    required this.primary,
    required this.fallback,
  });

  @override
  Future<List<NotificationItem>> fetchNotifications() async {
    try {
      return await primary.fetchNotifications();
    } catch (_) {
      return fallback.fetchNotifications();
    }
  }

  @override
  Future<void> markAsRead(String id) async {
    try {
      await primary.markAsRead(id);
    } catch (_) {
      await fallback.markAsRead(id);
    }
  }

  @override
  Future<void> markAllAsRead() async {
    try {
      await primary.markAllAsRead();
    } catch (_) {
      await fallback.markAllAsRead();
    }
  }
}
