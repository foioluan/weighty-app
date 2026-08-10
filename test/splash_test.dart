import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treino/app/design/brand.dart';
import 'package:treino/app/splash.dart';
import 'package:treino/app/theme.dart';

void main() {
  Widget wrap({required Widget child}) => MaterialApp(
    theme: darkTheme(),
    home: SplashGate(child: child),
  );

  testWidgets('a abertura cobre a tela e centraliza a marca', (tester) async {
    await tester.pumpWidget(
      wrap(child: const Center(child: Text('conteúdo do app'))),
    );

    expect(find.text(appName), findsOneWidget);
    expect(find.text(appCredit), findsOneWidget);

    // Regressão: como filho não posicionado de um Stack, a camada recebia
    // restrição solta e saía com a largura do texto, encostada à esquerda, com
    // o app aparecendo atrás. Comparar o centro do crédito com o centro da tela
    // é o que pega isso.
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(
      tester.getCenter(find.byType(AppCredit)).dx,
      closeTo(screen.width / 2, 0.5),
    );

    // Regressão: sem um Material acima, o Flutter desenha o texto com o
    // sublinhado amarelo duplo de "faltou Material". A abertura é a única tela
    // que não passa pelo AppScaffold, então ela cai nisso sozinha — e apareceu
    // assim no aparelho, em build release.
    expect(
      find.ancestor(
        of: find.byType(AppCredit),
        matching: find.byType(Material),
      ),
      findsWidgets,
    );
  });

  testWidgets('a abertura sai da árvore depois do fade', (tester) async {
    await tester.pumpWidget(
      wrap(child: const Center(child: Text('conteúdo do app'))),
    );

    // O conteúdo do app já está montado por baixo desde o primeiro quadro: a
    // abertura é uma camada por cima, não uma espera.
    expect(find.text('conteúdo do app'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();

    expect(find.text(appCredit), findsNothing);
    expect(find.text('conteúdo do app'), findsOneWidget);
  });
}
