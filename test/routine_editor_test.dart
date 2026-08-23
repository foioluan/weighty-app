import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
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

    testWidgets('cada série vira um chip, com o tipo no rótulo', (
      tester,
    ) async {
      final exercises = await catalog();
      final (routineId, _) = await seedRoutine(exercises[0].id);

      await tester.pumpWidget(wrap(routineId));
      await settle(tester);

      // Aquecimento, uma normal de 8-12 e um drop de 3 quedas sem alvo.
      expect(find.text('aq'), findsOneWidget);
      expect(find.text('8-12'), findsOneWidget);
      expect(find.text('D 3'), findsOneWidget);
      // O chip de adicionar fecha a fileira.
      expect(find.byType(SetChip), findsNWidgets(4));

      // Nenhuma linha repetindo o nome do tipo, que era a massa visual antiga.
      expect(find.text('Normal'), findsNothing);

      await teardownTree(tester);
    });

    testWidgets('o menu de três pontos oferece substituir e remover', (
      tester,
    ) async {
      final exercises = await catalog();
      final (routineId, _) = await seedRoutine(exercises[0].id);

      await tester.pumpWidget(wrap(routineId));
      await settle(tester);

      await tester.tap(find.byIcon(LucideIcons.ellipsis));
      await tester.pumpAndSettle();

      expect(find.text('Substituir exercício'), findsOneWidget);
      expect(find.text('Duplicar última série'), findsOneWidget);
      expect(find.text('Remover do treino'), findsOneWidget);

      // A folha abraça as três linhas em vez de ocupar a tela toda. Só
      // apareceu no aparelho: o Column do InsetGroup esticava sempre que a
      // altura era limitada, e numa lista ela nunca é.
      final sheet = tester.getRect(
        find.ancestor(
          of: find.text('Substituir exercício'),
          matching: find.byType(InsetGroup),
        ),
      );
      final screen = tester.getRect(find.byType(MaterialApp));
      expect(sheet.height, lessThan(screen.height / 2));

      await teardownTree(tester);
    });

    testWidgets('substituir troca o exercício e mantém os chips', (
      tester,
    ) async {
      final exercises = await catalog();
      final (routineId, _) = await seedRoutine(exercises[0].id);

      await tester.pumpWidget(wrap(routineId));
      await settle(tester);
      expect(find.text(exercises[0].name), findsOneWidget);

      await tester.tap(find.byIcon(LucideIcons.ellipsis));
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
      expect(find.text('aq'), findsOneWidget);
      expect(find.text('8-12'), findsOneWidget);

      await teardownTree(tester);
    });

    testWidgets('remover exercício pede confirmação', (tester) async {
      final exercises = await catalog();
      final (routineId, _) = await seedRoutine(exercises[0].id);

      await tester.pumpWidget(wrap(routineId));
      await settle(tester);

      await tester.tap(find.byIcon(LucideIcons.ellipsis));
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

    testWidgets('tocar num chip abre a série, com a opção de excluir', (
      tester,
    ) async {
      final exercises = await catalog();
      final (routineId, _) = await seedRoutine(exercises[0].id);

      await tester.pumpWidget(wrap(routineId));
      await settle(tester);

      await tester.tap(find.text('8-12'));
      await tester.pumpAndSettle();

      expect(find.text('Excluir série'), findsOneWidget);
      expect(find.text('Salvar série'), findsOneWidget);

      await tester.tap(find.text('Excluir série'));
      await settle(tester);

      expect(find.text('8-12'), findsNothing);
      expect(find.text('aq'), findsOneWidget);

      await teardownTree(tester);
    });
  });
}
