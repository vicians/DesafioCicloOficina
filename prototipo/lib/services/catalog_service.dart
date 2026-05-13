import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';
import '../features/interno/data/models/catalogo_servico_item.dart';

class CatalogService {
  static final String _baseUrl = ApiConfig.baseUrl;
  static const Duration _timeout = Duration(seconds: 8);

  static Future<List<CatalogoServicoItem>> getServices() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/servicos')).timeout(_timeout);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((json) => CatalogoServicoItem.fromJson(json)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> createService({
    required String nome,
    required double preco,
    String? descricao,
    int? duracaoMinutos,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/servicos'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': nome,
          'preco': (preco * 100).toInt(),
          'descricao': descricao,
          'duracao_minutos': duracaoMinutos ?? 60,
        }),
      ).timeout(_timeout);
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateService({
    required String id,
    required String nome,
    required double preco,
    String? descricao,
    int? duracaoMinutos,
  }) async {
    try {
      final res = await http.patch(
        Uri.parse('$_baseUrl/servicos/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nome': nome,
          'preco': (preco * 100).toInt(),
          'descricao': descricao,
          'duracao_minutos': duracaoMinutos ?? 60,
        }),
      ).timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> deleteService(String id) async {
    try {
      final res = await http.delete(Uri.parse('$_baseUrl/servicos/$id')).timeout(_timeout);
      return res.statusCode == 204 || res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
