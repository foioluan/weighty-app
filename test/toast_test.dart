import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treino/app/design/design.dart';

void main() {
  /// Monta um app de verdade: o toast vive no Overlay, e é sob o MaterialApp
  /// que existe o estilo de erro responsável pelo sublinhado amarelo.
  Future<BuildContext> pumpApp(
    WidgetTester tester, {
    double toastInset = 0,
    Size size = const Size(390, 700),
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    late BuildContext captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme(),
        home: ToastInset(
          bottom: toastInset,
          child: Scaffold(
            body: Builder(
              builder: (context) {
                captured = context;
                return const SizedBox.expand();
              },
            ),
          ),
        ),
      ),
    );
    return captured;
  }

  testWidgets('o toast tem um Material acima do texto', (tester) async {
    final context = await pumpApp(tester);
    AppToast.show(context, 'Backup importado.', kind: ToastKind.success);
    await tester.pumpAndSettle();

    // Regressão do sublinhado amarelo duplo: sem um Material acima, o Text
    // herda o estilo de erro do MaterialApp, que traz `decoration: underline`
    // em amarelo. O copyWith de cor não apaga a decoração, então o defeito
    // sobrevivia até no build release.
    expect(
      find.ancestor(
        of: find.text('Backup importado.'),
        matching: find.byType(Material),
      ),
      findsWidgets,
    );

    final style = tester.widget<Text>(find.text('Backup importado.')).style!;
    expect(style.decoration ?? TextDecoration.none, TextDecoration.none);

    AppToast.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('a pílula abraça o texto em vez de esticar', (tester) async {
    final context = await pumpApp(tester);
    AppToast.show(context, 'Ok.');
    await tester.pumpAndSettle();

    final pill = tester.getSize(
      find
          .ancestor(of: find.text('Ok.'), matching: find.byType(Material))
          .first,
    );
    // A faixa disponível é 390 menos 16 de cada lado; uma mensagem de três
    // letras não pode ocupar nem metade dela.
    expect(pill.width, lessThan(180));

    AppToast.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('mensagem longa quebra em duas linhas dentro da faixa', (
    tester,
  ) async {
    final context = await pumpApp(tester);
    AppToast.show(
      context,
      'Este backup foi feito numa versão mais nova do app. '
      'Atualize o app antes de importar.',
      kind: ToastKind.error,
    );
    await tester.pumpAndSettle();

    final pill = tester.getSize(
      find
          .ancestor(
            of: find.textContaining('Este backup'),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(pill.width, lessThanOrEqualTo(390 - 2 * Space.xl));
    // Duas linhas de texto: se tivesse cortado numa só, a altura seria menor.
    expect(pill.height, greaterThan(50));

    AppToast.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('o toque dispensa antes do tempo', (tester) async {
    final context = await pumpApp(tester);
    AppToast.show(context, 'Sessão excluída.');
    await tester.pumpAndSettle();
    expect(find.text('Sessão excluída.'), findsOneWidget);

    await tester.tap(find.text('Sessão excluída.'));
    await tester.pumpAndSettle();

    expect(find.text('Sessão excluída.'), findsNothing);
  });

  testWidgets('arrastar para baixo dispensa', (tester) async {
    final context = await pumpApp(tester);
    AppToast.show(context, 'Imagem salva na galeria.');
    await tester.pumpAndSettle();

    await tester.drag(
      find.text('Imagem salva na galeria.'),
      const Offset(0, 90),
    );
    await tester.pumpAndSettle();

    expect(find.text('Imagem salva na galeria.'), findsNothing);
  });

  testWidgets('arrasto curto volta ao lugar', (tester) async {
    final context = await pumpApp(tester);
    AppToast.show(context, 'Ainda aqui.');
    await tester.pumpAndSettle();

    // Passa do limiar de arrasto do sistema (senão vira toque, que dispensa),
    // mas devagar e curto demais para contar como dispensa.
    await tester.timedDrag(
      find.text('Ainda aqui.'),
      const Offset(0, 24),
      const Duration(milliseconds: 400),
    );
    await tester.pumpAndSettle();

    expect(find.text('Ainda aqui.'), findsOneWidget);

    AppToast.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('sai animado e some sozinho depois do tempo', (tester) async {
    final context = await pumpApp(tester);
    AppToast.show(context, 'Vai sumir.');
    await tester.pumpAndSettle();

    await tester.pump(const Duration(seconds: 3));
    // Um quadro depois do tempo o toast ainda está na árvore, saindo — antes
    // ele desaparecia num quadro só, sem animação nenhuma.
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('Vai sumir.'), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Vai sumir.'), findsNothing);
  });

  testWidgets('respeita a barra de abas informada pela casca', (tester) async {
    const barHeight = 54.0;
    final context = await pumpApp(tester, toastInset: barHeight);
    AppToast.show(context, 'Acima das abas.');
    await tester.pumpAndSettle();

    final pill = tester.getRect(
      find
          .ancestor(
            of: find.text('Acima das abas.'),
            matching: find.byType(Material),
          )
          .first,
    );
    // Regressão: sem o inset o toast ficava por baixo da barra de abas.
    expect(pill.bottom, lessThanOrEqualTo(700 - barHeight));

    AppToast.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('um toast novo substitui o anterior', (tester) async {
    final context = await pumpApp(tester);
    AppToast.show(context, 'Primeiro.');
    await tester.pumpAndSettle();

    AppToast.show(context, 'Segundo.');
    await tester.pumpAndSettle();

    expect(find.text('Primeiro.'), findsNothing);
    expect(find.text('Segundo.'), findsOneWidget);

    AppToast.dismiss();
    await tester.pumpAndSettle();
  });

  testWidgets('o toast capturado sobrevive à saída de quem o pediu', (
    tester,
  ) async {
    // Reproduz o caso real: a linha de uma lista pede o aviso, some da lista
    // durante o await, e o aviso tinha que aparecer mesmo assim.
    final visible = ValueNotifier(true);
    addTearDown(visible.dispose);

    late ToastHandle handle;
    await tester.pumpWidget(
      MaterialApp(
        theme: darkTheme(),
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: visible,
            builder: (context, show, _) => show
                ? Builder(
                    builder: (rowContext) {
                      handle = AppToast.capture(rowContext);
                      return const SizedBox.expand();
                    },
                  )
                : const SizedBox.expand(),
          ),
        ),
      ),
    );

    visible.value = false;
    await tester.pumpAndSettle();

    handle.show('Sessão excluída.', kind: ToastKind.success);
    await tester.pumpAndSettle();

    expect(find.text('Sessão excluída.'), findsOneWidget);

    AppToast.dismiss();
    await tester.pumpAndSettle();
  });
}
