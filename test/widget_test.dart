import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:treino/app/providers.dart';
import 'package:treino/app/theme.dart';
import 'package:treino/data/db/database.dart';
import 'package:treino/data/repos/routine_repository.dart';
import 'package:treino/data/repos/session_repository.dart';
import 'package:treino/features/routines/routines_page.dart';
import 'package:treino/features/session/session_page.dart';

/// A tela de sessão tem um cronômetro em Timer.periodic, então ela nunca fica
/// "assentada" e pumpAndSettle entraria em loop. Aqui o tempo avança um pouco,
/// o bastante para os providers assíncronos resolverem.
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 30));
  }
}

/// Descarta a árvore antes do fim do teste. Ao cancelar os streams do Drift, o
/// ProviderScope agenda um timer de limpeza; sem este pump extra ele ficaria
/// pendente e o framework de teste acusaria falha.
Future<void> teardownTree(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 10));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');

    // wakelock_plus fala com o SO por method channel; no teste não há SO.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/wakelock'),
          (call) async => null,
        );
  });

  setUp(() => db = AppDatabase(NativeDatabase.memory()));
  tearDown(() => db.close());

  Widget wrap(Widget child) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: darkTheme(),
        locale: const Locale('pt', 'BR'),
        home: child,
      ),
    );
  }

  testWidgets('a home convida a montar o primeiro treino quando está vazia', (
    tester,
  ) async {
    await tester.pumpWidget(wrap(const RoutinesPage()));
    await settle(tester);

    expect(find.text('Monte seu primeiro treino'), findsOneWidget);

    await teardownTree(tester);
  });

  testWidgets('a home lista o treino com contagens e botão de iniciar', (
    tester,
  ) async {
    final routines = RoutineRepository(db);
    final exercise = await (db.select(db.exercises)..limit(1)).getSingle();
    final routineId = await routines.createRoutine('Upper 1');
    await routines.addExercise(routineId, exercise.id, setCount: 3);

    await tester.pumpWidget(wrap(const RoutinesPage()));
    await settle(tester);

    expect(find.text('Upper 1'), findsOneWidget);
    expect(find.textContaining('1 exercício ·'), findsOneWidget);
    expect(find.textContaining('3 séries'), findsOneWidget);
    expect(find.text('Iniciar'), findsOneWidget);

    await teardownTree(tester);
  });

  group('tela de sessão', () {
    late int exerciseId;
    late int routineId;

    Future<int> seedFinishedSession(List<(double, int)> values) async {
      final sessions = SessionRepository(db);
      final id = await sessions.startFromRoutine(routineId);

      final links = await (db.select(
        db.sessionExercises,
      )..where((t) => t.sessionId.equals(id))).get();
      final sets =
          await (db.select(db.loggedSets)
                ..where((t) => t.sessionExerciseId.equals(links.first.id))
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();

      for (var i = 0; i < values.length && i < sets.length; i++) {
        final segment = await (db.select(
          db.setSegments,
        )..where((t) => t.loggedSetId.equals(sets[i].id))).getSingle();
        await sessions.updateSegment(
          segment.id,
          weightKg: values[i].$1,
          reps: values[i].$2,
        );
        await sessions.setCompleted(sets[i].id, true);
      }

      await sessions.finish(id);
      return id;
    }

    setUp(() async {
      final routines = RoutineRepository(db);
      final exercise = await (db.select(db.exercises)..limit(1)).getSingle();
      exerciseId = exercise.id;
      routineId = await routines.createRoutine('Upper 1');
      await routines.addExercise(routineId, exerciseId, setCount: 2);
    });

    testWidgets('mostra os valores da última vez como texto fantasma', (
      tester,
    ) async {
      await seedFinishedSession([(67.5, 9), (65, 8)]);
      final current = await SessionRepository(db).startFromRoutine(routineId);

      await tester.pumpWidget(wrap(SessionPage(sessionId: current)));
      await settle(tester);

      // A série de agora vem em destaque: a referência embaixo da carga e os
      // valores da semana passada como texto fantasma.
      expect(find.textContaining('última vez 67,5 × 9'), findsOneWidget);
      expect(find.text('67,5'), findsOneWidget);
      expect(find.text('Série 1 de 2'), findsOneWidget);

      // Tocar na pílula da próxima série mostra a referência dela.
      await tester.tap(find.bySemanticsLabel('Série 2'));
      await settle(tester);
      expect(find.textContaining('última vez 65 × 8'), findsOneWidget);

      await teardownTree(tester);
    });

    testWidgets('avisa quando é a primeira vez no exercício', (tester) async {
      final current = await SessionRepository(db).startFromRoutine(routineId);

      await tester.pumpWidget(wrap(SessionPage(sessionId: current)));
      await settle(tester);

      expect(
        find.textContaining('primeira vez neste exercício'),
        findsOneWidget,
      );

      await teardownTree(tester);
    });

    testWidgets('concluir sem digitar repete a carga da última vez', (
      tester,
    ) async {
      await seedFinishedSession([(67.5, 9), (65, 8)]);
      final current = await SessionRepository(db).startFromRoutine(routineId);

      await tester.pumpWidget(wrap(SessionPage(sessionId: current)));
      await settle(tester);

      await tester.tap(find.text('Concluir série'));
      await settle(tester);

      final links = await (db.select(
        db.sessionExercises,
      )..where((t) => t.sessionId.equals(current))).get();
      final sets =
          await (db.select(db.loggedSets)
                ..where((t) => t.sessionExerciseId.equals(links.first.id))
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();
      final segment = await (db.select(
        db.setSegments,
      )..where((t) => t.loggedSetId.equals(sets.first.id))).getSingle();

      expect(segment.weightKg, 67.5);
      expect(segment.reps, 9);
      // O resultado aparece na hora, e a próxima série assume o destaque.
      expect(find.text('Série 1 concluída · igual'), findsOneWidget);
      expect(find.bySemanticsLabel('Série 1, concluída'), findsOneWidget);
      expect(find.text('Série 2 de 2'), findsOneWidget);

      await teardownTree(tester);
    });

    testWidgets('mostra o delta em kg quando a carga sobe', (tester) async {
      await seedFinishedSession([(67.5, 9), (65, 8)]);
      final current = await SessionRepository(db).startFromRoutine(routineId);

      await tester.pumpWidget(wrap(SessionPage(sessionId: current)));
      await settle(tester);

      // O passo de carga vive no card em foco, que é a série de agora.
      await tester.tap(find.bySemanticsLabel('Aumentar 2,5 kg'));
      await settle(tester);

      await tester.tap(find.text('Concluir série'));
      await settle(tester);

      expect(find.text('Série 1 concluída · +2,5 kg'), findsOneWidget);

      await teardownTree(tester);
    });

    testWidgets('desfazer reabre uma série concluída', (tester) async {
      await seedFinishedSession([(67.5, 9), (65, 8)]);
      final current = await SessionRepository(db).startFromRoutine(routineId);

      await tester.pumpWidget(wrap(SessionPage(sessionId: current)));
      await settle(tester);

      await tester.tap(find.text('Concluir série'));
      await settle(tester);

      // Era um toque escondido na linha; agora é escolher a pílula e a ação
      // da base vira "Desfazer conclusão".
      await tester.tap(find.bySemanticsLabel('Série 1, concluída'));
      await settle(tester);
      await tester.tap(find.text('Desfazer conclusão'));
      await settle(tester);

      final links = await (db.select(
        db.sessionExercises,
      )..where((t) => t.sessionId.equals(current))).get();
      final sets = await (db.select(
        db.loggedSets,
      )..where((t) => t.sessionExerciseId.equals(links.first.id))).get();
      expect(sets.every((s) => !s.completed), isTrue);
      expect(find.text('Série 1 de 2'), findsOneWidget);

      await teardownTree(tester);
    });

    testWidgets('não conclui série sem repetições e avisa', (tester) async {
      // Sem sessão anterior não há de onde copiar valores.
      final current = await SessionRepository(db).startFromRoutine(routineId);

      await tester.pumpWidget(wrap(SessionPage(sessionId: current)));
      await settle(tester);

      await tester.tap(find.text('Concluir série'));
      await settle(tester);

      expect(find.text('Informe as repetições da série.'), findsOneWidget);

      final links = await (db.select(
        db.sessionExercises,
      )..where((t) => t.sessionId.equals(current))).get();
      final sets = await (db.select(
        db.loggedSets,
      )..where((t) => t.sessionExerciseId.equals(links.first.id))).get();
      expect(sets.every((s) => !s.completed), isTrue);

      // Passado o tempo do toast, ele sai sozinho — e o timer dele não fica
      // pendente no fim do teste. O `settle` extra é a animação de saída: o
      // toast some com um fade curto, não num quadro só.
      await tester.pump(const Duration(seconds: 4));
      await settle(tester);
      expect(find.text('Informe as repetições da série.'), findsNothing);

      await teardownTree(tester);
    });
  });
}
