import '../models/performance.dart';

/// Cargas são múltiplos de 0,25 kg na prática; esta folga evita que ruído de
/// ponto flutuante vire "evoluiu 0,0000001 kg". Pública porque a comparação de
/// recordes precisa usar exatamente a mesma tolerância do veredito.
const loadEpsilon = 0.001;

/// Acima de 12 repetições as fórmulas de 1RM perdem confiabilidade, então o
/// app prefere não mostrar número nenhum a mostrar um número errado.
const maxRepsForOneRm = 12;

enum Verdict {
  evoluiu,
  manteve,
  reduziu,

  /// Primeira vez que o exercício aparece — não há com o que comparar.
  semReferencia,
}

/// Indicadores de um exercício dentro de uma sessão. Séries de aquecimento
/// nunca entram aqui.
class ExerciseMetrics {
  const ExerciseMetrics({
    required this.topLoadKg,
    required this.volumeKg,
    required this.estimatedOneRmKg,
    required this.totalReps,
    required this.workingSetCount,
  });

  /// Maior carga levantada em qualquer segmento.
  final double? topLoadKg;

  /// Soma de carga × reps de todos os segmentos.
  final double volumeKg;

  /// Epley sobre o melhor segmento elegível. Nulo se todas as séries passaram
  /// de [maxRepsForOneRm].
  final double? estimatedOneRmKg;

  final int totalReps;
  final int workingSetCount;

  bool get isEmpty => workingSetCount == 0;

  static const empty = ExerciseMetrics(
    topLoadKg: null,
    volumeKg: 0,
    estimatedOneRmKg: null,
    totalReps: 0,
    workingSetCount: 0,
  );
}

/// Epley: carga × (1 + reps / 30). Para 1 repetição devolve a própria carga.
double estimateOneRm(double weightKg, int reps) => weightKg * (1 + reps / 30);

ExerciseMetrics computeMetrics(List<PerformedSet> sets) {
  final working = sets
      .where((s) => s.type.countsForProgress && s.hasData)
      .toList();

  if (working.isEmpty) return ExerciseMetrics.empty;

  double? topLoad;
  double? bestOneRm;
  var volume = 0.0;
  var reps = 0;

  for (final set in working) {
    for (final segment in set.filledSegments) {
      volume += segment.volumeKg;
      reps += segment.reps;

      if (topLoad == null || segment.weightKg > topLoad) {
        topLoad = segment.weightKg;
      }

      if (segment.reps <= maxRepsForOneRm) {
        final oneRm = estimateOneRm(segment.weightKg, segment.reps);
        if (bestOneRm == null || oneRm > bestOneRm) bestOneRm = oneRm;
      }
    }
  }

  return ExerciseMetrics(
    topLoadKg: topLoad,
    volumeKg: volume,
    estimatedOneRmKg: bestOneRm,
    totalReps: reps,
    workingSetCount: working.length,
  );
}

/// Veredito do exercício entre duas sessões: compara a carga máxima e, no
/// empate de carga, desempata pelo total de repetições. Mesma carga com mais
/// reps é evolução; mesma carga com as mesmas reps é manutenção.
Verdict compareExercise(ExerciseMetrics current, ExerciseMetrics? previous) {
  if (previous == null || previous.isEmpty) return Verdict.semReferencia;
  if (current.isEmpty) return Verdict.semReferencia;

  final currentTop = current.topLoadKg;
  final previousTop = previous.topLoadKg;
  if (currentTop == null || previousTop == null) return Verdict.semReferencia;

  final loadDelta = currentTop - previousTop;
  if (loadDelta.abs() > loadEpsilon) {
    return loadDelta > 0 ? Verdict.evoluiu : Verdict.reduziu;
  }

  final repsDelta = current.totalReps - previous.totalReps;
  if (repsDelta > 0) return Verdict.evoluiu;
  if (repsDelta < 0) return Verdict.reduziu;
  return Verdict.manteve;
}

/// Comparação série a série, usada durante o treino para mostrar o delta logo
/// abaixo do campo assim que a série é concluída.
class SetComparison {
  const SetComparison({
    required this.verdict,
    required this.deltaKg,
    required this.deltaReps,
    required this.previous,
  });

  final Verdict verdict;

  /// Diferença de carga de referência. Nulo quando não há série anterior.
  final double? deltaKg;
  final int? deltaReps;
  final PerformedSet? previous;

  bool get hasReference => previous != null;

  static const none = SetComparison(
    verdict: Verdict.semReferencia,
    deltaKg: null,
    deltaReps: null,
    previous: null,
  );
}

SetComparison compareSet(PerformedSet current, PerformedSet? previous) {
  if (previous == null || !previous.hasData || !current.hasData) {
    return SetComparison.none;
  }

  final currentLoad = current.referenceLoadKg!;
  final previousLoad = previous.referenceLoadKg!;
  final deltaKg = currentLoad - previousLoad;
  final deltaReps = current.totalReps - previous.totalReps;

  final Verdict verdict;
  if (deltaKg.abs() > loadEpsilon) {
    verdict = deltaKg > 0 ? Verdict.evoluiu : Verdict.reduziu;
  } else if (deltaReps > 0) {
    verdict = Verdict.evoluiu;
  } else if (deltaReps < 0) {
    verdict = Verdict.reduziu;
  } else {
    verdict = Verdict.manteve;
  }

  return SetComparison(
    verdict: verdict,
    deltaKg: deltaKg,
    deltaReps: deltaReps,
    previous: previous,
  );
}
