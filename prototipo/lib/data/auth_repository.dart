import 'dart:convert';
import 'package:http/http.dart' as http;

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

  AuthUser({
    required this.id,
    required this.nome,
    required this.email,
    required this.tipoId,
  });

  factory AuthUser.fromJson(Map<String, dynamic> json) {
    return AuthUser(
      id: json['id'],
      nome: json['nome'],
      email: json['email'],
      tipoId: json['tipo_id'],
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
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return AuthUser.fromJson(data['usuario']);
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
