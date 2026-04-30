import 'dart:convert';
import 'package:http/http.dart' as http;

// 10.0.2.2 é o alias do Android emulator para o localhost da máquina host.
// Para USB debugging com dispositivo físico, substitua pelo IP da máquina
// (ex: http://192.168.1.X:3000) ou use uma variável de ambiente.
const _backendUrl = 'http://10.0.2.2:3000';
const _aiServiceUrl = 'http://10.0.2.2:3001';
const _timeout = Duration(seconds: 8);

class InventoryService {
  /// Atualiza um produto no backend e dispara a sincronização com o Vector DB.
  /// Retorna true se o backend respondeu com sucesso.
  static Future<bool> syncProductWithRag({
    required String id,
    required String nome,
    required String categoria,
    required int quantidade,
    required double preco,
  }) async {
    try {
      final response = await http
          .patch(
            Uri.parse('$_backendUrl/produtos/$id'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'nome': nome,
              'quantidade_estoque': quantidade,
              'valor': preco,
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
    String? marca,
  }) async {
    try {
      final body = <String, Object>{
        'nome': nome,
        'quantidade_estoque': quantidade,
        'valor': preco,
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
              'valor': preco,
            }),
          )
          .timeout(_timeout);
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
