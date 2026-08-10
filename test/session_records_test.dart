// `isNull` existe no drift (predicado SQL) e no matcher; aqui vale o matcher.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treino/data/db/database.dart';
import 'package:treino/data/repos/progress_repository.dart';
import 'package:treino/data/repos/routine_repository.dart';
import 'package:treino/data/repos/session_repository.dart';
import 'package:treino/domain/metrics/progress_metrics.dart';
import 'package:treino/domain/models/enums.dart';

void main() {
  late AppDatabase db;
  late RoutineRepository routines;
  late SessionRepository sessions;
  late ProgressRepository progress;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    routines = RoutineRepository(db);
    sessions = SessionRepository(db);
    progress = ProgressRepository(db);
  });

  tearDown(() => db.close());

  Future<int> exerciseId(String name) async {
    final row = await (db.select(
      db.exercises,
    )..where((t) => t.name.equals(name))).getSingle();
    return row.id;
  }

  /// Preenche as séries de uma sessão na ordem em que elas existem e fecha o
  /// treino na data pedida. [values] é uma série por lista, cada uma com seus
  /// segmentos (carga, reps).
  Future<void> logAndFinish(
    int sessionId,
    List<List<(double, int)>> values, {
    required DateTime finishedAt,
  }) async {
    final links =
        await (db.select(db.sessionExercises)
              ..where((t) => t.sessionId.equals(sessionId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();

    final sets =
        await (db.select(db.loggedSets)
              ..where((t) => t.sessionExerciseId.isIn(links.map((e) => e.id)))
              ..orderBy([
                (t) => OrderingTerm.asc(t.sessionExerciseId),
                (t) => OrderingTerm.asc(t.position),
              ]))
            .get();

    for (var i = 0; i < values.length && i < sets.length; i++) {
      final segments =
          await (db.select(db.setSegments)
                ..where((t) => t.loggedSetId.equals(sets[i].id))
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();

      for (var j = 0; j < values[i].length && j < segments.length; j++) {
        await sessions.updateSegment(
          segments[j].id,
          weightKg: values[i][j].$1,
          reps: values[i][j].$2,
        );
      }
      await sessions.setCompleted(sets[i].id, true);
    }

    await (db.update(db.sessions)..where((t) => t.id.equals(sessionId))).write(
      SessionsCompanion(finishedAt: Value(finishedAt)),
    );
  }

  group('recordsFor', () {
    test('estrear um exercício não é recorde', () async {
      final routineId = await routines.createRoutine('Upper 1');
      await routines.addExercise(
        routineId,
        await exerciseId('Supino reto barra'),
        setCount: 1,
      );

      final id = await sessions.startFromRoutine(routineId);
      await logAndFinish(id, [
        [(70.0, 8)],
      ], finishedAt: DateTime(2026, 8, 5));

      final data = await progress.shareData(id);

      expect(data!.records, isEmpty);
    });

    test('carga acima da melhor de todas as sessões é recorde', () async {
      final routineId = await routines.createRoutine('Upper 1');
      await routines.addExercise(
        routineId,
        await exerciseId('Supino reto barra'),
        setCount: 1,
      );

      for (final (day, load) in [(22, 65.0), (29, 70.0)]) {
        final id = await sessions.startFromRoutine(routineId);
        await logAndFinish(id, [
          [(load, 8)],
        ], finishedAt: DateTime(2026, 7, day));
      }

      final last = await sessions.startFromRoutine(routineId);
      await logAndFinish(last, [
        [(72.5, 6)],
      ], finishedAt: DateTime(2026, 8, 5));

      final records = (await progress.shareData(last))!.records;

      expect(records, hasLength(1));
      expect(records.first.exercise.name, 'Supino reto barra');
      expect(records.first.loadKg, 72.5);
      expect(records.first.reps, 6);
      expect(records.first.previousBestKg, 70);
      expect(records.first.deltaKg, closeTo(2.5, 0.0001));
    });

    test('bater a última vez mas não a melhor de todas não é recorde', () async {
      final routineId = await routines.createRoutine('Upper 1');
      await routines.addExercise(
        routineId,
        await exerciseId('Supino reto barra'),
        setCount: 1,
      );

      // Pico em julho, recuo em agosto, e hoje sobe — mas ainda abaixo do pico.
      for (final (date, load) in [
        (DateTime(2026, 7, 22), 80.0),
        (DateTime(2026, 7, 29), 70.0),
      ]) {
        final id = await sessions.startFromRoutine(routineId);
        await logAndFinish(id, [
          [(load, 8)],
        ], finishedAt: date);
      }

      final today = await sessions.startFromRoutine(routineId);
      await logAndFinish(today, [
        [(75.0, 8)],
      ], finishedAt: DateTime(2026, 8, 5));

      final data = (await progress.shareData(today))!;

      // Evoluiu contra a semana passada...
      expect(data.summary.exercises.first.verdict, Verdict.evoluiu);
      // ...mas 75 não bate os 80 de julho.
      expect(data.records, isEmpty);
    });

    test('repetir a carga máxima não é recorde', () async {
      final routineId = await routines.createRoutine('Upper 1');
      await routines.addExercise(
        routineId,
        await exerciseId('Supino reto barra'),
        setCount: 1,
      );

      for (final day in [22, 29]) {
        final id = await sessions.startFromRoutine(routineId);
        await logAndFinish(id, [
          [(70.0, 8)],
        ], finishedAt: DateTime(2026, 7, day));
      }

      final last = await sessions.startFromRoutine(routineId);
      await logAndFinish(last, [
        [(70.0, 12)],
      ], finishedAt: DateTime(2026, 8, 5));

      // Mais repetições na mesma carga é evolução, mas não é recorde de carga.
      final data = (await progress.shareData(last))!;
      expect(data.summary.exercises.first.verdict, Verdict.evoluiu);
      expect(data.records, isEmpty);
    });

    test('aquecimento pesado não cria nem impede recorde', () async {
      final routineId = await routines.createRoutine('Upper 1');
      final linkId = await routines.addExercise(
        routineId,
        await exerciseId('Supino reto barra'),
        setCount: 0,
      );
      await routines.addSet(linkId, type: SetType.aquecimento);
      await routines.addSet(linkId);

      // Semana passada: aquecimento absurdo de 200 kg e trabalho de 65.
      final first = await sessions.startFromRoutine(routineId);
      await logAndFinish(first, [
        [(200.0, 12)],
        [(65.0, 8)],
      ], finishedAt: DateTime(2026, 7, 29));

      final second = await sessions.startFromRoutine(routineId);
      await logAndFinish(second, [
        [(40.0, 12)],
        [(70.0, 8)],
      ], finishedAt: DateTime(2026, 8, 5));

      final records = (await progress.shareData(second))!.records;

      // Se o aquecimento contasse, a marca a bater seria 200 kg e não haveria
      // recorde nenhum.
      expect(records, hasLength(1));
      expect(records.first.previousBestKg, 65);
      expect(records.first.loadKg, 70);
    });

    test('sessão excluída deixa de valer como marca anterior', () async {
      final routineId = await routines.createRoutine('Upper 1');
      await routines.addExercise(
        routineId,
        await exerciseId('Supino reto barra'),
        setCount: 1,
      );

      final inflated = await sessions.startFromRoutine(routineId);
      await logAndFinish(inflated, [
        [(90.0, 8)],
      ], finishedAt: DateTime(2026, 7, 22));
      final baseline = await sessions.startFromRoutine(routineId);
      await logAndFinish(baseline, [
        [(70.0, 8)],
      ], finishedAt: DateTime(2026, 7, 29));
      final today = await sessions.startFromRoutine(routineId);
      await logAndFinish(today, [
        [(75.0, 8)],
      ], finishedAt: DateTime(2026, 8, 5));

      expect((await progress.shareData(today))!.records, isEmpty);

      // Aquele treino de 90 kg não deveria ter contado.
      await sessions.delete(inflated);

      final records = (await progress.shareData(today))!.records;
      expect(records, hasLength(1));
      expect(records.first.previousBestKg, 70);
    });

    test('vários recordes vêm do maior ganho para o menor', () async {
      final routineId = await routines.createRoutine('Upper 1');
      await routines.addExercise(
        routineId,
        await exerciseId('Supino reto barra'),
        setCount: 1,
      );
      await routines.addExercise(
        routineId,
        await exerciseId('Remada curvada barra'),
        setCount: 1,
      );

      final first = await sessions.startFromRoutine(routineId);
      await logAndFinish(first, [
        [(70.0, 8)],
        [(60.0, 10)],
      ], finishedAt: DateTime(2026, 7, 29));

      final second = await sessions.startFromRoutine(routineId);
      await logAndFinish(second, [
        // Supino sobe 2,5; remada sobe 10.
        [(72.5, 8)],
        [(70.0, 10)],
      ], finishedAt: DateTime(2026, 8, 5));

      final records = (await progress.shareData(second))!.records;

      expect(records.map((r) => r.exercise.name), [
        'Remada curvada barra',
        'Supino reto barra',
      ]);
      expect(records.first.deltaKg, closeTo(10, 0.0001));
    });

    test('abrir uma sessão antiga mostra os recordes daquele dia', () async {
      final routineId = await routines.createRoutine('Upper 1');
      await routines.addExercise(
        routineId,
        await exerciseId('Supino reto barra'),
        setCount: 1,
      );

      final ids = <int>[];
      for (final (day, load) in [(22, 65.0), (29, 70.0), (5, 75.0)]) {
        final id = await sessions.startFromRoutine(routineId);
        await logAndFinish(
          id,
          [
            [(load, 8)],
          ],
          finishedAt: day == 5 ? DateTime(2026, 8, 5) : DateTime(2026, 7, day),
        );
        ids.add(id);
      }

      // A do meio bateu 70 contra os 65 dela, mesmo já existindo 75 depois.
      final middle = (await progress.shareData(ids[1]))!.records;

      expect(middle, hasLength(1));
      expect(middle.first.loadKg, 70);
      expect(middle.first.previousBestKg, 65);
    });
  });

  group('derivações do resumo', () {
    test('volume por grupo soma exercícios do mesmo grupo e ordena', () async {
      final routineId = await routines.createRoutine('Upper 1');
      // Dois de peito e um de costas.
      for (final name in [
        'Supino reto barra',
        'Supino inclinado halteres',
        'Remada curvada barra',
      ]) {
        await routines.addExercise(
          routineId,
          await exerciseId(name),
          setCount: 1,
        );
      }

      final id = await sessions.startFromRoutine(routineId);
      await logAndFinish(id, [
        [(100.0, 10)], // peito: 1000
        [(30.0, 10)], //  peito:  300
        [(60.0, 10)], //  costas: 600
      ], finishedAt: DateTime(2026, 8, 5));

      final summary = (await progress.summarize(id))!;
      final slices = summary.volumeByGroup;

      expect(slices, hasLength(2));
      expect(slices[0].group, MuscleGroup.peito);
      expect(slices[0].volumeKg, 1300);
      expect(slices[1].group, MuscleGroup.costas);
      expect(slices[1].volumeKg, 600);
      expect(
        slices.fold<double>(0, (sum, s) => sum + s.volumeKg),
        summary.totalVolumeKg,
      );
    });

    test('a série mais pesada atravessa exercícios', () async {
      final routineId = await routines.createRoutine('Lower 1');
      for (final name in ['Agachamento livre', 'Cadeira extensora']) {
        await routines.addExercise(
          routineId,
          await exerciseId(name),
          setCount: 1,
        );
      }

      final id = await sessions.startFromRoutine(routineId);
      await logAndFinish(id, [
        [(120.0, 5)],
        [(60.0, 15)],
      ], finishedAt: DateTime(2026, 8, 5));

      final heaviest = (await progress.summarize(id))!.heaviestSet!;

      expect(heaviest.exercise.name, 'Agachamento livre');
      expect(heaviest.loadKg, 120);
      expect(heaviest.reps, 5);
    });

    test('na carga repetida vale a série de mais repetições', () async {
      final routineId = await routines.createRoutine('Upper 1');
      await routines.addExercise(
        routineId,
        await exerciseId('Supino reto barra'),
        setCount: 3,
      );

      final id = await sessions.startFromRoutine(routineId);
      await logAndFinish(id, [
        [(70.0, 8)],
        [(70.0, 10)],
        [(65.0, 12)],
      ], finishedAt: DateTime(2026, 8, 5));

      final heaviest = (await progress.summarize(id))!.heaviestSet!;

      expect(heaviest.loadKg, 70);
      expect(heaviest.reps, 10);
    });

    test('drop set entra no recorde pela carga de entrada', () async {
      final routineId = await routines.createRoutine('Upper 1');
      final linkId = await routines.addExercise(
        routineId,
        await exerciseId('Supino reto barra'),
        setCount: 0,
      );
      await routines.addSet(linkId, type: SetType.drop, segmentCount: 3);

      final first = await sessions.startFromRoutine(routineId);
      await logAndFinish(first, [
        [(60.0, 8), (45.0, 6), (30.0, 5)],
      ], finishedAt: DateTime(2026, 7, 29));

      final second = await sessions.startFromRoutine(routineId);
      await logAndFinish(second, [
        [(65.0, 8), (50.0, 6), (35.0, 5)],
      ], finishedAt: DateTime(2026, 8, 5));

      final records = (await progress.shareData(second))!.records;

      expect(records, hasLength(1));
      expect(records.first.previousBestKg, 60);
      expect(records.first.loadKg, 65);
      expect(records.first.reps, 8);
    });

    test('sessão sem série de trabalho não tem nada a mostrar', () async {
      final routineId = await routines.createRoutine('Upper 1');
      final linkId = await routines.addExercise(
        routineId,
        await exerciseId('Supino reto barra'),
        setCount: 0,
      );
      await routines.addSet(linkId, type: SetType.aquecimento);

      final id = await sessions.startFromRoutine(routineId);
      await logAndFinish(id, [
        [(40.0, 12)],
      ], finishedAt: DateTime(2026, 8, 5));

      final data = (await progress.shareData(id))!;

      expect(data.summary.exercises, isEmpty);
      expect(data.summary.volumeByGroup, isEmpty);
      expect(data.summary.heaviestSet, isNull);
      expect(data.records, isEmpty);
    });

    test('sessão inexistente devolve nulo', () async {
      expect(await progress.shareData(999), isNull);
    });
  });
}
