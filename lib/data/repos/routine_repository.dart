import 'package:drift/drift.dart';

import '../../domain/models/enums.dart';
import '../db/database.dart';

/// Um exercício dentro de um treino, com as séries planejadas.
class RoutineExerciseDetail {
  const RoutineExerciseDetail({
    required this.link,
    required this.exercise,
    required this.sets,
  });

  final RoutineExercise link;
  final Exercise exercise;
  final List<PlannedSet> sets;
}

class RoutineDetail {
  const RoutineDetail({required this.routine, required this.exercises});

  final Routine routine;
  final List<RoutineExerciseDetail> exercises;

  int get totalSets => exercises.fold(0, (sum, e) => sum + e.sets.length);
}

/// Resumo para a lista da home.
class RoutineSummary {
  const RoutineSummary({
    required this.routine,
    required this.exerciseCount,
    required this.setCount,
    required this.muscleGroups,
    required this.lastPerformedAt,
  });

  final Routine routine;
  final int exerciseCount;
  final int setCount;

  /// Grupos distintos do treino, do mais frequente para o menos. A home mostra
  /// como pontos coloridos: dá para reconhecer um dia de superior ou inferior
  /// sem ler o nome.
  final List<MuscleGroup> muscleGroups;

  final DateTime? lastPerformedAt;
}

class RoutineRepository {
  RoutineRepository(this._db);

  final AppDatabase _db;

  Stream<List<Routine>> watchRoutines() {
    return (_db.select(_db.routines)
          ..where((t) => t.archivedAt.isNull())
          ..orderBy([
            (t) => OrderingTerm.asc(t.position),
            (t) => OrderingTerm.asc(t.id),
          ]))
        .watch();
  }

  /// Lista da home: treino, quantos exercícios tem e quando foi feito pela
  /// última vez.
  Stream<List<RoutineSummary>> watchSummaries() {
    return watchRoutines().asyncMap((routines) async {
      final result = <RoutineSummary>[];
      for (final routine in routines) {
        final links = await (_db.select(_db.routineExercises).join([
          innerJoin(
            _db.exercises,
            _db.exercises.id.equalsExp(_db.routineExercises.exerciseId),
          ),
        ])..where(_db.routineExercises.routineId.equals(routine.id))).get();

        // Conta quantas vezes cada grupo aparece para ordenar os pontos pelo
        // que o treino realmente enfatiza.
        final frequency = <MuscleGroup, int>{};
        var sets = 0;
        for (final row in links) {
          final group = row.readTable(_db.exercises).muscleGroup;
          frequency[group] = (frequency[group] ?? 0) + 1;

          final planned =
              await (_db.select(_db.plannedSets)..where(
                    (t) => t.routineExerciseId.equals(
                      row.readTable(_db.routineExercises).id,
                    ),
                  ))
                  .get();
          sets += planned.length;
        }

        final ordered = frequency.keys.toList()
          ..sort((a, b) => frequency[b]!.compareTo(frequency[a]!));

        final lastSession =
            await (_db.select(_db.sessions)
                  ..where(
                    (t) =>
                        t.routineId.equals(routine.id) &
                        t.finishedAt.isNotNull(),
                  )
                  ..orderBy([(t) => OrderingTerm.desc(t.finishedAt)])
                  ..limit(1))
                .getSingleOrNull();

        result.add(
          RoutineSummary(
            routine: routine,
            exerciseCount: links.length,
            setCount: sets,
            muscleGroups: ordered,
            lastPerformedAt: lastSession?.finishedAt,
          ),
        );
      }
      return result;
    });
  }

  Future<RoutineDetail?> detail(int routineId) async {
    final routine = await (_db.select(
      _db.routines,
    )..where((t) => t.id.equals(routineId))).getSingleOrNull();
    if (routine == null) return null;

    final links =
        await (_db.select(_db.routineExercises).join([
                innerJoin(
                  _db.exercises,
                  _db.exercises.id.equalsExp(_db.routineExercises.exerciseId),
                ),
              ])
              ..where(_db.routineExercises.routineId.equals(routineId))
              ..orderBy([OrderingTerm.asc(_db.routineExercises.position)]))
            .get();

    final details = <RoutineExerciseDetail>[];
    for (final row in links) {
      final link = row.readTable(_db.routineExercises);
      final sets =
          await (_db.select(_db.plannedSets)
                ..where((t) => t.routineExerciseId.equals(link.id))
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();

      details.add(
        RoutineExerciseDetail(
          link: link,
          exercise: row.readTable(_db.exercises),
          sets: sets,
        ),
      );
    }

    return RoutineDetail(routine: routine, exercises: details);
  }

  Future<int> createRoutine(String name) async {
    final count = await _db.select(_db.routines).get();
    return _db
        .into(_db.routines)
        .insert(
          RoutinesCompanion.insert(
            name: name.trim(),
            position: Value(count.length),
          ),
        );
  }

  Future<void> renameRoutine(int id, String name) {
    return (_db.update(_db.routines)..where((t) => t.id.equals(id))).write(
      RoutinesCompanion(name: Value(name.trim())),
    );
  }

  /// Apaga o treino e o conteúdo dele (exercícios e séries planejadas saem em
  /// cascata).
  ///
  /// O histórico sobrevive: `sessions.routineId` é `setNull` e o nome do treino
  /// foi copiado para a sessão quando ela começou. Foi para este caso que o
  /// snapshot existe.
  Future<void> deleteRoutine(int id) {
    return (_db.delete(_db.routines)..where((t) => t.id.equals(id))).go();
  }

  Future<void> archiveRoutine(int id) {
    return (_db.update(_db.routines)..where((t) => t.id.equals(id))).write(
      RoutinesCompanion(archivedAt: Value(DateTime.now())),
    );
  }

  /// Adiciona o exercício no fim do treino já com [setCount] séries normais.
  Future<int> addExercise(
    int routineId,
    int exerciseId, {
    int setCount = 3,
    int targetReps = 10,
  }) async {
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.routineExercises,
      )..where((t) => t.routineId.equals(routineId))).get();

