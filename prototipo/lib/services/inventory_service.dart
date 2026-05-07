import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';
import '../data/mock_data.dart';

// 10.0.2.2 é o alias do Android emulator para o localhost da máquina host.
// Para USB debugging com dispositivo físico, substitua pelo IP da máquina
// (ex: http://192.168.1.X:3000) ou use uma variável de ambiente.
final _backendUrl = ApiConfig.baseUrl;
final _aiServiceUrl = ApiConfig.aiServiceUrl;
const _timeout = Duration(seconds: 8);

class InventoryService {
  /// Busca todos os produtos do backend
  static Future<List<PartItem>> getProducts() async {
    try {
      final res = await http.get(Uri.parse('$_backendUrl/produtos')).timeout(_timeout);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((json) {
          final int qty = json['quantidade_estoque'] ?? 0;
          final int minEstoque = json['min_estoque'] ?? 10;
          return PartItem(
            id: json['id'],
            name: json['nome'] ?? '',
            category: json['categoria'] ?? 'Geral',
            qty: qty,
            min: minEstoque,
            unit: json['unidade'] ?? 'unid.',
            price: (json['valor'] ?? 0) / 100,
            status: qty < minEstoque ? 'low' : 'ok',
          );
        }).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  /// Deleta um produto do backend
  static Future<bool> deleteProduct(String id) async {
    try {
      final res = await http.delete(Uri.parse('$_backendUrl/produtos/$id')).timeout(_timeout);
      return res.statusCode == 204;
    } catch (_) {
      return false;
    }
  }

  /// Atualiza um produto no backend e dispara a sincronização com o Vector DB.
  /// Retorna true se o backend respondeu com sucesso.
  static Future<bool> syncProductWithRag({
    required String id,
    required String nome,
    required String categoria,
    required int quantidade,
    required double preco,
    int? min,
    String? unit,
  }) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$_backendUrl/produtos/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'nome': nome,
              'categoria': categoria,
              'quantidade_estoque': quantidade,
              'min_estoque': min,
              'unidade': unit,
              'valor': (preco * 100).toInt(),
            }),
          )
          .timeout(_timeout);
      // O backend chama o ai_service internamente após salvar.
      // Se o backend estiver offline, tenta sincronizar direto com o ai_service.
      if (response.statusCode == 200) return true;
      return await _syncDirectWithAi(
        id: id,
        nome: nome,
        quantidade: quantidade,
        preco: preco,
      );
    } catch (_) {
      return _syncDirectWithAi(
        id: id,
        nome: nome,
        quantidade: quantidade,
        preco: preco,
      );
    }
  }

  /// Cria um produto novo no backend.
  /// Retorna true se criado com sucesso.
  static Future<bool> createProduct({
    required String nome,
    required int quantidade,
    required double preco,
    required String categoria,
    int? min,
    String? unit,
    String? marca,
  }) async {
    try {
      final body = <String, Object>{
        'nome': nome,
        'categoria': categoria,
        'quantidade_estoque': quantidade,
        'min_estoque': min ?? 10,
        'unidade': unit ?? 'unid.',
        'valor': (preco * 100).toInt(),
      };
      if (marca != null) body['marca'] = marca;

      final response = await http
          .post(
            Uri.parse('$_backendUrl/produtos'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(_timeout);
      return response.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  /// Fallback: sincroniza diretamente com o ai_service quando o backend
  /// está indisponível (útil em desenvolvimento local).
  static Future<bool> _syncDirectWithAi({
    required String id,
    required String nome,
    required int quantidade,
    required double preco,
  }) async {
    try {
      final response = await http
          .post(
            Uri.parse('$_aiServiceUrl/ai/produtos/sync'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'id': id,
              'nome': nome,
              'quantidade_estoque': quantidade,
              'valor': (preco * 100).toInt(),
            }),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
