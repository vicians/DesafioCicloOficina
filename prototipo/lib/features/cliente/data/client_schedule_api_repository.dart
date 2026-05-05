import 'dart:convert';

import 'package:http/http.dart' as http;

class ClientVehicleOption {
  final String id;
  final String descricao;

  const ClientVehicleOption({
    required this.id,
    required this.descricao,
  });
}

class ClientScheduleContext {
  final String clienteId;
  final String clienteNome;
  final List<ClientVehicleOption> veiculos;

  const ClientScheduleContext({
    required this.clienteId,
    required this.clienteNome,
    required this.veiculos,
  });
}

class ClientScheduleApiRepository {
  final String baseUrl;
  final String clientId;
  final int userTypeId;
  final http.Client _client;
  ClientScheduleContext? _resolvedContext;

  ClientScheduleApiRepository({
    required this.baseUrl,
    required this.clientId,
    this.userTypeId = 2,
    http.Client? client,
  }) : _client = client ?? http.Client();

  Future<ClientScheduleContext> resolveContext() async {
    if (_resolvedContext != null) {
      return _resolvedContext!;
    }

    final usuarioResponse = await _client.get(Uri.parse('$baseUrl/usuarios/$clientId'));

    if (usuarioResponse.statusCode != 200) {
      throw Exception('Falha ao carregar dados do seu perfil.');
    }

    final usuario = jsonDecode(usuarioResponse.body) as Map<String, dynamic>;
    final clienteNome = usuario['nome'] as String?;

    if (clientId == null || clientId.isEmpty) {
      throw Exception('Cliente inválido para criar agendamento.');
    }

    final veiculoResponse = await _client.get(
      Uri.parse('$baseUrl/veiculos/cliente/$clientId'),
    );

    if (veiculoResponse.statusCode != 200) {
      throw Exception('Falha ao carregar veículo do cliente.');
    }

    final veiculos = jsonDecode(veiculoResponse.body) as List<dynamic>;
    if (veiculos.isEmpty) {
      throw Exception('Cadastre um veículo antes de agendar.');
    }

    final veiculoOptions = veiculos
        .map((item) {
          final veiculo = item as Map<String, dynamic>;
          final veiculoId = veiculo['id'] as String?;
          if (veiculoId == null || veiculoId.isEmpty) return null;

          final placa = (veiculo['placa'] as String?) ?? 'Sem placa';
          final marca = (veiculo['marca'] as String?) ?? '';
          final modelo = (veiculo['modelo'] as String?) ?? '';
          final descricao = [marca, modelo]
              .where((part) => part.trim().isNotEmpty)
              .join(' ')
              .trim();

          return ClientVehicleOption(
            id: veiculoId,
            descricao: descricao.isEmpty ? placa : '$descricao - $placa',
          );
        })
        .whereType<ClientVehicleOption>()
        .toList();

    if (veiculoOptions.isEmpty) {
      throw Exception('Veículo inválido para agendamento.');
    }

    _resolvedContext = ClientScheduleContext(
      clienteId: clientId,
      clienteNome: (clienteNome == null || clienteNome.isEmpty)
          ? 'Cliente'
          : clienteNome,
      veiculos: veiculoOptions,
    );

    return _resolvedContext!;
  }

  Future<Set<int>> fetchUnavailableHours(DateTime date) async {
    final data = _formatDate(date);
    final uri = Uri.parse('$baseUrl/agendamentos/disponibilidade').replace(
      queryParameters: {'data': data},
    );

    final response = await _client.get(uri);
    if (response.statusCode != 200) {
      throw Exception('Falha ao consultar horários disponíveis.');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final horas = (body['horas_indisponiveis'] as List<dynamic>? ?? <dynamic>[])
        .map((item) => item as int)
        .toSet();

    return horas;
  }

  Future<void> createSchedule({
    required String veiculoId,
    required DateTime date,
    required int hour,
    String? notes,
  }) async {
    final context = await resolveContext();
    final agendadoPara = DateTime(date.year, date.month, date.day, hour);

    final response = await _client.post(
      Uri.parse('$baseUrl/agendamentos'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'cliente_id': context.clienteId,
        'veiculo_id': veiculoId,
        'agendado_para': agendadoPara.toIso8601String(),
        'duracao_total_minutos': 60,
        'notas_cliente': (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
      }),
    );

    if (response.statusCode == 201) {
      return;
    }

    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      final message = body['error'] as String?;
      throw Exception(message ?? 'Falha ao confirmar agendamento.');
    } catch (_) {
      throw Exception('Falha ao confirmar agendamento.');
    }
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}
