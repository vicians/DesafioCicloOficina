import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/api_config.dart';
import '../features/interno/data/models/user_item.dart';

class UserService {
  static final String _baseUrl = ApiConfig.baseUrl;
  static const Duration _timeout = Duration(seconds: 8);

  static Future<List<UserItem>> getUsers() async {
    try {
      final res = await http.get(Uri.parse('$_baseUrl/usuarios')).timeout(_timeout);
      if (res.statusCode == 200) {
        final List<dynamic> data = jsonDecode(res.body);
        return data.map((json) => UserItem.fromJson(json)).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }

  static Future<bool> createUser({
    required int tipoId,
    required String cpfCnpj,
    required String nome,
    required String telefone,
    required String email,
    required String senha,
  }) async {
    try {
      final res = await http.post(
        Uri.parse('$_baseUrl/usuarios'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tipo_id': tipoId,
          'cpf_cnpj': cpfCnpj,
          'nome': nome,
          'telefone': telefone,
          'email': email,
          'senha': senha,
        }),
      ).timeout(_timeout);
      return res.statusCode == 201;
    } catch (_) {
      return false;
    }
  }

  static Future<bool> updateUser({
    required String id,
    required int tipoId,
    required String nome,
    required String telefone,
    required String email,
  }) async {
    try {
      final res = await http.put(
        Uri.parse('$_baseUrl/usuarios/$id'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'tipo_id': tipoId,
          'nome': nome,
          'telefone': telefone,
          'email': email,
        }),
      ).timeout(_timeout);
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
