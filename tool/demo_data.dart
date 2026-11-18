// Dados de exemplo: dois treinos e três semanas de sessões com evolução.
//
// Compartilhado pelo seed do emulador (tool/seed_demo.dart) e pela prévia das
// telas (tool/preview_screens.dart). Usa os repositórios do app, então o schema
// nunca sai de sincronia.
import 'package:drift/drift.dart';
import 'package:treino/data/db/database.dart';
import 'package:treino/data/repos/routine_repository.dart';
import 'package:treino/data/repos/session_repository.dart';
import 'package:treino/domain/models/enums.dart';

/// Ids do que o seed criou, para quem precisar abrir uma tela específica.
class DemoIds {
  const DemoIds({
    required this.upper,
    required this.lower,
    required this.remada,
    required this.desenvolvimento,
    required this.rosca,
  });

  final int upper;
  final int lower;
  final int remada;
  final int desenvolvimento;
  final int rosca;
}

Future<DemoIds> seedDemo(AppDatabase db) async {
  final routines = RoutineRepository(db);
  final sessions = SessionRepository(db);

  Future<int> exerciseId(String name) async {
    final row = await (db.select(
      db.exercises,
    )..where((t) => t.name.equals(name))).getSingle();
    return row.id;
  }

  // Upper: um aquecimento, séries normais e um drop set no fim.
  final upper = await routines.createRoutine('Upper 1');
  final supino = await routines.addExercise(
    upper,
    await exerciseId('Supino reto barra'),
    setCount: 0,
  );
  await routines.addSet(supino, type: SetType.aquecimento, targetReps: 12);
  for (var i = 0; i < 3; i++) {
    await routines.addSet(supino, targetReps: 8, targetRepsMax: 10);
  }
  await routines.addSet(supino, type: SetType.drop, segmentCount: 3);

  final remada = await routines.addExercise(
    upper,
    await exerciseId('Remada curvada barra'),
    setCount: 3,
    targetReps: 10,
  );
  final desenvolvimento = await routines.addExercise(
    upper,
    await exerciseId('Desenvolvimento halteres'),
    setCount: 3,
    targetReps: 12,
  );
  final rosca = await routines.addExercise(
    upper,
    await exerciseId('Rosca direta barra'),
    setCount: 3,
    targetReps: 12,
  );

  // Lower, com um cluster na extensora.
  final lower = await routines.createRoutine('Lower 1');
  await routines.addExercise(
    lower,
    await exerciseId('Agachamento livre'),
    setCount: 4,
    targetReps: 8,
  );
  await routines.addExercise(
    lower,
    await exerciseId('Stiff barra'),
    setCount: 3,
    targetReps: 10,
  );
  final extensora = await routines.addExercise(
    lower,
    await exerciseId('Cadeira extensora'),
    setCount: 2,
    targetReps: 15,
  );
  await routines.addSet(extensora, type: SetType.cluster, segmentCount: 3);
  await routines.addExercise(
    lower,
    await exerciseId('Panturrilha em pé'),
    setCount: 4,
    targetReps: 15,
  );

  /// Preenche todas as séries de uma sessão com a carga base do exercício,
  /// subindo a cada semana. Drop e cluster recebem os segmentos certos.
  Future<void> runSession({
    required int routineId,
    required DateTime date,
    required double bump,
  }) async {
    final id = await sessions.startFromRoutine(routineId);
    final live = await sessions.load(id);

    for (final exercise in live!.exercises) {
      final base = _baseLoad(exercise.exercise.name) + bump;

      for (final set in exercise.sets) {
        final type = set.set.setType;
        for (var i = 0; i < set.segments.length; i++) {
          final segment = set.segments[i];

          final (weight, reps) = switch (type) {
            SetType.aquecimento => (base * 0.5, 12),
            // Drop: cada queda tira 25% da carga de entrada.
            SetType.drop => (base * (0.85 - i * 0.22), 8 - i * 2),
            // Cluster: mesma carga, blocos curtos.
            SetType.cluster => (base * 0.8, 4),
            SetType.normal => (base, 9 - set.set.position),
          };

          await sessions.updateSegment(
            segment.id,
            weightKg: (weight / 2.5).round() * 2.5,
            reps: reps.clamp(3, 15),
          );
        }
        await sessions.setCompleted(set.set.id, true);
      }
    }

    await (db.update(db.sessions)..where((t) => t.id.equals(id))).write(
      SessionsCompanion(
        finishedAt: Value(date.add(const Duration(minutes: 52))),
      ),
    );
    await (db.update(db.sessions)..where((t) => t.id.equals(id))).write(
      SessionsCompanion(startedAt: Value(date)),
    );
  }

  // Três semanas de evolução, alternando Upper e Lower.
  final start = DateTime.now().subtract(const Duration(days: 21));
  for (var week = 0; week < 3; week++) {
    await runSession(
      routineId: upper,
      date: start.add(Duration(days: week * 7, hours: 18)),
      bump: week * 2.5,
    );
    await runSession(
      routineId: lower,
      date: start.add(Duration(days: week * 7 + 3, hours: 18)),
      bump: week * 5.0,
    );
  }

  return DemoIds(
    upper: upper,
    lower: lower,
    remada: remada,
    desenvolvimento: desenvolvimento,
    rosca: rosca,
  );
}

/// Cargas plausíveis por exercício, para os gráficos não ficarem irreais.
double _baseLoad(String name) => switch (name) {
  'Supino reto barra' => 70,
  'Remada curvada barra' => 60,
  'Desenvolvimento halteres' => 22,
  'Rosca direta barra' => 30,
  'Agachamento livre' => 100,
  'Stiff barra' => 80,
  'Cadeira extensora' => 55,
  'Panturrilha em pé' => 90,
  _ => 40,
};
