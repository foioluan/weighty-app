import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

// database.g.dart é um part deste arquivo e referencia os enums pelo nome,
// então eles precisam estar importados aqui mesmo sem uso direto.
// ignore: unused_import
import '../../domain/models/enums.dart';
import 'exercise_seed.dart';
import 'tables.dart';
import 'text_repair.dart';

part 'database.g.dart';

@DriftDatabase(
  tables: [
    Exercises,
    Routines,
    RoutineExercises,
    PlannedSets,
    Sessions,
    SessionExercises,
    LoggedSets,
    SetSegments,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Sem argumento abre o arquivo do app. Os testes passam um executor em
  /// memória (`NativeDatabase.memory()`).
  AppDatabase([QueryExecutor? executor])
    : super(executor ?? driftDatabase(name: 'treino'));

  @override
  int get schemaVersion => 2;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _seedCatalog();
    },
    onUpgrade: (m, from, to) async {
      // v2 não mudou o schema: só conserta nomes que ficaram com dupla
      // codificação em bancos criados antes dela.
      if (from < 2) await repairEncoding();
    },
    beforeOpen: (details) async {
      // Sem isto o SQLite ignora as FKs e os ON DELETE CASCADE não rodam.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// Percorre os textos visíveis e reverte dupla codificação onde encontrar.
  ///
  /// Público porque a importação de backup precisa rodar o mesmo reparo: um
  /// arquivo exportado de um banco corrompido carrega os nomes corrompidos.
  Future<int> repairEncoding() async {
    var fixed = 0;

    await transaction(() async {
      for (final row in await select(exercises).get()) {
        final name = repairDoubleEncoded(row.name);
        if (name == null) continue;
        await (update(exercises)..where((t) => t.id.equals(row.id))).write(
          ExercisesCompanion(name: Value(name)),
        );
        fixed++;
      }

      for (final row in await select(routines).get()) {
        final name = repairDoubleEncoded(row.name);
        if (name == null) continue;
        await (update(routines)..where((t) => t.id.equals(row.id))).write(
          RoutinesCompanion(name: Value(name)),
        );
        fixed++;
      }

      // O nome do treino é copiado para a sessão, então precisa do mesmo
      // tratamento — senão o histórico continua exibindo o texto quebrado.
      for (final row in await select(sessions).get()) {
        final name = repairDoubleEncoded(row.routineName);
        if (name == null) continue;
        await (update(sessions)..where((t) => t.id.equals(row.id))).write(
          SessionsCompanion(routineName: Value(name)),
        );
        fixed++;
      }
    });

    return fixed;
  }

  Future<void> _seedCatalog() async {
    await batch((b) {
      b.insertAll(exercises, [
        for (final e in seedExercises)
          ExercisesCompanion.insert(
            name: e.name,
            muscleGroup: e.group,
            equipment: e.equipment,
          ),
      ]);
    });
  }
}
