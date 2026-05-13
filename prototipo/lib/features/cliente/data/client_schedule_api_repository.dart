import 'dart:convert';

import 'package:http/http.dart' as http;
import '../../../core/config/auth_manager.dart';

class ClientCatalogoItem {
  final String id;
  final String nome;
  final double preco;
  final int duracaoMinutos;

  const ClientCatalogoItem({
    required this.id,
    required this.nome,
    required this.preco,
    this.duracaoMinutos = 60,
  });
}

class ClientScheduleSelected {
  final String servicoId;
  final int quantidade;

  const ClientScheduleSelected({
    required this.servicoId,
    this.quantidade = 1,
  });
}

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

  Map<String, String> get _headers {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (AuthManager.token != null) {
      headers['Authorization'] = 'Bearer ${AuthManager.token}';
    }
    return headers;
  }

  Future<ClientScheduleContext> resolveContext() async {
    if (_resolvedContext != null) return _resolvedContext!;

    final usuarioResponse = await _client.get(
      Uri.parse('$baseUrl/usuarios/$clientId'),
      headers: _headers,
    );
    
    if (usuarioResponse.statusCode != 200) {
      throw Exception('Falha ao carregar dados do seu perfil.');
    }

    final usuario = jsonDecode(usuarioResponse.body) as Map<String, dynamic>;
    final clienteNome = usuario['nome'] as String?;

    if (clientId.isEmpty) {
      throw Exception('Cliente inválido para criar agendamento.');
    }

    final veiculoResponse = await _client.get(
      Uri.parse('$baseUrl/veiculos/cliente/$clientId'),
      headers: _headers,
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
      clienteNome: (clienteNome == null || clienteNome.isEmpty) ? 'Cliente' : clienteNome,
      veiculos: veiculoOptions,
    );

    return _resolvedContext!;
  }

  Future<List<ClientCatalogoItem>> fetchCatalogoServicos() async {
    final response = await _client.get(
      Uri.parse('$baseUrl/servicos'),
      headers: _headers,
    );
    if (response.statusCode != 200) {
      throw Exception('Falha ao carregar serviços disponíveis.');
    }

    final List data = jsonDecode(response.body) as List;
    return data
        .cast<Map<String, dynamic>>()
        .map((e) => ClientCatalogoItem(
              id: e['id'] as String,
              nome: e['nome'] as String,
              preco: ((e['preco'] as num?) ?? 0) / 100.0,
              duracaoMinutos: ((e['duracao_minutos'] as num?) ?? 60).toInt(),
            ))
        .toList();
  }

  Future<Set<int>> fetchUnavailableHours(DateTime date) async {
    final data = _formatDate(date);
    final uri = Uri.parse('$baseUrl/agendamentos/disponibilidade').replace(
      queryParameters: {'data': data},
    );

    final response = await _client.get(uri, headers: _headers);
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
    List<ClientScheduleSelected> servicos = const [],
    List<ClientCatalogoItem> catalogoCompleto = const [],
    bool paraAvaliacao = false,
  }) async {
    final context = await resolveContext();

    // Calcula duração real somando duracao_minutos de cada serviço selecionado.
    // Para avaliação usa mínimo de 60 min (slot padrão).
    int duracaoMinutos = 60;
    if (servicos.isNotEmpty && catalogoCompleto.isNotEmpty) {
      final catalogoMap = {for (final c in catalogoCompleto) c.id: c};
      final soma = servicos.fold<int>(
        0,
        (acc, s) => acc + (catalogoMap[s.servicoId]?.duracaoMinutos ?? 60),
      );
      if (soma > 0) duracaoMinutos = soma;
    }

    final response = await _client.post(
      Uri.parse('$baseUrl/agendamentos'),
      headers: _headers,
      body: jsonEncode({
        'cliente_id': context.clienteId,
        'veiculo_id': veiculoId,
        'data': '${date.year.toString().padLeft(4, '0')}-'
            '${date.month.toString().padLeft(2, '0')}-'
            '${date.day.toString().padLeft(2, '0')}',
        'hora': hour,
        'duracao_total_minutos': duracaoMinutos,
        'notas_cliente': (notes == null || notes.trim().isEmpty) ? null : notes.trim(),
        if (paraAvaliacao) 'para_avaliacao': true,
        if (servicos.isNotEmpty)
          'servicos': servicos
              .map((s) => {'servico_id': s.servicoId, 'quantidade': s.quantidade})
              .toList(),
      }),
    );

    if (response.statusCode == 201) return;

    String errorMessage = 'Falha ao confirmar agendamento.';
    try {
      final body = jsonDecode(response.body) as Map<String, dynamic>;
      errorMessage = (body['error'] as String?) ?? errorMessage;
    } catch (_) {}
    throw Exception(errorMessage);
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

