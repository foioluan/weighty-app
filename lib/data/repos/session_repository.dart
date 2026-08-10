import 'package:drift/drift.dart';

import '../../domain/models/enums.dart';
import '../db/database.dart';

/// Uma série durante a execução, com os segmentos já carregados.
class LiveSet {
  const LiveSet({
    required this.set,
    required this.segments,
    required this.plannedTargetReps,
    required this.plannedTargetRepsMax,
  });

  final LoggedSet set;
  final List<SetSegment> segments;
  final int? plannedTargetReps;
  final int? plannedTargetRepsMax;
}

class LiveExercise {
  const LiveExercise({
    required this.link,
    required this.exercise,
    required this.sets,
  });

  final SessionExercise link;
  final Exercise exercise;
  final List<LiveSet> sets;
}

class LiveSession {
  const LiveSession({required this.session, required this.exercises});

  final Session session;
  final List<LiveExercise> exercises;
}

class SessionRepository {
  SessionRepository(this._db);

  final AppDatabase _db;

  /// Cria a sessão copiando a estrutura do treino: cada série planejada vira
  /// uma série a preencher, com os segmentos em branco já criados.
  Future<int> startFromRoutine(int routineId) {
    return _db.transaction(() async {
      final routine = await (_db.select(
        _db.routines,
      )..where((t) => t.id.equals(routineId))).getSingle();

      final sessionId = await _db
          .into(_db.sessions)
          .insert(
            SessionsCompanion.insert(
              routineId: Value(routineId),
              routineName: routine.name,
              startedAt: DateTime.now(),
            ),
          );

      final links =
          await (_db.select(_db.routineExercises)
                ..where((t) => t.routineId.equals(routineId))
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();

      for (final link in links) {
        final sessionExerciseId = await _db
            .into(_db.sessionExercises)
            .insert(
              SessionExercisesCompanion.insert(
                sessionId: sessionId,
                exerciseId: link.exerciseId,
                position: link.position,
              ),
            );

        final planned =
            await (_db.select(_db.plannedSets)
                  ..where((t) => t.routineExerciseId.equals(link.id))
                  ..orderBy([(t) => OrderingTerm.asc(t.position)]))
                .get();

        for (final plan in planned) {
          final loggedSetId = await _db
              .into(_db.loggedSets)
              .insert(
                LoggedSetsCompanion.insert(
                  sessionExerciseId: sessionExerciseId,
                  position: plan.position,
                  setType: plan.setType,
                  plannedSetId: Value(plan.id),
                ),
              );

          await _createEmptySegments(loggedSetId, plan.segmentCount);
        }
      }

      return sessionId;
    });
  }

  Future<void> _createEmptySegments(int loggedSetId, int count) async {
    for (var i = 0; i < count; i++) {
      await _db
          .into(_db.setSegments)
          .insert(
            SetSegmentsCompanion.insert(
              loggedSetId: loggedSetId,
              position: i,
              weightKg: 0,
              reps: 0,
            ),
          );
    }
  }

  /// A sessão em andamento, se houver. É o que permite fechar o app no meio do
  /// treino e voltar de onde parou.
  Future<Session?> activeSession() {
    return (_db.select(_db.sessions)
          ..where((t) => t.finishedAt.isNull())
          ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
          ..limit(1))
        .getSingleOrNull();
  }

  /// O `readsFrom` é o que importa aqui: sem declarar as tabelas filhas, o
  /// Drift só reemitiria quando `sessions` mudasse, e digitar uma carga (que
  /// escreve em set_segments) não atualizaria a tela.
  Stream<LiveSession?> watchSession(int sessionId) {
    return _db
        .customSelect(
          'SELECT id FROM sessions WHERE id = ?',
          variables: [Variable<int>(sessionId)],
          readsFrom: {
            _db.sessions,
            _db.sessionExercises,
            _db.loggedSets,
            _db.setSegments,
          },
        )
        .watch()
        .asyncMap((rows) async {
          if (rows.isEmpty) return null;
          final session = await (_db.select(
            _db.sessions,
          )..where((t) => t.id.equals(sessionId))).getSingle();
          return LiveSession(
            session: session,
            exercises: await _liveExercises(sessionId),
          );
        });
  }

  Future<List<LiveExercise>> _liveExercises(int sessionId) async {
    final rows =
        await (_db.select(_db.sessionExercises).join([
                innerJoin(
                  _db.exercises,
                  _db.exercises.id.equalsExp(_db.sessionExercises.exerciseId),
                ),
              ])
              ..where(_db.sessionExercises.sessionId.equals(sessionId))
              ..orderBy([OrderingTerm.asc(_db.sessionExercises.position)]))
            .get();

    final result = <LiveExercise>[];
    for (final row in rows) {
      final link = row.readTable(_db.sessionExercises);

      final setRows =
          await (_db.select(_db.loggedSets).join([
                  leftOuterJoin(
                    _db.plannedSets,
                    _db.plannedSets.id.equalsExp(_db.loggedSets.plannedSetId),
                  ),
                ])
                ..where(_db.loggedSets.sessionExerciseId.equals(link.id))
                ..orderBy([OrderingTerm.asc(_db.loggedSets.position)]))
              .get();

      final sets = <LiveSet>[];
      for (final setRow in setRows) {
        final loggedSet = setRow.readTable(_db.loggedSets);
        final plan = setRow.readTableOrNull(_db.plannedSets);

        final segments =
            await (_db.select(_db.setSegments)
                  ..where((t) => t.loggedSetId.equals(loggedSet.id))
                  ..orderBy([(t) => OrderingTerm.asc(t.position)]))
                .get();

        sets.add(
          LiveSet(
            set: loggedSet,
            segments: segments,
            plannedTargetReps: plan?.targetReps,
            plannedTargetRepsMax: plan?.targetRepsMax,
          ),
        );
      }

      result.add(
        LiveExercise(
          link: link,
          exercise: row.readTable(_db.exercises),
          sets: sets,
        ),
      );
    }
    return result;
  }

  Future<void> updateSegment(int segmentId, {double? weightKg, int? reps}) {
    return (_db.update(
      _db.setSegments,
    )..where((t) => t.id.equals(segmentId))).write(
      SetSegmentsCompanion(
        weightKg: weightKg == null ? const Value.absent() : Value(weightKg),
        reps: reps == null ? const Value.absent() : Value(reps),
      ),
    );
  }

  Future<void> setCompleted(int loggedSetId, bool completed) {
    return (_db.update(_db.loggedSets)..where((t) => t.id.equals(loggedSetId)))
        .write(LoggedSetsCompanion(completed: Value(completed)));
  }

  /// Série extra criada durante o treino (não estava no planejamento).
  Future<int> addExtraSet(
    int sessionExerciseId, {
    SetType type = SetType.normal,
    int segmentCount = 1,
  }) {
    return _db.transaction(() async {
      final existing = await (_db.select(
        _db.loggedSets,
      )..where((t) => t.sessionExerciseId.equals(sessionExerciseId))).get();

      final id = await _db
          .into(_db.loggedSets)
          .insert(
            LoggedSetsCompanion.insert(
              sessionExerciseId: sessionExerciseId,
              position: existing.length,
              setType: type,
            ),
          );

      await _createEmptySegments(id, segmentCount);
      return id;
    });
  }

  Future<void> removeSet(int loggedSetId) {
    return (_db.delete(
      _db.loggedSets,
    )..where((t) => t.id.equals(loggedSetId))).go();
  }

  /// Ajusta a quantidade de segmentos (quedas do drop, blocos do cluster) de
  /// uma série já em execução.
  Future<void> setSegmentCount(int loggedSetId, int count) {
    return _db.transaction(() async {
      final current =
          await (_db.select(_db.setSegments)
                ..where((t) => t.loggedSetId.equals(loggedSetId))
                ..orderBy([(t) => OrderingTerm.asc(t.position)]))
              .get();

      if (count > current.length) {
        for (var i = current.length; i < count; i++) {
          await _db
              .into(_db.setSegments)
              .insert(
                SetSegmentsCompanion.insert(
                  loggedSetId: loggedSetId,
                  position: i,
                  weightKg: current.isNotEmpty ? current.last.weightKg : 0,
                  reps: 0,
                ),
              );
        }
      } else if (count < current.length) {
        for (final extra in current.sublist(count)) {
          await (_db.delete(
            _db.setSegments,
          )..where((t) => t.id.equals(extra.id))).go();
        }
      }
    });
  }

  /// Sessões finalizadas, da mais recente para a mais antiga.
  Stream<List<Session>> watchFinished() {
    return (_db.select(_db.sessions)
          ..where((t) => t.finishedAt.isNotNull())
          ..orderBy([(t) => OrderingTerm.desc(t.finishedAt)]))
        .watch();
  }

  /// Uma sessão já finalizada, com todo o conteúdo — usada pelo resumo e pelo
  /// detalhe no histórico.
  Future<LiveSession?> load(int sessionId) async {
    final session = await (_db.select(
      _db.sessions,
    )..where((t) => t.id.equals(sessionId))).getSingleOrNull();
    if (session == null) return null;

    return LiveSession(
      session: session,
      exercises: await _liveExercises(sessionId),
    );
  }

  Future<void> finish(int sessionId) {
    return (_db.update(_db.sessions)..where((t) => t.id.equals(sessionId)))
        .write(SessionsCompanion(finishedAt: Value(DateTime.now())));
  }

  /// Apaga a sessão e tudo que ela registrou (as FKs em cascata levam séries e
  /// segmentos junto).
  ///
  /// Serve para descartar um treino em andamento e para excluir um do
  /// histórico. Nos dois casos a sessão some dos gráficos e deixa de servir de
  /// referência de "última vez" — que é o efeito desejado ao apagar um treino
  /// que não deveria contar na evolução.
  Future<void> delete(int sessionId) {
    return (_db.delete(
      _db.sessions,
    )..where((t) => t.id.equals(sessionId))).go();
  }
}
