import 'package:drift/drift.dart';

import '../../domain/metrics/progress_metrics.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/performance.dart';
import '../db/database.dart';

/// Um ponto da série histórica de um exercício: o que foi feito numa sessão
/// finalizada, já reduzido a indicadores.
class ProgressPoint {
  const ProgressPoint({
    required this.sessionId,
    required this.date,
    required this.metrics,
    required this.sets,
  });

  final int sessionId;
  final DateTime date;
  final ExerciseMetrics metrics;
  final List<PerformedSet> sets;
}

/// Um exercício no resumo pós-treino: o que foi feito, e como se compara com a
/// vez anterior.
class ExerciseSummary {
  const ExerciseSummary({
    required this.exercise,
    required this.metrics,
    required this.previous,
    required this.verdict,
    required this.sets,
  });

  final Exercise exercise;
  final ExerciseMetrics metrics;
  final ExerciseMetrics? previous;
  final Verdict verdict;
  final List<PerformedSet> sets;

  double? get loadDeltaKg {
    final current = metrics.topLoadKg;
    final before = previous?.topLoadKg;
    if (current == null || before == null) return null;
    return current - before;
  }

  /// Repetições feitas na carga máxima do dia. Quando a mesma carga aparece em
  /// várias séries, vale a de mais repetições: é a melhor execução daquela
  /// carga, e é assim que um recorde se conta.
  int? get topLoadReps {
    final top = metrics.topLoadKg;
    if (top == null) return null;

    int? best;
    for (final set in sets) {
      if (!set.type.countsForProgress) continue;
      for (final segment in set.filledSegments) {
        if ((segment.weightKg - top).abs() > loadEpsilon) continue;
        if (best == null || segment.reps > best) best = segment.reps;
      }
    }
    return best;
  }
}

/// A fatia de um grupo muscular no volume do treino.
class GroupSlice {
  const GroupSlice({required this.group, required this.volumeKg});

  final MuscleGroup group;
  final double volumeKg;
}

/// A série mais pesada do treino, seja de que exercício for.
class HeaviestSet {
  const HeaviestSet({
    required this.exercise,
    required this.loadKg,
    required this.reps,
  });

  final Exercise exercise;
  final double loadKg;
  final int reps;
}

class SessionSummary {
  const SessionSummary({required this.session, required this.exercises});

  final Session session;
  final List<ExerciseSummary> exercises;

  double get totalVolumeKg =>
      exercises.fold(0, (sum, e) => sum + e.metrics.volumeKg);

  int get totalSets =>
      exercises.fold(0, (sum, e) => sum + e.metrics.workingSetCount);

  Duration? get duration => session.finishedAt?.difference(session.startedAt);

  int get improvedCount =>
      exercises.where((e) => e.verdict == Verdict.evoluiu).length;

  /// Quantos exercícios tinham vez anterior com que se comparar. É o
  /// denominador honesto de "evoluíram": um exercício estreando não tinha como
  /// evoluir, e contá-lo faria o dia parecer pior do que foi.
  int get comparableCount =>
      exercises.where((e) => e.verdict != Verdict.semReferencia).length;

  /// Volume por grupo muscular, do maior para o menor. Vários exercícios do
  /// mesmo grupo somam numa fatia só — é o grupo que interessa no gráfico, não
  /// o exercício.
  List<GroupSlice> get volumeByGroup {
    final byGroup = <MuscleGroup, double>{};
    for (final exercise in exercises) {
      byGroup.update(
        exercise.exercise.muscleGroup,
        (value) => value + exercise.metrics.volumeKg,
        ifAbsent: () => exercise.metrics.volumeKg,
      );
    }

    final slices = [
      for (final entry in byGroup.entries)
        if (entry.value > 0)
          GroupSlice(group: entry.key, volumeKg: entry.value),
    ];
    slices.sort((a, b) => b.volumeKg.compareTo(a.volumeKg));
    return slices;
  }

  HeaviestSet? get heaviestSet {
    HeaviestSet? best;
    for (final exercise in exercises) {
      final load = exercise.metrics.topLoadKg;
      final reps = exercise.topLoadReps;
      if (load == null || reps == null) continue;
      if (best == null || load > best.loadKg) {
        best = HeaviestSet(
          exercise: exercise.exercise,
          loadKg: load,
          reps: reps,
        );
      }
    }
    return best;
  }
}

