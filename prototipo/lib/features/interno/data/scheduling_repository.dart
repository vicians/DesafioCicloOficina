import 'models/scheduled_service_item.dart';

abstract class SchedulingRepository {
  Future<List<ScheduledServiceItem>> fetchScheduledServices();
  Future<String> confirmScheduleToService({
    required ScheduledServiceItem schedule,
  });
  Future<String> openScheduleBudget({
    required ScheduledServiceItem schedule,
  });
}
