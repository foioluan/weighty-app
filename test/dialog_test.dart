import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treino/app/design/design.dart';

void main() {
  Widget app(void Function(BuildContext) open) => MaterialApp(
    theme: darkTheme(),
    home: Builder(
      builder: (context) => Center(
        child: TextButton(
          onPressed: () => open(context),
          child: const Text('abrir'),
        ),
      ),
    ),
  );

  // O fundo desfocado tinha um ColoredBox opaco ao toque por cima da barreira,
  // e tocar fora não fechava nem o diálogo nem a folha.
  testWidgets('tocar fora fecha o diálogo', (tester) async {
    await tester.pumpWidget(
      app(
        (context) => showAppDialog<void>(
          context,
          title: 'Título',
          actions: const [AppDialogAction(label: 'Ok')],
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Título'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Título'), findsNothing);
  });

  testWidgets('tocar fora fecha a folha', (tester) async {
    await tester.pumpWidget(
      app(
        (context) => showAppSheet<void>(
          context,
          title: 'Folha',
          builder: (_) => const SizedBox(height: 120),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle();
    expect(find.text('Folha'), findsOneWidget);

    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(find.text('Folha'), findsNothing);
  });
}
