import 'dart:convert';
import 'package:http/http.dart' as http;
import 'models/scheduled_service_item.dart';
import 'scheduling_repository.dart';

class SchedulingApiRepository implements SchedulingRepository {
  final String baseUrl;
  final http.Client _client;

  SchedulingApiRepository({
    required this.baseUrl,
    http.Client? client,
  }) : _client = client ?? http.Client();

  String _normalizeStatus(String rawStatus) {
    switch (rawStatus.toUpperCase()) {
      case 'PENDENTE':
        return 'PENDENTE';
      case 'CONFIRMADO':
        return 'CONFIRMADO';
      case 'CANCELADO':
        return 'CANCELADO';
      // Em cenários legados o backend pode retornar ANDAMENTO para agendamento.
      // Para a UI de agenda, tratamos como confirmado para simplificar os filtros.
      case 'ANDAMENTO':
        return 'CONFIRMADO';
      default:
        return 'PENDENTE';
    }
  }

  @override
  Future<List<ScheduledServiceItem>> fetchScheduledServices() async {
    final [agendamentosResp, veiculosResp] = await Future.wait([
      _client.get(Uri.parse('$baseUrl/agendamentos')),
      _client.get(Uri.parse('$baseUrl/veiculos')),
    ]);

    if (agendamentosResp.statusCode != 200) {
      throw Exception('Falha ao buscar agendamentos: ${agendamentosResp.statusCode}');
    }
    if (veiculosResp.statusCode != 200) {
      throw Exception('Falha ao buscar veiculos: ${veiculosResp.statusCode}');
    }

    final List<dynamic> agendamentos =
        jsonDecode(agendamentosResp.body) as List<dynamic>;
    final List<dynamic> veiculos = jsonDecode(veiculosResp.body) as List<dynamic>;

    final Map<String, Map<String, dynamic>> veiculosPorId = {
      for (final raw in veiculos)
        (raw as Map<String, dynamic>)['id'] as String: raw,
    };

    final items = agendamentos.map((raw) {
      final map = raw as Map<String, dynamic>;
      final veiculo = veiculosPorId[map['veiculo_id'] as String? ?? ''];

      final modelo = (veiculo?['modelo'] as String?)?.trim();
      final marca = (veiculo?['marca'] as String?)?.trim();
      final clienteNome =
          (veiculo?['nome_cliente'] as String?)?.trim().isNotEmpty == true
          ? (veiculo!['nome_cliente'] as String)
          : 'Cliente sem nome';

      final veiculoDescricao = [
        if (marca != null && marca.isNotEmpty) marca,
        if (modelo != null && modelo.isNotEmpty) modelo,
      ].join(' ');

      final agendadoPara = DateTime.tryParse(map['agendado_para'] as String? ?? '');

      return ScheduledServiceItem(
        id: map['id'] as String? ?? '',
        clienteNome: clienteNome,
        veiculoDescricao:
            veiculoDescricao.isNotEmpty ? veiculoDescricao : 'Veiculo nao identificado',
        placa: (veiculo?['placa'] as String?) ?? 'Sem placa',
        agendadoPara: agendadoPara ?? DateTime.now(),
        duracaoMinutos: (map['duracao_total_minutos'] as num?)?.toInt() ?? 0,
        status: _normalizeStatus(map['status'] as String? ?? 'PENDENTE'),
        notasCliente: map['notas_cliente'] as String?,
      );
    }).toList();

    items.sort((a, b) => a.agendadoPara.compareTo(b.agendadoPara));
    return items;
  }
}
