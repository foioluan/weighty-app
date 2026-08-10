import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treino/data/backup/backup_service.dart';
import 'package:treino/data/db/database.dart';
import 'package:treino/data/repos/progress_repository.dart';
import 'package:treino/data/repos/routine_repository.dart';
import 'package:treino/data/repos/session_repository.dart';
import 'package:treino/domain/models/enums.dart';

void main() {
  late AppDatabase source;

  setUp(() => source = AppDatabase(NativeDatabase.memory()));
  tearDown(() => source.close());

  /// Monta um treino com drop set e uma sessão finalizada.
  Future<void> seed(AppDatabase db) async {
    final routines = RoutineRepository(db);
    final sessions = SessionRepository(db);

    final exercise = await (db.select(db.exercises)..limit(1)).getSingle();
    final routineId = await routines.createRoutine('Upper 1');
    final linkId = await routines.addExercise(
      routineId,
      exercise.id,
      setCount: 1,
      targetReps: 9,
    );
    await routines.addSet(linkId, type: SetType.drop, segmentCount: 3);

    final sessionId = await sessions.startFromRoutine(routineId);
    final links = await (db.select(
      db.sessionExercises,
    )..where((t) => t.sessionId.equals(sessionId))).get();
    final sets =
        await (db.select(db.loggedSets)
              ..where((t) => t.sessionExerciseId.equals(links.first.id))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();

    final values = [
      [(70.0, 9)],
      [(60.0, 8), (45.0, 6), (30.0, 5)],
    ];

    for (var i = 0; i < sets.length; i++) {
      final segments =
          await (db.select(db.setSegments)
                ..where((t) => t.loggedSetId.equals(sets[i].id))
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();
      for (var j = 0; j < values[i].length; j++) {
        await sessions.updateSegment(
          segments[j].id,
          weightKg: values[i][j].$1,
          reps: values[i][j].$2,
        );
      }
      await sessions.setCompleted(sets[i].id, true);
    }

    await (db.update(db.sessions)..where((t) => t.id.equals(sessionId))).write(
      SessionsCompanion(finishedAt: Value(DateTime(2026, 8, 5, 10, 30))),
    );
  }

  test('exportar e importar preserva treinos, sessões e drop sets', () async {
    await seed(source);
    final json = await BackupService(source).exportJson();

    final restored = AppDatabase(NativeDatabase.memory());
    addTearDown(restored.close);
    await BackupService(restored).importJson(json);

    final routines = await restored.select(restored.routines).get();
    expect(routines.map((r) => r.name), ['Upper 1']);

    final sessions = await restored.select(restored.sessions).get();
    expect(sessions, hasLength(1));
    expect(sessions.first.finishedAt, DateTime(2026, 8, 5, 10, 30));

    // O que mais importa: o histórico de cargas continua legível.
    final exerciseId = (await (restored.select(
      restored.exercises,
    )..limit(1)).getSingle()).id;
    final last = await ProgressRepository(restored).lastPerformance(exerciseId);

    expect(last, hasLength(2));
    expect(last[0].referenceLoadKg, 70);
    expect(last[1].type, SetType.drop);
    expect(last[1].segments, hasLength(3));
    expect(last[1].totalReps, 19);
  });

  test('importar substitui o conteúdo anterior em vez de somar', () async {
    await seed(source);
    final json = await BackupService(source).exportJson();

    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    await RoutineRepository(target).createRoutine('Treino que será apagado');

    await BackupService(target).importJson(json);

    final routines = await target.select(target.routines).get();
    expect(routines.map((r) => r.name), ['Upper 1']);
  });

  test('arquivo inválido é recusado sem tocar no banco', () async {
    await seed(source);

    await expectLater(
      BackupService(source).importJson('isso não é json'),
      throwsA(isA<BackupException>()),
    );
    await expectLater(
      BackupService(source).importJson('{"foo": 1}'),
      throwsA(isA<BackupException>()),
    );

    expect(await source.select(source.routines).get(), hasLength(1));
  });

  test('backup de versão futura é recusado com aviso claro', () async {
    final future = jsonEncode({'formatVersion': 999, 'exercises': []});

    await expectLater(
      BackupService(source).importJson(future),
      throwsA(
        isA<BackupException>().having(
          (e) => e.message,
          'message',
          contains('versão mais nova'),
        ),
      ),
    );
  });

  test('tipo de série desconhecido não derruba a importação', () async {
    await seed(source);
    final data =
        jsonDecode(await BackupService(source).exportJson())
            as Map<String, dynamic>;

    // Simula um backup feito por uma versão do app que já tem rest-pause.
    (data['loggedSets'] as List).first['setType'] = 'restPause';

    final target = AppDatabase(NativeDatabase.memory());
    addTearDown(target.close);
    await BackupService(target).importJson(jsonEncode(data));

    final sets = await target.select(target.loggedSets).get();
    expect(sets, hasLength(2));
    expect(sets.first.setType, SetType.normal);
  });
}