      final linkId = await _db
          .into(_db.routineExercises)
          .insert(
            RoutineExercisesCompanion.insert(
              routineId: routineId,
              exerciseId: exerciseId,
              position: existing.length,
            ),
          );

      for (var i = 0; i < setCount; i++) {
        await _db
            .into(_db.plannedSets)
            .insert(
              PlannedSetsCompanion.insert(
                routineExerciseId: linkId,
                position: i,
                setType: SetType.normal,
                targetReps: Value(targetReps),
              ),
            );
      }
      return linkId;
    });
  }

  Future<void> removeExercise(int routineExerciseId) {
    return (_db.delete(
      _db.routineExercises,
    )..where((t) => t.id.equals(routineExerciseId))).go();
  }

  /// Troca o exercício de um vínculo mantendo as séries planejadas.
  ///
  /// É uma coluna só porque as séries penduram no id do vínculo, não no
  /// exercício — trocar aqui preserva tipo, alvo de repetições, segmentos e
  /// posição de cada série, que é justamente a diferença entre "substituir" e
  /// "excluir e adicionar de novo".
  ///
  /// O histórico não se mexe: a sessão copia o `exerciseId` para
  /// `sessionExercises` quando começa, então o que já foi treinado continua
  /// registrado no exercício antigo.
  Future<void> replaceExercise(int routineExerciseId, int newExerciseId) {
    return (_db.update(_db.routineExercises)
          ..where((t) => t.id.equals(routineExerciseId)))
        .write(RoutineExercisesCompanion(exerciseId: Value(newExerciseId)));
  }

  /// Reordena os exercícios do treino conforme a ordem dos ids recebidos.
  Future<void> reorderExercises(List<int> routineExerciseIdsInOrder) {
    return _db.transaction(() async {
      for (var i = 0; i < routineExerciseIdsInOrder.length; i++) {
        await (_db.update(_db.routineExercises)
              ..where((t) => t.id.equals(routineExerciseIdsInOrder[i])))
            .write(RoutineExercisesCompanion(position: Value(i)));
      }
    });
  }

  Future<int> addSet(
    int routineExerciseId, {
    SetType type = SetType.normal,
    int? targetReps,
    int? targetRepsMax,
    int segmentCount = 1,
  }) {
    return _db.transaction(() async {
      // Compacta antes de anexar: um banco que já tenha buraco ou posição
      // repetida (de antes desta correção) se conserta na próxima série
      // criada, e a nova vai mesmo para o fim.
      final count = await _compactSetPositions(routineExerciseId);

      return _db
          .into(_db.plannedSets)
          .insert(
            PlannedSetsCompanion.insert(
              routineExerciseId: routineExerciseId,
              position: count,
              setType: type,
              targetReps: Value(targetReps),
              targetRepsMax: Value(targetRepsMax),
              segmentCount: Value(segmentCount),
            ),
          );
    });
  }

  Future<void> updateSet(
    int plannedSetId, {
    SetType? type,
    int? targetReps,
    int? targetRepsMax,
    int? segmentCount,
  }) {
    return (_db.update(
      _db.plannedSets,
    )..where((t) => t.id.equals(plannedSetId))).write(
      PlannedSetsCompanion(
        setType: type == null ? const Value.absent() : Value(type),
        targetReps: Value(targetReps),
        targetRepsMax: Value(targetRepsMax),
        segmentCount: segmentCount == null
            ? const Value.absent()
            : Value(segmentCount),
      ),
    );
  }

  /// Apaga a série e renumera as que ficam (0, 1, 2…).
  ///
  /// Sem a renumeração, apagar a do meio de 0, 1, 2, 3 deixava 0, 2, 3, e a
  /// próxima série criada pegava a posição pela contagem — 3, repetida. Como a
  /// sessão copia a posição e a comparação com a última vez casa as séries por
  /// ela, duas séries com a mesma posição disputavam a mesma referência.
  ///
  /// Renumerar faz a comparação ser por ordem — a 2ª série de hoje contra a 2ª
  /// da última vez —, que é o que a tela mostra e o que a série extra da
  /// sessão já fazia.
  Future<void> removeSet(int plannedSetId) {
    return _db.transaction(() async {
      final set = await (_db.select(
        _db.plannedSets,
      )..where((t) => t.id.equals(plannedSetId))).getSingleOrNull();
      if (set == null) return;

      await (_db.delete(
        _db.plannedSets,
      )..where((t) => t.id.equals(plannedSetId))).go();
      await _compactSetPositions(set.routineExerciseId);
    });
  }

  /// Reescreve as posições das séries do vínculo como 0, 1, 2…, na ordem
  /// atual (o id desempata posições repetidas). Devolve quantas séries há.
  Future<int> _compactSetPositions(int routineExerciseId) async {
    final sets =
        await (_db.select(_db.plannedSets)
              ..where((t) => t.routineExerciseId.equals(routineExerciseId))
              ..orderBy([
                (t) => OrderingTerm.asc(t.position),
                (t) => OrderingTerm.asc(t.id),
              ]))
            .get();

    for (var i = 0; i < sets.length; i++) {
      if (sets[i].position == i) continue;
      await (_db.update(_db.plannedSets)..where((t) => t.id.equals(sets[i].id)))
          .write(PlannedSetsCompanion(position: Value(i)));
    }
    return sets.length;
  }
}
