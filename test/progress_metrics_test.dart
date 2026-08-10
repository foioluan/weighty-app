import 'package:flutter_test/flutter_test.dart';
import 'package:treino/domain/metrics/progress_metrics.dart';
import 'package:treino/domain/models/enums.dart';
import 'package:treino/domain/models/performance.dart';

PerformedSet _set(
  SetType type,
  List<(double, int)> segments, {
  int position = 0,
}) {
  return PerformedSet(
    position: position,
    type: type,
    segments: [
      for (final (weight, reps) in segments)
        SegmentData(weightKg: weight, reps: reps),
    ],
  );
}

void main() {
  group('computeMetrics', () {
    test('soma volume e acha a carga máxima entre séries normais', () {
      final metrics = computeMetrics([
        _set(SetType.normal, [(70, 9)], position: 0),
        _set(SetType.normal, [(67.5, 8)], position: 1),
      ]);

      expect(metrics.topLoadKg, 70);
      expect(metrics.volumeKg, 70 * 9 + 67.5 * 8);
      expect(metrics.totalReps, 17);
      expect(metrics.workingSetCount, 2);
    });

    test('ignora aquecimento em todos os indicadores', () {
      final metrics = computeMetrics([
        // Aquecimento pesado de propósito: se entrasse, viraria a carga máxima.
        _set(SetType.aquecimento, [(100, 12)], position: 0),
        _set(SetType.normal, [(70, 9)], position: 1),
      ]);

      expect(metrics.topLoadKg, 70);
      expect(metrics.volumeKg, 70 * 9);
      expect(metrics.workingSetCount, 1);
    });

    test('treino só com aquecimento não gera indicador', () {
      final metrics = computeMetrics([
        _set(SetType.aquecimento, [(40, 12)]),
      ]);

      expect(metrics.isEmpty, isTrue);
      expect(metrics.topLoadKg, isNull);
      expect(metrics.volumeKg, 0);
    });

    test('série criada e não preenchida não conta', () {
      final metrics = computeMetrics([
        _set(SetType.normal, [(0, 0)]),
      ]);

      expect(metrics.isEmpty, isTrue);
    });

    test('drop set soma todos os segmentos no volume', () {
      final metrics = computeMetrics([
        _set(SetType.drop, [(60, 8), (45, 6), (30, 5)]),
      ]);

      expect(metrics.topLoadKg, 60);
      expect(metrics.volumeKg, 60 * 8 + 45 * 6 + 30 * 5);
      expect(metrics.totalReps, 19);
      // Um drop set inteiro é uma série só.
      expect(metrics.workingSetCount, 1);
    });

    test('cluster mantém a carga e soma as reps dos blocos', () {
      final metrics = computeMetrics([
        _set(SetType.cluster, [(80, 3), (80, 3), (80, 3)]),
      ]);

      expect(metrics.topLoadKg, 80);
      expect(metrics.totalReps, 9);
      expect(metrics.volumeKg, 80 * 9);
    });

    test('1RM estimado usa Epley sobre o melhor segmento', () {
      final metrics = computeMetrics([
        _set(SetType.normal, [(70, 9)]),
      ]);

      expect(metrics.estimatedOneRmKg, closeTo(70 * (1 + 9 / 30), 0.0001));
    });

    test('1RM é nulo quando toda série passou do limite de reps', () {
      final metrics = computeMetrics([
        _set(SetType.normal, [(30, 20)]),
      ]);

      expect(metrics.estimatedOneRmKg, isNull);
      // O volume continua valendo — só o 1RM é que não faz sentido.
      expect(metrics.volumeKg, 600);
    });

    test('1RM ignora o segmento acima do limite mas usa os elegíveis', () {
      final metrics = computeMetrics([
        _set(SetType.normal, [(30, 20)], position: 0),
        _set(SetType.normal, [(60, 5)], position: 1),
      ]);

      expect(metrics.estimatedOneRmKg, closeTo(60 * (1 + 5 / 30), 0.0001));
    });
  });

  group('compareExercise', () {
    ExerciseMetrics of(List<PerformedSet> sets) => computeMetrics(sets);

    test('primeira vez do exercício não tem referência', () {
      final current = of([
        _set(SetType.normal, [(70, 9)]),
      ]);

      expect(compareExercise(current, null), Verdict.semReferencia);
    });

    test('carga maior é evolução', () {
      final previous = of([
        _set(SetType.normal, [(67.5, 9)]),
      ]);
      final current = of([
        _set(SetType.normal, [(70, 9)]),
      ]);

      expect(compareExercise(current, previous), Verdict.evoluiu);
    });

    test('carga menor é redução', () {
      final previous = of([
        _set(SetType.normal, [(70, 9)]),
      ]);
      final current = of([
        _set(SetType.normal, [(65, 9)]),
      ]);

      expect(compareExercise(current, previous), Verdict.reduziu);
    });

    test('mesma carga com mais reps é evolução', () {
      final previous = of([
        _set(SetType.normal, [(70, 8)]),
      ]);
      final current = of([
        _set(SetType.normal, [(70, 10)]),
      ]);

      expect(compareExercise(current, previous), Verdict.evoluiu);
    });

    test('carga e reps idênticas é manutenção', () {
      final previous = of([
        _set(SetType.normal, [(70, 9)]),
      ]);
      final current = of([
        _set(SetType.normal, [(70, 9)]),
      ]);

      expect(compareExercise(current, previous), Verdict.manteve);
    });

    test('ruído de ponto flutuante não vira evolução', () {
      final previous = of([
        _set(SetType.normal, [(0.1 + 0.2, 9)]),
      ]);
      final current = of([
        _set(SetType.normal, [(0.3, 9)]),
      ]);

      expect(compareExercise(current, previous), Verdict.manteve);
    });

    test('sessão anterior só de aquecimento não serve de referência', () {
      final previous = of([
        _set(SetType.aquecimento, [(40, 12)]),
      ]);
      final current = of([
        _set(SetType.normal, [(70, 9)]),
      ]);

      expect(compareExercise(current, previous), Verdict.semReferencia);
    });
  });

  group('compareSet', () {
    test('sem série anterior devolve comparação vazia', () {
      final result = compareSet(_set(SetType.normal, [(70, 9)]), null);

      expect(result.verdict, Verdict.semReferencia);
      expect(result.hasReference, isFalse);
      expect(result.deltaKg, isNull);
    });

    test('calcula o delta de carga e de reps', () {
      final result = compareSet(
        _set(SetType.normal, [(70, 9)]),
        _set(SetType.normal, [(67.5, 8)]),
      );

      expect(result.verdict, Verdict.evoluiu);
      expect(result.deltaKg, closeTo(2.5, 0.0001));
      expect(result.deltaReps, 1);
    });

    test('drop set compara pela carga de entrada, não pela final', () {
      // A carga de entrada subiu (60 -> 65) mesmo com a última queda mais leve.
      final result = compareSet(
        _set(SetType.drop, [(65, 8), (40, 6)]),
        _set(SetType.drop, [(60, 8), (45, 6)]),
      );

      expect(result.verdict, Verdict.evoluiu);
      expect(result.deltaKg, closeTo(5, 0.0001));
    });

    test('mesma carga com menos reps é redução', () {
      final result = compareSet(
        _set(SetType.normal, [(70, 7)]),
        _set(SetType.normal, [(70, 9)]),
      );

      expect(result.verdict, Verdict.reduziu);
      expect(result.deltaKg, 0);
      expect(result.deltaReps, -2);
    });
  });
}
