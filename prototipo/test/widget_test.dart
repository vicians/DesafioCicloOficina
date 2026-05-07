// Smoke test básico — verifica que o ClienteApp renderiza sem crash.
// Não depende de Firebase (main.dart não é importado).
//
// Para rodar: flutter test test/widget_test.dart

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:tiao_oficina/features/cliente/cliente_app.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  testWidgets('ClienteApp smoke test — renderiza sem crash', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: ClienteApp(clientId: 'test-id')));
    await tester.pump();
    expect(find.byType(ClienteApp), findsOneWidget);
  });
}
