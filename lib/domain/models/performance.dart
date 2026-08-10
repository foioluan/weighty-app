import 'enums.dart';

/// Um par (carga, reps) dentro de uma série.
class SegmentData {
  const SegmentData({required this.weightKg, required this.reps});

  final double weightKg;
  final int reps;

  /// Segmento em branco (série criada mas ainda não preenchida) não entra em
  /// nenhum cálculo.
  bool get isFilled => reps > 0;

  double get volumeKg => weightKg * reps;

  @override
  String toString() => '${weightKg}kg x $reps';
}

/// Uma série executada, já desacoplada do Drift para o domínio poder ser
/// testado sem banco.
class PerformedSet {
  const PerformedSet({
    required this.position,
    required this.type,
    required this.segments,
  });

  final int position;
  final SetType type;
  final List<SegmentData> segments;

  Iterable<SegmentData> get filledSegments => segments.where((s) => s.isFilled);

  bool get hasData => filledSegments.isNotEmpty;

  /// A carga que representa a série numa comparação. Para drop set é a carga
  /// de entrada (primeiro segmento); para cluster a carga é única; para normal
  /// só existe uma.
  double? get referenceLoadKg => hasData ? filledSegments.first.weightKg : null;

  int get totalReps => filledSegments.fold(0, (sum, s) => sum + s.reps);
}