/// Um recorde de carga: a maior carga do exercício naquele dia superou tudo o
/// que já havia sido registrado antes dele.
///
/// Estrear um exercício **não** é recorde. Sem marca anterior não há o que
/// bater, e chamar a primeira sessão de recorde tornaria o indicador barato.
class LoadRecord {
  const LoadRecord({
    required this.exercise,
    required this.loadKg,
    required this.reps,
    required this.previousBestKg,
  });

  final Exercise exercise;
  final double loadKg;
  final int reps;
  final double previousBestKg;

  double get deltaKg => loadKg - previousBestKg;
}

/// Tudo que a imagem do treino precisa, numa consulta só. Existe para a tela
/// não ter que combinar dois providers e ficar meio pronta na tela.
class SessionShareData {
  const SessionShareData({required this.summary, required this.records});

  final SessionSummary summary;

  /// Do maior ganho para o menor: o recorde mais expressivo primeiro.
  final List<LoadRecord> records;
}

/// Volume de uma semana, para o minigráfico da home.
class WeekPoint {
  const WeekPoint({required this.start, required this.volumeKg});

  final DateTime start;
  final double volumeKg;
}

/// Resumo da semana corrente mostrado no topo da home.
class WeekSummary {
  const WeekSummary({
    required this.volumeKg,
    required this.sessions,
    required this.plannedRoutines,
    required this.recentWeeks,
  });

  final double volumeKg;
  final int sessions;

  /// Quantos treinos existem cadastrados — o denominador de "3 de 4 feitos".
  final int plannedRoutines;

  /// Semanas anteriores em ordem cronológica, incluindo a atual.
  final List<WeekPoint> recentWeeks;

  bool get isEmpty =>
      sessions == 0 && recentWeeks.every((w) => w.volumeKg == 0);

  /// Variação contra a semana anterior, quando as duas têm volume.
  double? get deltaRatio {
    if (recentWeeks.length < 2) return null;
    final previous = recentWeeks[recentWeeks.length - 2].volumeKg;
    if (previous == 0) return null;
    return (volumeKg - previous) / previous;
  }
}

/// Leituras de evolução. Só enxerga sessões finalizadas — uma sessão em
/// andamento não pode servir de referência para ela mesma.
class ProgressRepository {
  ProgressRepository(this._db);

  final AppDatabase _db;

  /// As séries do exercício na sessão finalizada mais recente. É o que alimenta
  /// o valor fantasma e o delta durante o treino.
  ///
  /// [excludeSessionId] tira a sessão em andamento da busca.
  /// [before] restringe a busca a sessões anteriores a uma data. É o que faz o
  /// histórico comparar cada sessão com a que veio antes dela, e não com a
  /// mais recente de todas.
  Future<List<PerformedSet>> lastPerformance(
    int exerciseId, {
    int? excludeSessionId,
    DateTime? before,
  }) async {
    final link = await _mostRecentSessionExercise(
      exerciseId,
      excludeSessionId: excludeSessionId,
      before: before,
    );
    if (link == null) return const [];
    return _performedSetsFor(link.id);
  }

  /// Histórico completo do exercício, do mais antigo para o mais recente
  /// (ordem que os gráficos esperam).
  Future<List<ProgressPoint>> history(int exerciseId) async {
    final query =
        _db.select(_db.sessionExercises).join([
            innerJoin(
              _db.sessions,
              _db.sessions.id.equalsExp(_db.sessionExercises.sessionId),
            ),
          ])
          ..where(
            _db.sessionExercises.exerciseId.equals(exerciseId) &
                _db.sessions.finishedAt.isNotNull(),
          )
          ..orderBy([OrderingTerm.asc(_db.sessions.finishedAt)]);

    final rows = await query.get();

    final points = <ProgressPoint>[];
    for (final row in rows) {
      final link = row.readTable(_db.sessionExercises);
      final session = row.readTable(_db.sessions);
      final sets = await _performedSetsFor(link.id);
      final metrics = computeMetrics(sets);

      // Sessão em que o exercício foi pulado, ou só teve aquecimento, não vira
      // ponto no gráfico.
      if (metrics.isEmpty) continue;

      points.add(
        ProgressPoint(
          sessionId: session.id,
          date: session.finishedAt!,
          metrics: metrics,
          sets: sets,
        ),
      );
    }
    return points;
  }

