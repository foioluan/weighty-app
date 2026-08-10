import 'package:drift/drift.dart';
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

  /// Preenche as séries de um exercício da sessão e fecha o treino.
  /// [values] é uma série por lista, cada uma com seus segmentos (carga, reps).
  Future<void> logAndFinish(
    int sessionId,
    List<List<(double, int)>> values, {
    bool finish = true,
    DateTime? finishedAt,
  }) async {
    final sessionExercises =
        await (db.select(db.sessionExercises)
              ..where((t) => t.sessionId.equals(sessionId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();

    final loggedSets =
        await (db.select(db.loggedSets)
              ..where(
                (t) =>
                    t.sessionExerciseId.isIn(sessionExercises.map((e) => e.id)),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();

    for (var i = 0; i < values.length && i < loggedSets.length; i++) {
      final segments =
          await (db.select(db.setSegments)
                ..where((t) => t.loggedSetId.equals(loggedSets[i].id))
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();

      for (var j = 0; j < values[i].length; j++) {
        final (weight, reps) = values[i][j];
        if (j < segments.length) {
          await sessions.updateSegment(
            segments[j].id,
            weightKg: weight,
            reps: reps,
          );
        }
      }
      await sessions.setCompleted(loggedSets[i].id, true);
    }

    if (finish) {
      if (finishedAt != null) {
        await (db.update(db.sessions)..where((t) => t.id.equals(sessionId)))
            .write(SessionsCompanion(finishedAt: Value(finishedAt)));
      } else {
        await sessions.finish(sessionId);
      }
    }
  }

  Future<int> firstExerciseId() async {
    final exercise = await (db.select(db.exercises)..limit(1)).getSingle();
    return exercise.id;
  }

  test('o catálogo é semeado na criação do banco', () async {
    final all = await db.select(db.exercises).get();

    expect(all.length, greaterThan(50));
    expect(all.where((e) => e.name == 'Supino reto barra'), hasLength(1));
    expect(all.every((e) => e.isCustom == false), isTrue);
  });

  test('exercício inédito não tem referência anterior', () async {
    final exerciseId = await firstExerciseId();

    final last = await progress.lastPerformance(exerciseId);

    expect(last, isEmpty);
  });

  test('lastPerformance traz a sessão finalizada mais recente', () async {
    final exerciseId = await firstExerciseId();
    final routineId = await routines.createRoutine('Upper 1');
    await routines.addExercise(routineId, exerciseId, setCount: 2);

    final week1 = await sessions.startFromRoutine(routineId);
    await logAndFinish(week1, [
      [(65.0, 9)],
      [(62.5, 8)],
    ], finishedAt: DateTime(2026, 7, 22));

    final week2 = await sessions.startFromRoutine(routineId);
    await logAndFinish(week2, [
      [(70.0, 9)],
      [(67.5, 8)],
    ], finishedAt: DateTime(2026, 7, 29));

    final last = await progress.lastPerformance(exerciseId);

    expect(last, hasLength(2));
    expect(last[0].referenceLoadKg, 70);
    expect(last[1].referenceLoadKg, 67.5);
  });

  test('sessão em andamento nunca serve de referência', () async {
    final exerciseId = await firstExerciseId();
    final routineId = await routines.createRoutine('Upper 1');
    await routines.addExercise(routineId, exerciseId, setCount: 1);

    final finished = await sessions.startFromRoutine(routineId);
    await logAndFinish(finished, [
      [(70.0, 9)],
    ], finishedAt: DateTime(2026, 7, 29));

    // Treino de hoje, ainda aberto e já com carga maior digitada.
    final ongoing = await sessions.startFromRoutine(routineId);
    await logAndFinish(ongoing, [
      [(75.0, 9)],
    ], finish: false);

    final last = await progress.lastPerformance(
      exerciseId,
      excludeSessionId: ongoing,
    );

    // Tem que enxergar os 70 kg da semana passada, não os 75 de agora.
    expect(last, hasLength(1));
    expect(last.first.referenceLoadKg, 70);
  });

  test('history vem em ordem cronológica e vira indicadores', () async {
    final exerciseId = await firstExerciseId();
    final routineId = await routines.createRoutine('Upper 1');
    await routines.addExercise(routineId, exerciseId, setCount: 1);

    for (final (day, load) in [(22, 65.0), (29, 67.5), (5, 70.0)]) {
      final id = await sessions.startFromRoutine(routineId);
      await logAndFinish(id, [
        [(load, 9)],
      ], finishedAt: day == 5 ? DateTime(2026, 8, 5) : DateTime(2026, 7, day));
    }

    final history = await progress.history(exerciseId);

    expect(history.map((p) => p.metrics.topLoadKg), [65.0, 67.5, 70.0]);
    expect(history.first.date.isBefore(history.last.date), isTrue);
  });

  test(
    'o resumo compara com a sessão anterior, não com a mais recente',
    () async {
      final exerciseId = await firstExerciseId();
      final routineId = await routines.createRoutine('Upper 1');
      await routines.addExercise(routineId, exerciseId, setCount: 1);

      final ids = <int>[];
      for (final (day, load) in [(22, 65.0), (29, 67.5), (5, 70.0)]) {
        final id = await sessions.startFromRoutine(routineId);
        await logAndFinish(
          id,
          [
            [(load, 9)],
          ],
          finishedAt: day == 5 ? DateTime(2026, 8, 5) : DateTime(2026, 7, day),
        );
        ids.add(id);
      }

      // Abrindo a sessão do meio no histórico: a referência tem que ser a de 22
      // de julho (65 kg), e não a de 5 de agosto, que veio depois.
      final middle = await progress.summarize(ids[1]);

      expect(middle!.exercises, hasLength(1));
      expect(middle.exercises.first.metrics.topLoadKg, 67.5);
      expect(middle.exercises.first.previous?.topLoadKg, 65);
      expect(middle.exercises.first.verdict, Verdict.evoluiu);
      expect(middle.exercises.first.loadDeltaKg, closeTo(2.5, 0.0001));
    },
  );

  test('a primeira sessão do exercício não tem veredito', () async {
    final exerciseId = await firstExerciseId();
    final routineId = await routines.createRoutine('Upper 1');
    await routines.addExercise(routineId, exerciseId, setCount: 1);

    final id = await sessions.startFromRoutine(routineId);
    await logAndFinish(id, [
      [(70.0, 9)],
    ], finishedAt: DateTime(2026, 8, 5));

    final summary = await progress.summarize(id);

    expect(summary!.exercises.first.verdict, Verdict.semReferencia);
    expect(summary.totalVolumeKg, 70 * 9);
    expect(summary.totalSets, 1);
  });

  test('sessão só de aquecimento não vira ponto no gráfico', () async {
    final exerciseId = await firstExerciseId();
    final routineId = await routines.createRoutine('Upper 1');
    final linkId = await routines.addExercise(
      routineId,
      exerciseId,
      setCount: 0,
    );
    await routines.addSet(linkId, type: SetType.aquecimento);

    final sessionId = await sessions.startFromRoutine(routineId);
    await logAndFinish(sessionId, [
      [(40.0, 12)],
    ], finishedAt: DateTime(2026, 8, 5));

    final history = await progress.history(exerciseId);

    expect(history, isEmpty);
  });

  test('drop set sobrevive à ida e volta do banco', () async {
    final exerciseId = await firstExerciseId();
    final routineId = await routines.createRoutine('Upper 1');
    final linkId = await routines.addExercise(
      routineId,
      exerciseId,
      setCount: 0,
    );
    await routines.addSet(linkId, type: SetType.drop, segmentCount: 3);

    final sessionId = await sessions.startFromRoutine(routineId);
    await logAndFinish(sessionId, [
      [(60.0, 8), (45.0, 6), (30.0, 5)],
    ], finishedAt: DateTime(2026, 8, 5));

    final last = await progress.lastPerformance(exerciseId);

    expect(last, hasLength(1));
    expect(last.first.type, SetType.drop);
    expect(last.first.segments, hasLength(3));
    expect(last.first.referenceLoadKg, 60);
    expect(last.first.totalReps, 19);
    expect(computeMetrics(last).volumeKg, 60 * 8 + 45 * 6 + 30 * 5);
  });

  test('apagar a sessão leva junto séries e segmentos', () async {
    final exerciseId = await firstExerciseId();
    final routineId = await routines.createRoutine('Upper 1');
    await routines.addExercise(routineId, exerciseId, setCount: 2);

    final sessionId = await sessions.startFromRoutine(routineId);
    expect(await db.select(db.setSegments).get(), isNotEmpty);

    await sessions.delete(sessionId);

    expect(await db.select(db.loggedSets).get(), isEmpty);
    expect(await db.select(db.setSegments).get(), isEmpty);
    expect(await db.select(db.sessionExercises).get(), isEmpty);
  });

  test('excluir uma sessão a tira do gráfico e da referência', () async {
    final exerciseId = await firstExerciseId();
    final routineId = await routines.createRoutine('Upper 1');
    await routines.addExercise(routineId, exerciseId, setCount: 1);

    final ids = <int>[];
    for (final (day, load) in [(22, 65.0), (29, 67.5), (5, 70.0)]) {
      final id = await sessions.startFromRoutine(routineId);
      await logAndFinish(id, [
        [(load, 9)],
      ], finishedAt: day == 5 ? DateTime(2026, 8, 5) : DateTime(2026, 7, day));
      ids.add(id);
    }

    // A mais recente (70 kg) foi um treino que não deveria contar.
    await sessions.delete(ids.last);

    final history = await progress.history(exerciseId);
    expect(history.map((p) => p.metrics.topLoadKg), [65.0, 67.5]);

    // E a referência de "última vez" volta a ser a de 29 de julho.
    final last = await progress.lastPerformance(exerciseId);
    expect(last.first.referenceLoadKg, 67.5);

    // Nada de série ou segmento órfão no banco.
    final orphanSets = await db.select(db.loggedSets).get();
    final orphanSegments = await db.select(db.setSegments).get();
    expect(orphanSets, hasLength(2));
    expect(orphanSegments, hasLength(2));
  });

  test('arquivar exercício não apaga o histórico dele', () async {
    final exerciseId = await firstExerciseId();
    final routineId = await routines.createRoutine('Upper 1');
    await routines.addExercise(routineId, exerciseId, setCount: 1);

    final sessionId = await sessions.startFromRoutine(routineId);
    await logAndFinish(sessionId, [
      [(70.0, 9)],
    ], finishedAt: DateTime(2026, 8, 5));

    await (db.update(db.exercises)..where((t) => t.id.equals(exerciseId)))
        .write(ExercisesCompanion(archivedAt: Value(DateTime(2026, 8, 6))));

    final history = await progress.history(exerciseId);

    expect(history, hasLength(1));
    expect(history.first.metrics.topLoadKg, 70);
  });
}
