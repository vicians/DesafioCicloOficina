import 'dart:convert';
import '../core/api/api_helper.dart';
import '../core/config/api_config.dart';
import '../core/api/api_helper.dart';
import '../features/interno/data/models/user_item.dart';

class UserService {
  static final String _baseUrl = ApiConfig.baseUrl;

  static Future<List<UserItem>> getUsers() async {
    try {
      final res = await ApiHelper.get('$_baseUrl/usuarios');
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
      final res = await ApiHelper.post(
        '$_baseUrl/usuarios',
        {
          'tipo_id': tipoId,
          'cpf_cnpj': cpfCnpj,
          'nome': nome,
          'telefone': telefone,
          'email': email,
          'senha': senha,
        },
      );
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
      final res = await ApiHelper.put(
        '$_baseUrl/usuarios/$id',
        {
          'tipo_id': tipoId,
          'nome': nome,
          'telefone': telefone,
          'email': email,
        },
      );
      return res.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