  /// Resumo de uma sessão: por exercício, o que foi feito e o veredito contra
  /// a vez anterior. Alimenta a tela pós-treino e o detalhe no histórico.
  Future<SessionSummary?> summarize(int sessionId) async {
    final session = await (_db.select(
      _db.sessions,
    )..where((t) => t.id.equals(sessionId))).getSingleOrNull();
    if (session == null) return null;

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

    final summaries = <ExerciseSummary>[];
    for (final row in rows) {
      final link = row.readTable(_db.sessionExercises);
      final exercise = row.readTable(_db.exercises);

      final sets = await _performedSetsFor(link.id);
      final metrics = computeMetrics(sets);
      if (metrics.isEmpty) continue;

      final previousSets = await lastPerformance(
        exercise.id,
        excludeSessionId: sessionId,
        before: session.finishedAt,
      );
      final previous = previousSets.isEmpty
          ? null
          : computeMetrics(previousSets);

      summaries.add(
        ExerciseSummary(
          exercise: exercise,
          metrics: metrics,
          previous: previous,
          verdict: compareExercise(metrics, previous),
          sets: sets,
        ),
      );
    }

    return SessionSummary(session: session, exercises: summaries);
  }

  /// Resumo + recordes de uma sessão, para a imagem do treino.
  Future<SessionShareData?> shareData(int sessionId) async {
    final summary = await summarize(sessionId);
    if (summary == null) return null;
    return SessionShareData(
      summary: summary,
      records: await recordsFor(summary),
    );
  }

  /// Quais exercícios da sessão bateram a melhor carga de todos os tempos.
  ///
  /// "De todos os tempos" conta só o que veio **antes** desta sessão: abrir uma
  /// sessão antiga no histórico tem que mostrar os recordes daquele dia, não os
  /// de hoje.
  Future<List<LoadRecord>> recordsFor(SessionSummary summary) async {
    final records = <LoadRecord>[];

    for (final exercise in summary.exercises) {
      final load = exercise.metrics.topLoadKg;
      final reps = exercise.topLoadReps;
      if (load == null || reps == null) continue;

      final best = await _bestLoadBefore(
        exercise.exercise.id,
        excludeSessionId: summary.session.id,
        before: summary.session.finishedAt,
      );
      if (best == null || load - best <= loadEpsilon) continue;

      records.add(
        LoadRecord(
          exercise: exercise.exercise,
          loadKg: load,
          reps: reps,
          previousBestKg: best,
        ),
      );
    }

    records.sort((a, b) => b.deltaKg.compareTo(a.deltaKg));
    return records;
  }

  /// A maior carga já registrada no exercício em sessões finalizadas anteriores.
  ///
  /// Os filtros são os mesmos de [computeMetrics] — aquecimento fora, segmento
  /// em branco fora — para o recorde nunca discordar da carga máxima exibida.
  Future<double?> _bestLoadBefore(
    int exerciseId, {
    required int excludeSessionId,
    DateTime? before,
  }) async {
    final maxLoad = _db.setSegments.weightKg.max();

    var predicate =
        _db.sessionExercises.exerciseId.equals(exerciseId) &
        _db.sessions.finishedAt.isNotNull() &
        _db.sessions.id.equals(excludeSessionId).not() &
        _db.setSegments.reps.isBiggerThanValue(0) &
        _db.loggedSets.setType.equalsValue(SetType.aquecimento).not();
    if (before != null) {
      predicate =
          predicate & _db.sessions.finishedAt.isSmallerThanValue(before);
    }

    final query = _db.selectOnly(_db.setSegments)
      ..addColumns([maxLoad])
      ..join([
        innerJoin(
          _db.loggedSets,
          _db.loggedSets.id.equalsExp(_db.setSegments.loggedSetId),
        ),
        innerJoin(
          _db.sessionExercises,
          _db.sessionExercises.id.equalsExp(_db.loggedSets.sessionExerciseId),
        ),
        innerJoin(
          _db.sessions,
          _db.sessions.id.equalsExp(_db.sessionExercises.sessionId),
        ),
      ])
      ..where(predicate);

    return (await query.getSingle()).read(maxLoad);
  }

