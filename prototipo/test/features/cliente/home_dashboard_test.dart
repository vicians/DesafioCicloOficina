// Testes de widget para a Tela de Início - Dashboard do Cliente
//
// Cobre o card do Trello:
//   "Tela de Início - Dashboard do Cliente"
//   - Header com saudação personalizada e identificação do usuário
//   - Card de Status em Tempo Real do veículo
//   - Botão flutuante de acesso rápido (QuickActionFab)
//
// Para rodar:
//   cd prototipo
//   flutter test test/features/cliente/home_dashboard_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tiao_oficina/features/cliente/cliente_app.dart';

void main() {
  setUpAll(() {
    // Desabilita download de fontes em tempo de teste
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  // Envolve ClienteApp em MaterialApp para ter Scaffold e Navigator
  Widget buildSubject() =>
      const MaterialApp(home: ClienteApp(clientId: 'test-id'));

  // Avança frames suficientes sem esperar animações infinitas (PulsingDot)
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump(); // primeira renderização
    await tester.pump(const Duration(milliseconds: 100)); // estabiliza layout
  }

  // Avança frames o suficiente para completar uma animação curta (≤250ms)
  Future<void> pumpAnimation(WidgetTester tester) async {
    await tester.pump(const Duration(milliseconds: 300));
  }

  group('Header – saudação e identidade visual', () {
    testWidgets('exibe o nome da oficina', (tester) async {
      await pumpApp(tester);
      expect(find.text('Tião Oficina'), findsWidgets);
    });

    testWidgets('exibe saudação com o nome do cliente', (tester) async {
      await pumpApp(tester);
      expect(find.textContaining('Carlos'), findsOneWidget);
    });

    testWidgets('exibe avatar do cliente', (tester) async {
      await pumpApp(tester);
      // O AppAvatar renderiza um Container com as iniciais
      expect(find.text('CM'), findsOneWidget);
    });
  });

  group('Card de Status em Tempo Real', () {
    testWidgets('exibe label de status "EM ANDAMENTO"', (tester) async {
      await pumpApp(tester);
      expect(find.text('EM ANDAMENTO'), findsOneWidget);
    });

    testWidgets('exibe modelo e placa do veículo', (tester) async {
      await pumpApp(tester);
      expect(find.textContaining('Honda Civic'), findsOneWidget);
      expect(find.textContaining('ABC-1234'), findsOneWidget);
    });

    testWidgets('exibe percentual de progresso', (tester) async {
      await pumpApp(tester);
      expect(find.textContaining('65%'), findsOneWidget);
    });

    testWidgets('exibe previsão de conclusão', (tester) async {
      await pumpApp(tester);
      expect(find.textContaining('17h'), findsOneWidget);
    });
  });

  group('Card do mecânico', () {
    testWidgets('exibe nome do mecânico responsável', (tester) async {
      await pumpApp(tester);
      expect(find.textContaining('José Ferreira'), findsOneWidget);
    });

    testWidgets('exibe label "Mecânico responsável"', (tester) async {
      await pumpApp(tester);
      expect(find.text('Mecânico responsável'), findsOneWidget);
    });

    testWidgets('exibe badge "Online"', (tester) async {
      await pumpApp(tester);
      expect(find.text('Online'), findsOneWidget);
    });
  });

  group('Card de próxima etapa', () {
    testWidgets('exibe título "Próxima etapa"', (tester) async {
      await pumpApp(tester);
      expect(find.text('Próxima etapa'), findsOneWidget);
    });
  });

  group('Serviços anteriores', () {
    testWidgets('exibe seção "Serviços anteriores"', (tester) async {
      await pumpApp(tester);
      expect(find.text('Serviços anteriores'), findsOneWidget);
    });

    testWidgets('exibe até 2 itens do histórico', (tester) async {
      await pumpApp(tester);
      expect(find.text('Alinhamento e balanceamento'), findsOneWidget);
      expect(find.text('Troca de pneus (4 unidades)'), findsOneWidget);
      // Terceiro item não deve aparecer na home
      expect(find.text('Revisão de 40.000 km'), findsNothing);
    });
  });

  group('Botão flutuante de acesso rápido (QuickActionFab)', () {
    testWidgets('FAB aparece na aba Home (índice 0)', (tester) async {
      await pumpApp(tester);
      expect(find.byKey(const Key('fab_main')), findsOneWidget);
    });

    testWidgets('sub-ações não são visíveis inicialmente', (tester) async {
      await pumpApp(tester);
      expect(find.byKey(const Key('fab_schedule')), findsNothing);
      expect(find.byKey(const Key('fab_support')), findsNothing);
    });

    testWidgets('FAB visível ao navegar por outras abas e voltar', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('Histórico'));
      await tester.pump(const Duration(milliseconds: 500));
      await tester.tap(find.text('Início'));
      await tester.pump(const Duration(milliseconds: 500));
      // Scaffold._FloatingActionButtonTransition pode ter até 2 instâncias
      // durante a transição; o importante é que ao menos uma esteja presente.
      expect(find.byKey(const Key('fab_main')), findsAtLeastNWidgets(1));
    });

    testWidgets('toque no FAB exibe sub-ações', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('fab_main')));
      await pumpAnimation(tester);

      expect(find.byKey(const Key('fab_schedule')), findsOneWidget);
      expect(find.byKey(const Key('fab_support')), findsOneWidget);
      expect(find.text('Agendar serviço'), findsOneWidget);
      expect(find.text('Falar com suporte'), findsOneWidget);
    });

    testWidgets('segundo toque no FAB fecha as sub-ações', (tester) async {
      await pumpApp(tester);
      // Abre
      await tester.tap(find.byKey(const Key('fab_main')));
      await pumpAnimation(tester);
      expect(find.byKey(const Key('fab_schedule')), findsOneWidget);
      // Fecha
      await tester.tap(find.byKey(const Key('fab_main')));
      await pumpAnimation(tester);

      expect(find.byKey(const Key('fab_schedule')), findsNothing);
      expect(find.byKey(const Key('fab_support')), findsNothing);
    });

    testWidgets('"Agendar serviço" exibe snackbar ao ser tocado', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('fab_main')));
      await pumpAnimation(tester);
      await tester.tap(find.byKey(const Key('fab_schedule')));
      await pumpAnimation(tester);

      expect(find.textContaining('Agendamento'), findsOneWidget);
    });

    testWidgets('"Falar com suporte" exibe snackbar ao ser tocado', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.byKey(const Key('fab_main')));
      await pumpAnimation(tester);
      await tester.tap(find.byKey(const Key('fab_support')));
      await pumpAnimation(tester);

      expect(find.textContaining('Suporte'), findsOneWidget);
    });
  });
}
