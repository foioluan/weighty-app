import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:treino/app/design/design.dart';

/// Renderiza os componentes reais em PNG, com as fontes, cores e widgets do
/// app, para decidir design olhando em vez de imaginando.
///
///   flutter test test/mockups_test.dart --dart-define=OUT=/caminho
const out = String.fromEnvironment('OUT', defaultValue: '/tmp');

// ------------------------------------------------------------------- harness

Future<void> _loadFonts() async {
  for (final file in [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$file').readAsBytes();
    await (FontLoader(
      'Inter',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }

  // Sem isto os ícones saem como quadrados vazios e a maquete mente sobre o
  // peso visual da linha. O nome da família leva o prefixo do pacote porque o
  // IconData do Lucide declara `fontPackage`.
  final lucide = await _resolveLucide();
  if (lucide != null) {
    await (FontLoader(
      'packages/lucide_icons_flutter/Lucide',
    )..addFont(Future.value(ByteData.sublistView(lucide)))).load();
  }
}

/// Acha o `lucide.ttf` dentro do pub-cache pelo `.dart_tool/package_config.json`,
/// em vez de fixar a versão do pacote no caminho.
Future<Uint8List?> _resolveLucide() async {
  final config = File('.dart_tool/package_config.json');
  if (!config.existsSync()) return null;

  final packages =
      (jsonDecode(config.readAsStringSync())
              as Map<String, dynamic>)['packages']
          as List<dynamic>;
  final root = packages.cast<Map<String, dynamic>>().firstWhere(
    (p) => p['name'] == 'lucide_icons_flutter',
    orElse: () => const {},
  )['rootUri'];
  if (root is! String) return null;

  // A barra final importa: sem ela, `resolve` troca o último segmento do
  // caminho em vez de descer para dentro dele.
  final base = Uri.parse(root.endsWith('/') ? root : '$root/');
  final file = File.fromUri(base.resolve('assets/lucide.ttf'));
  return file.existsSync() ? file.readAsBytesSync() : null;
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 3);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  if (bytes != null) File('$out/$name.png').writeAsBytesSync(bytes);
}

/// Renderiza um pedaço de tela solto — sem MaterialApp, para os componentes.
Future<void> shoot(
  WidgetTester tester,
  String name,
  Size size,
  Widget Function(BuildContext) build, {
  required bool dark,
}) async {
  final key = GlobalKey();
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(size: size),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Theme(
          data: dark ? darkTheme() : lightTheme(),
          child: Builder(
            builder: (context) => RepaintBoundary(
              key: key,
              child: Material(
                color: context.colors.bg,
                child: SizedBox(
                  width: size.width,
                  height: size.height,
                  child: build(context),
                ),
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  await _capture(tester, key, name);
}

/// Renderiza uma tela inteira dentro de um MaterialApp de verdade.
///
/// O toast precisa disso: ele mora no Overlay, e é justamente sob MaterialApp
/// que existe o `_errorTextStyle` responsável pelo sublinhado amarelo. Uma
/// maquete montada à mão esconderia o defeito em vez de mostrá-lo.
Future<void> shootApp(
  WidgetTester tester,
  String name,
  Size size, {
  required bool dark,
  required Widget Function(GlobalKey bodyKey) home,
  required Future<void> Function(BuildContext) act,
}) async {
  final key = GlobalKey();
  final bodyKey = GlobalKey();
  tester.view.physicalSize = size * 3;
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    RepaintBoundary(
      key: key,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? darkTheme() : lightTheme(),
          home: home(bodyKey),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await act(bodyKey.currentContext!);
  await tester.pumpAndSettle();
  await _capture(tester, key, name);

  // Deixa o toast sair de cena para não sobrar timer pendente no teste.
  AppToast.dismiss();
  await tester.pumpAndSettle();
}

// ------------------------------------------------------------------- maquetes

/// Uma tela com barra de abas, para o toast ter algo por baixo a respeitar.
class DemoTabScreen extends StatelessWidget {
  const DemoTabScreen({super.key, required this.bodyKey});

  /// Vai num ponto abaixo do [ToastInset], porque é dessa posição que a tela
  /// real chama o toast — e é a busca a partir dali que precisa achar o inset.
  final GlobalKey bodyKey;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ToastInset(
      bottom: AppTabBar.reservedHeight(context),
      child: Scaffold(
        backgroundColor: c.bg,
        body: SafeArea(
          child: KeyedSubtree(
            key: bodyKey,
            child: Padding(
              padding: const EdgeInsets.all(Space.xl),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Ajustes',
                    style: AppText.largeTitle.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: Space.xl),
                  const InsetGroup(
                    children: [
                      AppRow(title: 'Exportar backup', showChevron: true),
                      AppRow(title: 'Importar backup', showChevron: true),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        bottomNavigationBar: AppTabBar(
          items: const [
            AppTabItem(
              icon: LucideIcons.dumbbell,
              activeIcon: LucideIcons.dumbbell,
              label: 'Treinos',
            ),
            AppTabItem(
              icon: LucideIcons.history,
              activeIcon: LucideIcons.history,
              label: 'Histórico',
            ),
            AppTabItem(
              icon: LucideIcons.clipboardList,
              activeIcon: LucideIcons.clipboardList,
              label: 'Exercícios',
            ),
            AppTabItem(
              icon: LucideIcons.settings2,
              activeIcon: LucideIcons.settings2,
              label: 'Ajustes',
            ),
          ],
          currentIndex: 3,
          onTap: (_) {},
        ),
      ),
    );
  }
}

void main() {
  setUpAll(_loadFonts);

  for (final dark in [true, false]) {
    final suffix = dark ? 'dark' : 'light';

    testWidgets('toast curto sobre a barra de abas · $suffix', (tester) async {
      await shootApp(
        tester,
        'toast-curto-$suffix',
        const Size(390, 500),
        dark: dark,
        home: (bodyKey) => DemoTabScreen(bodyKey: bodyKey),
        act: (context) async {
          AppToast.show(context, 'Backup importado.', kind: ToastKind.success);
        },
      );
    });

    testWidgets('toast longo de erro · $suffix', (tester) async {
      await shootApp(
        tester,
        'toast-longo-$suffix',
        const Size(390, 500),
        dark: dark,
        home: (bodyKey) => DemoTabScreen(bodyKey: bodyKey),
        act: (context) async {
          AppToast.show(
            context,
            'Este backup foi feito numa versão mais nova do app. '
            'Atualize o app antes de importar.',
            kind: ToastKind.error,
          );
        },
      );
    });

    testWidgets('toast informativo · $suffix', (tester) async {
      await shootApp(
        tester,
        'toast-info-$suffix',
        const Size(390, 500),
        dark: dark,
        home: (bodyKey) => DemoTabScreen(bodyKey: bodyKey),
        act: (context) async {
          AppToast.show(context, '"Upper 1" excluído.');
        },
      );
    });
  }
}
