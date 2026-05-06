import 'models/report_data.dart';

abstract class ReportRepository {
  Future<ReportData> fetchInternalReport({
    String period = 'month',
    String? date,
    String? month,
    String? year,
  });
}
