import 'dart:convert';
import '../core/api/api_helper.dart';
import '../core/config/api_config.dart';
import '../features/interno/data/models/workshop_info.dart';

class WorkshopService {
  static final String _baseUrl = ApiConfig.baseUrl;

  static Future<WorkshopInfo?> getWorkshop() async {
    try {
      final res = await ApiHelper.get('$_baseUrl/oficina');
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        if (data.isNotEmpty) {
          return WorkshopInfo.fromJson(data[0]);
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  static Future<bool> updateWorkshop(String id, String name, int boxes) async {
    try {
      final res = await ApiHelper.patch(
        '$_baseUrl/oficina/$id',
        {
          'nome': name,
          'quantidade_boxes': boxes,
        },
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
