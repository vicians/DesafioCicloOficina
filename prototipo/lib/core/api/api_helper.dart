import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/auth_manager.dart';

class ApiHelper {
  static Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (AuthManager.token != null) {
      headers['Authorization'] = 'Bearer ${AuthManager.token}';
    }
    return headers;
  }

  static Future<http.Response> get(String url) async {
    return await http.get(Uri.parse(url), headers: _headers);
  }

  static Future<http.Response> post(String url, dynamic body) async {
    return await http.post(
      Uri.parse(url),
      headers: _headers,
      body: jsonEncode(body),
    );
  }

  static Future<http.Response> put(String url, [dynamic body]) async {
    return await http.put(
      Uri.parse(url),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }

  static Future<http.Response> patch(String url, [dynamic body]) async {
    return await http.patch(
      Uri.parse(url),
      headers: _headers,
      body: body != null ? jsonEncode(body) : null,
    );
  }



  static Future<http.Response> delete(String url) async {
    return await http.delete(Uri.parse(url), headers: _headers);
  }
}
