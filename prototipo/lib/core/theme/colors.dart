import 'package:flutter/material.dart';

// Primárias
const Color navyDark = Color(0xFF1C2F4A);
const Color navyMid = Color(0xFF2A4268);
const Color orange = Color(0xFFF97316);
const Color orangeLight = Color(0xFFFFF0E6);

// Superfícies
const Color bgPage = Color(0xFFF4F5F7);
const Color cardWhite = Color(0xFFFFFFFF);

// Texto
const Color textPrimary = Color(0xFF111827);
const Color textSecondary = Color(0xFF6B7280);
const Color textMuted = Color(0xFF9CA3AF);

// Semânticas
const Color green = Color(0xFF16A34A);
const Color greenBg = Color(0xFFDCFCE7);
const Color blue = Color(0xFF2563EB);
const Color blueBg = Color(0xFFDBEAFE);
const Color yellow = Color(0xFFD97706);
const Color yellowBg = Color(0xFFFEF3C7);
const Color red = Color(0xFFDC2626);
const Color redBg = Color(0xFFFEE2E2);
const Color purple = Color(0xFF7C3AED);
const Color purpleBg = Color(0xFFEDE9FE);

// Bordas
const Color borderColor = Color(0xFFE5E7EB);
const Color dividerColor = Color(0xFFF3F4F6);

// Sombras
const BoxShadow cardShadow = BoxShadow(
  color: Color(0x12000000),
  blurRadius: 3,
  offset: Offset(0, 1),
);
const BoxShadow cardShadowHover = BoxShadow(
  color: Color(0x1A000000),
  blurRadius: 16,
  offset: Offset(0, 4),
);
BoxShadow orangeButtonShadow = const BoxShadow(
  color: Color(0x44F97316),
  blurRadius: 14,
  offset: Offset(0, 4),
);

// Status badge mapping
class ServiceStatus {
  final String label;
  final Color textColor;
  final Color backgroundColor;
  final Color dotColor;

  const ServiceStatus({
    required this.label,
    required this.textColor,
    required this.backgroundColor,
    required this.dotColor,
  });
}

const statusMap = {
  'aguardando': ServiceStatus(
    label: 'Aguardando',
    textColor: textMuted,
    backgroundColor: Color(0xFFF3F4F6),
    dotColor: Color(0xFF9CA3AF),
  ),
  'pendente': ServiceStatus(
    label: 'Pendente',
    textColor: textMuted,
    backgroundColor: Color(0xFFF3F4F6),
    dotColor: Color(0xFF9CA3AF),
  ),
  'orcamento': ServiceStatus(
    label: 'Aprovar orçamento',
    textColor: yellow,
    backgroundColor: yellowBg,
    dotColor: yellow,
  ),
  'andamento': ServiceStatus(
    label: 'Em andamento',
    textColor: blue,
    backgroundColor: blueBg,
    dotColor: blue,
  ),
  // Alias para o status EM_EXECUCAO do backend (integração futura)
  'em_execucao': ServiceStatus(
    label: 'Em execução',
    textColor: blue,
    backgroundColor: blueBg,
    dotColor: blue,
  ),
  'revisao': ServiceStatus(
    label: 'Em revisão',
    textColor: purple,
    backgroundColor: purpleBg,
    dotColor: purple,
  ),
  'revisao_tecnica': ServiceStatus(
    label: 'Em revisão',
    textColor: purple,
    backgroundColor: purpleBg,
    dotColor: purple,
  ),
  'aguardando_retirada': ServiceStatus(
    label: 'Aguardando retirada',
    textColor: orange,
    backgroundColor: orangeLight,
    dotColor: orange,
  ),
  'concluido': ServiceStatus(
    label: 'Concluído',
    textColor: green,
    backgroundColor: greenBg,
    dotColor: green,
  ),
  'confirmado': ServiceStatus(
    label: 'Confirmado',
    textColor: green,
    backgroundColor: greenBg,
    dotColor: green,
  ),
  'cancelado': ServiceStatus(
    label: 'Cancelado',
    textColor: red,
    backgroundColor: redBg,
    dotColor: red,
  ),
};

ServiceStatus statusFor(String key) =>
    statusMap[key] ?? statusMap['aguardando']!;
