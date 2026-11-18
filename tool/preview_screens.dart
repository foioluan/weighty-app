// Renderiza as telas reais do app, com dados de exemplo, em PNG — claro e
// escuro — para conferir design olhando a tela inteira, e não só o componente.
//
//   PREVIEW_OUT=/caminho [PREVIEW_SCALE=3] flutter test tool/preview_screens.dart
//
// Fica em tool/, fora do glob de test/: gera arquivos e não testa nada.
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:treino/app/providers.dart';
import 'package:treino/app/router.dart';
import 'package:treino/app/settings.dart';
import 'package:treino/app/theme.dart';
import 'package:treino/data/db/database.dart';
import 'package:treino/data/repos/session_repository.dart';

import 'demo_data.dart';

final _out = Platform.environment['PREVIEW_OUT'] ?? '/tmp';

/// Escala do PNG. 1 basta para conferir layout; 3 é a densidade do aparelho.
final _scale = double.parse(Platform.environment['PREVIEW_SCALE'] ?? '1');

/// Um celular Android comum: 393 × 852 com barra de status e de gestos.
const _size = Size(393, 852);
const _padding = EdgeInsets.only(top: 32, bottom: 20);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await _loadFonts();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/wakelock'),
          (call) async => null,
        );
    // As versões novas do wakelock_plus falam por pigeon, não por method
    // channel; a resposta é uma lista com o retorno (nulo).
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMessageHandler(
          'dev.flutter.pigeon.wakelock_plus_platform_interface.'
          'WakelockPlusApi.toggle',
          (_) async => const StandardMessageCodec().encodeMessage([null]),
        );
  });

  for (final dark in [true, false]) {
    final suffix = dark ? 'escuro' : 'claro';

    testWidgets('telas · $suffix', (tester) async {
      final db = AppDatabase(NativeDatabase.memory());
      final ids = await seedDemo(db);
      final summaryId =
          (await (db.select(db.sessions)
                    ..where((t) => t.finishedAt.isNotNull())
                    ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
                    ..limit(1))
                  .getSingle())
              .id;

      tester.view.physicalSize = _size * 3;
      tester.view.devicePixelRatio = 3;
      tester.view.padding = FakeViewPadding(
        top: _padding.top * 3,
        bottom: _padding.bottom * 3,
      );
      addTearDown(tester.view.reset);

      final key = GlobalKey();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            settingsProvider.overrideWith(
              (ref) => SettingsNotifier(
                initial: Settings(
                  themeMode: dark ? ThemeMode.dark : ThemeMode.light,
                ),
              ),
            ),
          ],
          child: RepaintBoundary(
            key: key,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: lightTheme(),
              darkTheme: darkTheme(),
              themeMode: dark ? ThemeMode.dark : ThemeMode.light,
              scrollBehavior: const AppScrollBehavior(),
              routerConfig: router,
              builder: (_, child) =>
                  BackdropGroup(child: child ?? const SizedBox()),
              locale: const Locale('pt', 'BR'),
            ),
          ),
        ),
      );

      Future<void> settleFrames() async {
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
      }

      Future<void> dismiss() async {
        await tester.tapAt(const Offset(196, 120));
        await settleFrames();
      }

      Future<void> shot(String path, String name) async {
        router.go(path);
        for (var i = 0; i < 30; i++) {
          await tester.pump(const Duration(milliseconds: 30));
        }
        await _capture(tester, key, '${name}_$suffix');
      }

      await shot('/', '01_treinos');
      await shot('/historico', '02_historico');
      await shot('/exercicios', '03_exercicios');
      // Rolada: o título grande sai, o pequeno aparece no topo e a lista passa
      // por baixo do vidro.
      await tester.drag(
        find.byType(CustomScrollView).last,
        const Offset(0, -500),
      );
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 30));
      }
      await _capture(tester, key, '03b_exercicios_rolado_$suffix');
      await shot('/ajustes', '04_ajustes');
      await shot('/treino/${ids.upper}/editar?de=Treinos', '05_editor');
      await tester.tap(find.byIcon(LucideIcons.ellipsis).first);
      await settleFrames();
      await _capture(tester, key, '05b_menu_$suffix');
      await dismiss();
      await tester.tap(find.text('8–10').first);
      await settleFrames();
      await _capture(tester, key, '05c_folha_$suffix');
      await dismiss();
      await shot('/sessao/$summaryId?de=Histórico', '06_resumo');
      // O seed devolve o id do vínculo treino–exercício; a tela de progressão
      // quer o do exercício.
      final remada = await (db.select(
        db.exercises,
      )..where((t) => t.name.equals('Remada curvada barra'))).getSingle();
      await shot('/exercicio/${remada.id}?de=Exercícios', '07_progresso');
      // Dedo pousado no gráfico: régua, ponto realçado e balão.
      final chart = tester.getRect(find.byType(LineChart));
      final touch = await tester.startGesture(
        chart.centerLeft + Offset(chart.width * 0.45, 0),
      );
      await settleFrames();
      await _capture(tester, key, '07b_progresso_toque_$suffix');
      await touch.up();
      await settleFrames();

      // Por último: começar uma sessão deixa um treino em andamento, e isso
      // mudaria as telas anteriores.
      final live = await SessionRepository(db).startFromRoutine(ids.upper);
      await shot('/treino/$live', '08_sessao');
      await tester.tap(find.text('Finalizar'));
      await settleFrames();
      await _capture(tester, key, '08b_dialogo_$suffix');
      await tester.tap(find.text('Voltar'));
      await settleFrames();
      await tester.tap(find.text('Concluir série'));
      await settleFrames();
      await _capture(tester, key, '08c_sessao_concluida_$suffix');
      await tester.tap(find.bySemanticsLabel('Carga'));
      await settleFrames();
      await _capture(tester, key, '08d_teclado_$suffix');
      await dismiss();
      await tester.tap(find.bySemanticsLabel('Exercícios do treino'));
      await settleFrames();
      await _capture(tester, key, '08e_lista_$suffix');
      await dismiss();

      router.go('/');
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 50));
      await db.close();
    });
  }
}

Future<void> _capture(WidgetTester tester, GlobalKey key, String name) async {
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: _scale);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });
  if (bytes != null) File('$_out/$name.png').writeAsBytesSync(bytes);
}

Future<void> _loadFonts() async {
  final inter = FontLoader('Inter');
  for (final file in [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
    'Inter-Bold.ttf',
  ]) {
    final bytes = File('assets/fonts/$file').readAsBytesSync();
    inter.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await inter.load();

  // Sem isto os ícones saem como quadrados vazios. O nome leva o prefixo do
  // pacote porque o IconData do Lucide declara `fontPackage`.
  final config = File('.dart_tool/package_config.json');
  final packages =
      (jsonDecode(config.readAsStringSync())
              as Map<String, dynamic>)['packages']
          as List<dynamic>;
  final root =
      packages.cast<Map<String, dynamic>>().firstWhere(
            (p) => p['name'] == 'lucide_icons_flutter',
          )['rootUri']
          as String;
  final base = Uri.parse(root.endsWith('/') ? root : '$root/');
  final lucide = File.fromUri(base.resolve('assets/lucide.ttf'));
  await (FontLoader('packages/lucide_icons_flutter/Lucide')
        ..addFont(Future.value(ByteData.sublistView(lucide.readAsBytesSync()))))
      .load();
}