  /// Resumo das últimas [weeks] semanas, com a atual por último.
  ///
  /// A semana começa na segunda-feira: é como se pensa uma rotina de treino,
  /// não como o `DateTime.weekday` numera (domingo = 7).
  Future<WeekSummary> weekSummary({int weeks = 6, DateTime? now}) async {
    final reference = now ?? DateTime.now();
    final today = DateTime(reference.year, reference.month, reference.day);
    final currentStart = today.subtract(Duration(days: today.weekday - 1));
    final firstStart = currentStart.subtract(Duration(days: 7 * (weeks - 1)));

    final finished =
        await (_db.select(_db.sessions)..where(
              (t) =>
                  t.finishedAt.isNotNull() &
                  t.finishedAt.isBiggerOrEqualValue(firstStart),
            ))
            .get();

    final volumeByWeek = <DateTime, double>{
      for (var i = 0; i < weeks; i++)
        firstStart.add(Duration(days: 7 * i)): 0.0,
    };
    var sessionsThisWeek = 0;

    for (final session in finished) {
      final date = session.finishedAt!;
      final day = DateTime(date.year, date.month, date.day);
      final start = day.subtract(Duration(days: day.weekday - 1));
      if (!volumeByWeek.containsKey(start)) continue;

      final summary = await summarize(session.id);
      volumeByWeek[start] =
          volumeByWeek[start]! + (summary?.totalVolumeKg ?? 0);
      if (start == currentStart) sessionsThisWeek++;
    }

    final ordered = volumeByWeek.keys.toList()..sort();

    return WeekSummary(
      volumeKg: volumeByWeek[currentStart] ?? 0,
      sessions: sessionsThisWeek,
      plannedRoutines: (await (_db.select(
        _db.routines,
      )..where((t) => t.archivedAt.isNull())).get()).length,
      recentWeeks: [
        for (final start in ordered)
          WeekPoint(start: start, volumeKg: volumeByWeek[start]!),
      ],
    );
  }

  Future<SessionExercise?> _mostRecentSessionExercise(
    int exerciseId, {
    int? excludeSessionId,
    DateTime? before,
  }) async {
    var predicate =
        _db.sessionExercises.exerciseId.equals(exerciseId) &
        _db.sessions.finishedAt.isNotNull();
    if (excludeSessionId != null) {
      predicate = predicate & _db.sessions.id.equals(excludeSessionId).not();
    }
    if (before != null) {
      predicate =
          predicate & _db.sessions.finishedAt.isSmallerThanValue(before);
    }

    final query =
        _db.select(_db.sessionExercises).join([
            innerJoin(
              _db.sessions,
              _db.sessions.id.equalsExp(_db.sessionExercises.sessionId),
            ),
          ])
          ..where(predicate)
          ..orderBy([OrderingTerm.desc(_db.sessions.finishedAt)])
          ..limit(1);

    final row = await query.getSingleOrNull();
    return row?.readTable(_db.sessionExercises);
  }

  /// Monta os [PerformedSet] de um exercício dentro de uma sessão, com os
  /// segmentos já na ordem certa.
  Future<List<PerformedSet>> _performedSetsFor(int sessionExerciseId) async {
    final sets =
        await (_db.select(_db.loggedSets)
              ..where((t) => t.sessionExerciseId.equals(sessionExerciseId))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();

    if (sets.isEmpty) return const [];

    final segments =
        await (_db.select(_db.setSegments)
              ..where((t) => t.loggedSetId.isIn(sets.map((s) => s.id)))
              ..orderBy([(t) => OrderingTerm.asc(t.position)]))
            .get();

    final bySet = <int, List<SetSegment>>{};
    for (final segment in segments) {
      bySet.putIfAbsent(segment.loggedSetId, () => []).add(segment);
    }

    return [
      for (final set in sets)
        PerformedSet(
          position: set.position,
          type: set.setType,
          segments: [
            for (final s in bySet[set.id] ?? const <SetSegment>[])
              SegmentData(weightKg: s.weightKg, reps: s.reps),
          ],
        ),
    ];
  }
}
