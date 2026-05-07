import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/colors.dart';
import '../../../core/widgets/app_button.dart';
import '../data/client_schedule_api_repository.dart';

Future<void> showClientScheduleSheet(
  BuildContext context, {
  required ClientScheduleApiRepository repository,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _ClientScheduleSheet(repository: repository),
  );
}

class _ClientScheduleSheet extends StatefulWidget {
  final ClientScheduleApiRepository repository;

  const _ClientScheduleSheet({required this.repository});

  @override
  State<_ClientScheduleSheet> createState() => _ClientScheduleSheetState();
}

class _ClientScheduleSheetState extends State<_ClientScheduleSheet> {
  static const int _firstHour = 7;
  static const int _lastHour = 18;

  DateTime _selectedDate = DateTime.now();
  int? _selectedHour;
  bool _loadingContext = true;
  bool _loadingAvailability = true;
  bool _confirming = false;
  String? _error;
  String? _selectedVehicleId;
  final TextEditingController _notesController = TextEditingController();

  ClientScheduleContext? _context;
  Set<int> _unavailableHours = <int>{};
  List<ClientCatalogoItem> _catalogoServicos = [];
  final Set<String> _selectedServicos = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _loadingContext = true;
      _error = null;
    });

    try {
      final context = await widget.repository.resolveContext();
      final catalogo = await widget.repository.fetchCatalogoServicos();
      if (!mounted) return;

      setState(() {
        _context = context;
        _selectedVehicleId = context.veiculos.first.id;
        _catalogoServicos = catalogo;
        _loadingContext = false;
      });

      await _loadAvailabilityFor(_selectedDate);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingContext = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  Future<void> _loadAvailabilityFor(DateTime date) async {
    setState(() {
      _loadingAvailability = true;
      _error = null;
    });

    try {
      final unavailable = await widget.repository.fetchUnavailableHours(date);
      if (!mounted) return;

      setState(() {
        _unavailableHours = unavailable;
        _loadingAvailability = false;

        if (_selectedHour != null && _isHourDisabled(_selectedHour!)) {
          _selectedHour = null;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingAvailability = false;
        _error = e.toString().replaceFirst('Exception: ', '');
      });
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isHourDisabled(int hour) {
    if (_unavailableHours.contains(hour)) {
      return true;
    }

    if (_isToday(_selectedDate)) {
      final now = DateTime.now();
      if (hour < now.hour) {
        return true;
      }
      if (hour == now.hour && now.minute > 0) {
        return true;
      }
    }

    return false;
  }

  Future<void> _openServiceSelector() async {
    final temp = Set<String>.from(_selectedServicos);

    final result = await showModalBottomSheet<Set<String>>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Selecionar serviços',
                      style: GoogleFonts.dmSans(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 320,
                      child: ListView.builder(
                        itemCount: _catalogoServicos.length,
                        itemBuilder: (_, i) {
                          final item = _catalogoServicos[i];
                          final selected = temp.contains(item.id);
                          return CheckboxListTile(
                            value: selected,
                            activeColor: orange,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(
                              item.nome,
                              style: GoogleFonts.dmSans(
                                fontSize: 13,
                                color: textPrimary,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            subtitle: Text(
                              'R\$ ${item.preco.toStringAsFixed(2).replaceAll('.', ',')}',
                              style: GoogleFonts.dmSans(
                                fontSize: 11,
                                color: textSecondary,
                              ),
                            ),
                            onChanged: (val) {
                              setModalState(() {
                                if (val == true) {
                                  temp.add(item.id);
                                } else {
                                  temp.remove(item.id);
                                }
                              });
                            },
                          );
                        },
                      ),
                    ),
                    const SizedBox(height: 8),
                    AppButton(
                      label: 'Aplicar seleção',
                      fullWidth: true,
                      onPressed: () => Navigator.of(modalContext).pop(temp),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );

    if (!mounted || result == null) return;
    setState(() {
      _selectedServicos
        ..clear()
        ..addAll(result);
    });
  }

  Future<void> _confirmSchedule() async {
    final selectedHour = _selectedHour;
    final selectedVehicleId = _selectedVehicleId;
    if (selectedHour == null) return;
    if (selectedVehicleId == null || selectedVehicleId.isEmpty) return;

    setState(() {
      _confirming = true;
      _error = null;
    });

    try {
      await widget.repository.createSchedule(
        veiculoId: selectedVehicleId,
        date: _selectedDate,
        hour: selectedHour,
        notes: _notesController.text,
        servicos: _selectedServicos
            .map((id) => ClientScheduleSelected(servicoId: id))
            .toList(),
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Agendamento confirmado',
            style: GoogleFonts.dmSans(color: Colors.white),
          ),
          backgroundColor: green,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      final message = e.toString().replaceFirst('Exception: ', '');
      setState(() {
        _confirming = false;
        _error = message;
      });

      await _loadAvailabilityFor(_selectedDate);
    }
  }

  String _formatDate(DateTime date) {
    final d = date.day.toString().padLeft(2, '0');
    final m = date.month.toString().padLeft(2, '0');
    final y = date.year.toString();
    return '$d/$m/$y';
  }

  String _formatHour(int hour) {
    final hh = hour.toString().padLeft(2, '0');
    return '$hh:00';
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
          top: 12,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: cardWhite,
            borderRadius: BorderRadius.circular(24),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 20,
                offset: Offset(0, 10),
              ),
            ],
          ),
          child: _loadingContext
              ? const Padding(
                  padding: EdgeInsets.all(28),
                  child: Center(child: CircularProgressIndicator()),
                )
              : _buildContent(),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final context = _context;
    if (context == null) {
      return Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Não foi possível abrir o agendamento',
              style: GoogleFonts.dmSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _error ?? 'Tente novamente em instantes.',
              style: GoogleFonts.dmSans(
                fontSize: 13,
                color: textSecondary,
              ),
            ),
            const SizedBox(height: 18),
            AppButton(
              label: 'Fechar',
              fullWidth: true,
              onPressed: () => Navigator.of(this.context).pop(),
            ),
          ],
        ),
      );
    }

    final allHours = List<int>.generate(_lastHour - _firstHour + 1, (i) => i + _firstHour);
    ClientVehicleOption? selectedVehicle;
    for (final vehicle in context.veiculos) {
      if (vehicle.id == _selectedVehicleId) {
        selectedVehicle = vehicle;
        break;
      }
    }

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: orangeLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.calendar_month_rounded, color: orange),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Agendar serviço',
                    style: GoogleFonts.dmSans(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(this.context).pop(),
                  icon: const Icon(Icons.close_rounded, color: textMuted),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Escolha a data, selecione o horário disponível e confirme.',
              style: GoogleFonts.dmSans(fontSize: 13, color: textSecondary),
            ),
            const SizedBox(height: 14),
            Text(
              'Veículo',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: _selectedVehicleId,
              decoration: InputDecoration(
                filled: true,
                fillColor: bgPage,
                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: orange),
                ),
              ),
              items: context.veiculos
                  .map((v) => DropdownMenuItem<String>(
                        value: v.id,
                        child: Text(
                          v.descricao,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: textPrimary,
                          ),
                        ),
                      ))
                  .toList(),
              onChanged: (value) {
                setState(() {
                  _selectedVehicleId = value;
                });
              },
            ),
            const SizedBox(height: 14),
            Container(
              decoration: BoxDecoration(
                color: bgPage,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: borderColor),
              ),
              child: CalendarDatePicker(
                initialDate: _selectedDate,
                firstDate: DateTime.now(),
                lastDate: DateTime.now().add(const Duration(days: 90)),
                onDateChanged: (date) {
                  setState(() {
                    _selectedDate = date;
                    _selectedHour = null;
                  });
                  _loadAvailabilityFor(date);
                },
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'Horários disponíveis',
              style: GoogleFonts.dmSans(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: textPrimary,
              ),
            ),
            const SizedBox(height: 10),
            if (_loadingAvailability)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(child: CircularProgressIndicator()),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: allHours.map((hour) {
                  final disabled = _isHourDisabled(hour);
                  final selected = _selectedHour == hour;

                  return ChoiceChip(
                    label: Text(
                      _formatHour(hour),
                      style: GoogleFonts.dmSans(
                        fontWeight: FontWeight.w600,
                        color: disabled
                            ? textMuted
                            : selected
                                ? Colors.white
                                : textPrimary,
                      ),
                    ),
                    selected: selected,
                    onSelected: disabled
                        ? null
                        : (_) => setState(() => _selectedHour = hour),
                    selectedColor: orange,
                    backgroundColor: cardWhite,
                    disabledColor: bgPage,
                    shape: RoundedRectangleBorder(
                      side: BorderSide(color: disabled ? dividerColor : borderColor),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  );
                }).toList(),
              ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: bgPage,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Confirme seus dados',
                    style: GoogleFonts.dmSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _InfoRow(label: 'Cliente', value: context.clienteNome),
                  _InfoRow(
                    label: 'Veículo',
                    value: selectedVehicle?.descricao ?? 'Selecione um veículo',
                    highlight: selectedVehicle != null,
                  ),
                  _InfoRow(label: 'Data', value: _formatDate(_selectedDate)),
                  _InfoRow(
                    label: 'Horário',
                    value: _selectedHour == null ? 'Selecione um horário' : _formatHour(_selectedHour!),
                    highlight: _selectedHour != null,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              minLines: 2,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: 'Observação (opcional)',
                labelStyle: GoogleFonts.dmSans(color: textSecondary),
                hintText: 'Ex.: alinhamento + revisão geral',
                hintStyle: GoogleFonts.dmSans(color: textMuted),
                filled: true,
                fillColor: bgPage,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: borderColor),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: borderColor),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: orange),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: redBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  _error!,
                  style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: red,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
            if (_catalogoServicos.isNotEmpty) ...[
              Text(
                'Serviços desejados',
                style: GoogleFonts.dmSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Selecione os serviços que precisa (opcional)',
                style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
              ),
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: bgPage,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: borderColor),
                ),
                child: InkWell(
                  onTap: _openServiceSelector,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.playlist_add_check_rounded, color: navyMid, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _selectedServicos.isEmpty
                                ? 'Toque para escolher serviços'
                                : '${_selectedServicos.length} serviço(s) selecionado(s)',
                            style: GoogleFonts.dmSans(
                              fontSize: 13,
                              color: _selectedServicos.isEmpty ? textSecondary : textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down_rounded, color: textSecondary),
                      ],
                    ),
                  ),
                ),
              ),
              if (_selectedServicos.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _catalogoServicos
                      .where((item) => _selectedServicos.contains(item.id))
                      .map(
                        (item) => Chip(
                          backgroundColor: orangeLight,
                          label: Text(
                            item.nome,
                            style: GoogleFonts.dmSans(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: textPrimary,
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
              const SizedBox(height: 14),
            ],
            AppButton(
              label: 'Confirmar agendamento',
              fullWidth: true,
              loading: _confirming,
              onPressed: (_selectedHour == null ||
                      _selectedVehicleId == null ||
                      _loadingAvailability ||
                      _confirming)
                  ? null
                  : _confirmSchedule,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _InfoRow({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: RichText(
        text: TextSpan(
          style: GoogleFonts.dmSans(fontSize: 12, color: textSecondary),
          children: [
            TextSpan(
              text: '$label: ',
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            TextSpan(
              text: value,
              style: TextStyle(
                color: highlight ? orange : textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
