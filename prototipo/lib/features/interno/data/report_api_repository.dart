import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/api/api_helper.dart';
import 'models/report_data.dart';
import 'report_repository.dart';

class ReportApiRepository implements ReportRepository {
  final String baseUrl;

  ReportApiRepository({
    required this.baseUrl,
  });

  @override
  Future<ReportData> fetchInternalReport({
    String period = 'month',
    String? date,
    String? month,
    String? year,
  }) async {
    final query = <String, String>{'period': period};
    if (date != null && date.trim().isNotEmpty) {
      query['date'] = date.trim();
    }
    if (month != null && month.trim().isNotEmpty) {
      query['month'] = month.trim();
    }
    if (year != null && year.trim().isNotEmpty) {
      query['year'] = year.trim();
    }

    final uri = Uri.parse('$baseUrl/reports/internal').replace(
      queryParameters: query.isEmpty ? null : query,
    );

    final response = await ApiHelper.get(uri.toString());
    if (response.statusCode != 200) {
      throw Exception('Falha ao carregar relatório: ${response.statusCode}');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    return ReportData.fromJson(body);
  }
}
