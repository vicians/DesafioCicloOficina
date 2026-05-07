import 'models/scheduled_service_item.dart';

abstract class SchedulingRepository {
  Future<List<ScheduledServiceItem>> fetchScheduledServices();
  Future<String> sendScheduleToBudgets({
    required ScheduledServiceItem schedule,
  });
}
