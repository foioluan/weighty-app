import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treino/data/db/database.dart';
import 'package:treino/data/repos/routine_repository.dart';
import 'package:treino/data/repos/session_repository.dart';
import 'package:treino/domain/models/enums.dart';

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
}
