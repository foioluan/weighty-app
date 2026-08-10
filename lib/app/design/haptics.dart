import 'package:flutter/services.dart';

/// Resposta tátil do app.
///
/// Na academia isso não é enfeite: confirma o toque sem exigir que você olhe a
/// tela entre uma série e outra, com a mão suada e o celular no banco.
abstract final class Haptics {
  /// Ajuste fino — passo de carga, troca de aba, seleção.
  static void tick() => HapticFeedback.selectionClick();

  /// Série concluída. O único evento que merece um toque mais firme.
  static void confirm() => HapticFeedback.mediumImpact();

  /// Algo foi recusado ou apagado.
  static void warn() => HapticFeedback.heavyImpact();
}
