import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:treino/app/design/design.dart';

void main() {
  late Object? result;

  Future<void> open(
    WidgetTester tester,
    Future<Object?> Function(BuildContext) show,
  ) async {
    result = 'não confirmou';
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme(),
        home: Builder(
          builder: (context) => Center(
            child: TextButton(
              onPressed: () async => result = await show(context),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
  }

  Future<void> keys(WidgetTester tester, List<String> pressed) async {
    for (final key in pressed) {
      if (key == '⌫') {
        await tester.tap(find.byIcon(LucideIcons.delete));
      } else {
        await tester.tap(find.bySemanticsLabel(key == ',' ? 'Vírgula' : key));
      }
      await tester.pump();
    }
  }

  Future<void> ok(WidgetTester tester) async {
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('o primeiro toque substitui o valor que veio pronto', (
    tester,
  ) async {
    await open(
      tester,
      (c) => showNumberPad(c, title: 'Carga', initial: 75, decimal: true),
    );
    await keys(tester, ['8', '2', ',', '5']);
    await ok(tester);
    expect(result, 82.5);
  });

  testWidgets('o apagar tira um dígito por vez', (tester) async {
    await open(tester, (c) => showNumberPad(c, title: 'Carga', decimal: true));
    await keys(tester, ['1', '0', '2', '⌫']);
    await ok(tester);
    expect(result, 10);
  });

  testWidgets('usar última vez preenche o valor anterior', (tester) async {
    await open(
      tester,
      (c) => showNumberPad(c, title: 'Carga', decimal: true, lastValue: 67.5),
    );
    await tester.tap(find.textContaining('Usar última vez'));
    await tester.pump();
    await ok(tester);
    expect(result, 67.5);
  });

  testWidgets('sem decimal não há vírgula', (tester) async {
    await open(tester, (c) => showNumberPad(c, title: 'Reps', initial: 8));
    expect(find.bySemanticsLabel('Vírgula'), findsNothing);
  });

  testWidgets('fechar sem OK não devolve valor', (tester) async {
    await open(tester, (c) => showNumberPad(c, title: 'Reps', initial: 8));
    await keys(tester, ['1', '2']);
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });

  testWidgets('a faixa edita "de" e "até" separados', (tester) async {
    await open(
      tester,
      (c) => showRangePad(c, title: 'Repetições', from: 8, to: 10),
    );
    await keys(tester, ['6']);
    await tester.tap(find.text('até'));
    await tester.pump();
    await keys(tester, ['1', '2']);
    await ok(tester);
    expect(result, (6, 12));
  });
}
