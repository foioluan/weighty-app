import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treino/app/design/design.dart';
import 'package:treino/app/providers.dart';
import 'package:treino/data/db/database.dart';
import 'package:treino/data/repos/routine_repository.dart';
import 'package:treino/data/repos/session_repository.dart';
import 'package:treino/domain/models/enums.dart';
import 'package:treino/features/routines/routine_editor_page.dart';

void main() {
  late AppDatabase db;
  late RoutineRepository routines;
  late SessionRepository sessions;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    routines = RoutineRepository(db);
    sessions = SessionRepository(db);
  });

  tearDown(() => db.close());

  Future<List<Exercise>> catalog() => (db.select(db.exercises)..limit(3)).get();

  /// Um treino com um exercício e três séries de tipos diferentes, para provar
  /// que a substituição não achata a configuração de nenhuma delas.
  Future<(int routineId, int linkId)> seedRoutine(int exerciseId) async {
    final routineId = await routines.createRoutine('Upper 1');
    final linkId = await routines.addExercise(
      routineId,
      exerciseId,
      setCount: 0,
    );
    await routines.addSet(linkId, type: SetType.aquecimento, targetReps: 12);
    await routines.addSet(linkId, targetReps: 8, targetRepsMax: 12);
    await routines.addSet(linkId, type: SetType.drop, segmentCount: 3);
    return (routineId, linkId);
  }

  group('replaceExercise', () {
    test('troca o exercício e preserva as séries planejadas', () async {
      final exercises = await catalog();
      final (routineId, linkId) = await seedRoutine(exercises[0].id);

      final before = await routines.detail(routineId);
      final setsBefore = before!.exercises.single.sets;

      await routines.replaceExercise(linkId, exercises[1].id);

      final after = await routines.detail(routineId);
      final detail = after!.exercises.single;

      expect(detail.exercise.id, exercises[1].id);
      // O vínculo é o mesmo: nada foi recriado por baixo.
      expect(detail.link.id, linkId);
      expect(detail.link.position, before.exercises.single.link.position);

      expect(detail.sets.length, 3);
      for (var i = 0; i < setsBefore.length; i++) {
        expect(detail.sets[i].id, setsBefore[i].id);
        expect(detail.sets[i].position, setsBefore[i].position);
        expect(detail.sets[i].setType, setsBefore[i].setType);
        expect(detail.sets[i].targetReps, setsBefore[i].targetReps);
        expect(detail.sets[i].targetRepsMax, setsBefore[i].targetRepsMax);
        expect(detail.sets[i].segmentCount, setsBefore[i].segmentCount);
      }
    });

    test('não mexe no histórico já registrado', () async {
      final exercises = await catalog();
      final (routineId, linkId) = await seedRoutine(exercises[0].id);

      final sessionId = await sessions.startFromRoutine(routineId);
      await sessions.finish(sessionId);

      await routines.replaceExercise(linkId, exercises[1].id);

      // A sessão guardou a própria cópia do exerciseId ao começar, então ela
      // continua apontando para o exercício antigo.
      final logged = await (db.select(
        db.sessionExercises,
      )..where((t) => t.sessionId.equals(sessionId))).get();
      expect(logged.single.exerciseId, exercises[0].id);
    });

    test('trocar pelo mesmo exercício não muda nada', () async {
      final exercises = await catalog();
      final (routineId, linkId) = await seedRoutine(exercises[0].id);

      await routines.replaceExercise(linkId, exercises[0].id);

      final detail = await routines.detail(routineId);
      expect(detail!.exercises.single.exercise.id, exercises[0].id);
      expect(detail.exercises.single.sets.length, 3);
    });

    test('mantém os outros exercícios do treino intactos', () async {
      final exercises = await catalog();
      final (routineId, linkId) = await seedRoutine(exercises[0].id);
      await routines.addExercise(routineId, exercises[2].id);

      await routines.replaceExercise(linkId, exercises[1].id);

      final detail = await routines.detail(routineId);
      expect(detail!.exercises.map((e) => e.exercise.id), [
        exercises[1].id,
        exercises[2].id,
      ]);
    });
  });

  group('posições das séries', () {
    Future<List<PlannedSet>> setsOf(int linkId) =>
        (db.select(db.plannedSets)
              ..where((t) => t.routineExerciseId.equals(linkId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();

    test('apagar a série do meio renumera as que ficam', () async {
      final exercises = await catalog();
      final (_, linkId) = await seedRoutine(exercises[0].id);
      final before = await setsOf(linkId);

      await routines.removeSet(before[1].id);

      final after = await setsOf(linkId);
      expect(after.map((s) => s.position), [0, 1]);
      // A ordem é a mesma: só os números fecharam o buraco.
      expect(after.map((s) => s.id), [before[0].id, before[2].id]);
    });

    test('a série nova depois de apagar não repete posição', () async {
      final exercises = await catalog();
      final (_, linkId) = await seedRoutine(exercises[0].id);
      final before = await setsOf(linkId);

      await routines.removeSet(before[1].id);
      final added = await routines.addSet(linkId, targetReps: 10);

      final after = await setsOf(linkId);
      expect(after.map((s) => s.position), [0, 1, 2]);
      expect(after.last.id, added);
    });

    test('acrescentar conserta posições que já estavam repetidas', () async {
      final exercises = await catalog();
      final (_, linkId) = await seedRoutine(exercises[0].id);
      final before = await setsOf(linkId);

      // O estado que a versão anterior deixava: buraco e posição repetida.
      await (db.update(db.plannedSets)..where((t) => t.id.equals(before[1].id)))
          .write(const PlannedSetsCompanion(position: Value(2)));

      final added = await routines.addSet(linkId);

      final after = await setsOf(linkId);
      expect(after.map((s) => s.position), [0, 1, 2, 3]);
      expect(after.map((s) => s.id), [
        before[0].id,
        before[1].id,
        before[2].id,
        added,
      ]);
    });
  });

  group('tela do editor', () {
    Widget wrap(int routineId) => ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: darkTheme(),
        home: RoutineEditorPage(routineId: routineId),
      ),
    );

    /// A tela tem animação de entrada escalonada, então precisa de alguns
    /// quadros antes de assentar.
    Future<void> settle(WidgetTester tester) async {
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 60));
      }
    }

    Future<void> teardownTree(WidgetTester tester) async {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 10));
    }

    testWidgets('o exercício mostra o resumo e abre com as séries', (
      tester,
    ) async {
      final exercises = await catalog();
      final (routineId, _) = await seedRoutine(exercises[0].id);

      await tester.pumpWidget(wrap(routineId));
      await settle(tester);

      // Uma linha que resume, no lugar da fileira de chips repetidos.
      expect(find.text('aquecimento + 1 × 8–12 + drop'), findsOneWidget);
      expect(find.text('1 exercício · 3 séries'), findsOneWidget);

      // O primeiro exercício já vem aberto, com uma linha por série.
      expect(find.text('Aquecimento'), findsOneWidget);
      expect(find.text('Série 1'), findsOneWidget);
      expect(find.text('Drop set'), findsOneWidget);
      expect(find.text('3 quedas'), findsOneWidget);
      expect(find.text('8–12'), findsOneWidget);

      // Tocar no cabeçalho recolhe.
      await tester.tap(find.text(exercises[0].name));
      await settle(tester);
      expect(find.text('Série 1'), findsNothing);

      await teardownTree(tester);
    });

    testWidgets('o + anda a faixa de repetições inteira', (tester) async {
      final exercises = await catalog();
      final (routineId, _) = await seedRoutine(exercises[0].id);

      await tester.pumpWidget(wrap(routineId));
      await settle(tester);

      await tester.tap(find.bySemanticsLabel('Mais · Repetições da série 1'));
      await settle(tester);

      expect(find.text('9–13'), findsOneWidget);
      final detail = await routines.detail(routineId);
      final set = detail!.exercises.single.sets[1];
      expect((set.targetReps, set.targetRepsMax), (9, 13));

      await teardownTree(tester);
    });

    testWidgets('o selo troca o tipo da série', (tester) async {
      final exercises = await catalog();
      final (routineId, _) = await seedRoutine(exercises[0].id);

      await tester.pumpWidget(wrap(routineId));
      await settle(tester);

      await tester.tap(find.bySemanticsLabel('Tipo: Normal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cluster set'));
      await tester.pumpAndSettle();

      final detail = await routines.detail(routineId);
      final set = detail!.exercises.single.sets[1];
      expect(set.setType, SetType.cluster);
      // Virar cluster começa com três blocos e mantém o alvo.
      expect(set.segmentCount, 3);
      expect((set.targetReps, set.targetRepsMax), (8, 12));

      await teardownTree(tester);
    });

    testWidgets('deslizar uma série apaga', (tester) async {
      final exercises = await catalog();
      final (routineId, _) = await seedRoutine(exercises[0].id);

      await tester.pumpWidget(wrap(routineId));
      await settle(tester);

      await tester.drag(find.text('Série 1'), const Offset(-500, 0));
      await tester.pumpAndSettle();

      expect(find.text('Série 1'), findsNothing);
      final detail = await routines.detail(routineId);
      expect(detail!.exercises.single.sets.map((s) => s.setType), [
        SetType.aquecimento,
        SetType.drop,
      ]);

      await teardownTree(tester);
    });

    testWidgets('iniciar treino fica na base e só sem exercício desliga', (
      tester,
    ) async {
      final empty = await routines.createRoutine('Vazio');

      await tester.pumpWidget(wrap(empty));
      await settle(tester);

      final button = tester.widget<AppButton>(
        find.widgetWithText(AppButton, 'Iniciar treino'),
      );
      expect(button.onPressed, isNull);

      await teardownTree(tester);
    });

    testWidgets('o menu de três pontos oferece substituir e remover', (
      tester,
    ) async {
      final exercises = await catalog();
      final (routineId, _) = await seedRoutine(exercises[0].id);

      await tester.pumpWidget(wrap(routineId));
      await settle(tester);

      await tester.tap(find.bySemanticsLabel(RegExp('^Opções de ')));
      await tester.pumpAndSettle();

      expect(find.text('Substituir exercício'), findsOneWidget);
      expect(find.text('Duplicar última série'), findsOneWidget);
      expect(find.text('Remover do treino'), findsOneWidget);

      // O menu abraça as três linhas e nasce junto do botão que o abriu — e
      // não lá embaixo, como a folha que ele substituiu.
      final menu = tester.getRect(
        find
            .ancestor(
              of: find.text('Substituir exercício'),
              matching: find.byType(GlassSurface),
            )
            .first,
      );
      final button = tester.getRect(
        find.bySemanticsLabel(RegExp('^Opções de ')),
      );
      final screen = tester.getRect(find.byType(MaterialApp));
      expect(menu.height, lessThan(screen.height / 3));
      expect((menu.top - button.bottom).abs(), lessThan(24));
      expect(menu.right, closeTo(button.right, 24));

      await teardownTree(tester);
    });

    testWidgets('substituir troca o exercício e mantém as séries', (
      tester,
    ) async {
      final exercises = await catalog();
      final (routineId, _) = await seedRoutine(exercises[0].id);

      await tester.pumpWidget(wrap(routineId));
      await settle(tester);
      expect(find.text(exercises[0].name), findsOneWidget);

      await tester.tap(find.bySemanticsLabel(RegExp('^Opções de ')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Substituir exercício'));
      await tester.pumpAndSettle();

      // O catálogo abriu em modo de escolha, com o título da substituição.
      expect(find.text('Substituir exercício'), findsOneWidget);

      // Busca em vez de rolar: o catálogo tem 72 exercícios e o alvo estaria
      // fora da tela.
      await tester.enterText(find.byType(TextField).first, exercises[1].name);
      await settle(tester);
      // A linha, e não `find.text(...).first`: o campo de busca agora contém o
      // mesmo texto, e `find.text` também casa com EditableText.
      await tester.tap(find.widgetWithText(AppRow, exercises[1].name));
      await tester.pumpAndSettle();

      expect(find.text(exercises[1].name), findsOneWidget);
      expect(find.text(exercises[0].name), findsNothing);
      // As séries continuam lá: é a diferença entre substituir e recomeçar.
      expect(find.text('aquecimento + 1 × 8–12 + drop'), findsOneWidget);

      await teardownTree(tester);
    });

    testWidgets('remover exercício pede confirmação', (tester) async {
      final exercises = await catalog();
      final (routineId, _) = await seedRoutine(exercises[0].id);

      await tester.pumpWidget(wrap(routineId));
      await settle(tester);

      await tester.tap(find.bySemanticsLabel(RegExp('^Opções de ')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Remover do treino'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Remover "'), findsOneWidget);

      // Cancelar não remove nada — antes a remoção era imediata e calada.
      await tester.tap(find.text('Cancelar'));
      await settle(tester);
      expect(find.text(exercises[0].name), findsOneWidget);

      await teardownTree(tester);
    });
  });
}
