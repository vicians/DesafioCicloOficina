import 'dart:convert';
import 'package:http/http.dart' as http;
import '../core/config/auth_manager.dart';

class AuthException implements Exception {
  final String message;
  AuthException(this.message);

  @override
  String toString() => message;
}

class AuthUser {
  final String id;
  final String nome;
  final String email;
  final int tipoId;
  final String token;

  AuthUser({
    required this.id,
    required this.nome,
    required this.email,
    required this.tipoId,
    required this.token,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json, String token) {
    return AuthUser(
      id: json['id'],
      nome: json['nome'],
      email: json['email'],
      tipoId: json['tipo_id'],
      token: token,
    );
  }
}

class AuthRepository {
  final String baseUrl;

  AuthRepository({required this.baseUrl});

  Future<AuthUser?> login(String email, String senha) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'senha': senha}),
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final token = data['token'];
        await AuthManager.saveToken(token);
        return AuthUser.fromJson(data['usuario'], token);
      } else {
        final data = jsonDecode(response.body);
        throw AuthException(data['error'] ?? 'Erro desconhecido ao fazer login');
      }
    } on AuthException {
      rethrow;
    } catch (e) {
      print('Erro no login: $e');
      throw AuthException('Erro de conexão com o servidor. Verifique sua internet.');
    }
  }
}

