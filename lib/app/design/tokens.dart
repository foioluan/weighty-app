import 'package:flutter/material.dart';

import '../../domain/models/enums.dart';

/// Espaçamentos. Múltiplos de 2 com passos curtos: a densidade da tela de
/// treino depende de conseguir ajustar 2 px, não 8.
abstract final class Space {
  static const xxs = 2.0;
  static const xs = 4.0;
  static const sm = 6.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const xxl = 20.0;
  static const xxxl = 28.0;
}

abstract final class Radii {
  static const sm = 8.0;
  static const md = 11.0;
  static const lg = 14.0;
  static const xl = 18.0;
  static const pill = 999.0;
}

/// Alturas de controle. 44 é o alvo de toque confortável do iOS e o que a mão
/// suada precisa; 34 é para controles secundários que não são o caminho
/// principal.
abstract final class Heights {
  static const control = 44.0;
  static const controlCompact = 34.0;
  static const cell = 38.0;
  static const row = 46.0;
}

/// Prefixado porque `Durations` já existe no material.dart do Flutter.
abstract final class AppDurations {
  static const fast = Duration(milliseconds: 120);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 320);
}

/// Paleta do app, exposta como ThemeExtension para os componentes lerem do
/// contexto em vez de importar constantes soltas.
///
/// Regra que organiza tudo: **verde e vermelho significam só progressão**. A
/// cor de ação é o bronze. Se o botão fosse verde, "evoluiu" perderia força.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.bg,
    required this.surface,
    required this.surfaceRaised,
    required this.surfaceInput,
    required this.hairline,
    required this.hairlineStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textTertiary,
    required this.textGhost,
    required this.accent,
    required this.accentPressed,
    required this.onAccent,
    required this.accentSubtle,
    required this.up,
    required this.down,
    required this.flat,
    required this.upSubtle,
    required this.downSubtle,
    required this.isDark,
  });

  /// Fundo da página.
  final Color bg;

  /// Card e agrupamento de lista.
  final Color surface;

  /// Elemento acima do card (folha, diálogo).
  final Color surfaceRaised;

  /// Fundo de campo numérico e de texto.
  final Color surfaceInput;

  final Color hairline;
  final Color hairlineStrong;

  final Color textPrimary;
  final Color textSecondary;
  final Color textTertiary;

  /// Valor da última vez, mostrado dentro do campo vazio.
  final Color textGhost;

  final Color accent;
  final Color accentPressed;
  final Color onAccent;
  final Color accentSubtle;

  /// Evoluiu.
  final Color up;

  /// Reduziu.
  final Color down;

  /// Manteve, ou sem referência.
  final Color flat;

  final Color upSubtle;
  final Color downSubtle;

  final bool isDark;

  // Fundo mais escuro e superfícies mais claras que na primeira versão: com
  // pouco contraste entre card e página, tudo virava um bloco só.
  static const dark = AppColors(
    bg: Color(0xFF08090B),
    surface: Color(0xFF15181C),
    surfaceRaised: Color(0xFF1E2227),
    surfaceInput: Color(0xFF262B31),
    hairline: Color(0x14FFFFFF),
    hairlineStrong: Color(0x26FFFFFF),
    textPrimary: Color(0xFFF2F3F5),
    textSecondary: Color(0xFF9BA1A8),
    textTertiary: Color(0xFF6E7378),
    textGhost: Color(0xFF4A4E55),
    accent: Color(0xFFE0A64B),
    accentPressed: Color(0xFFC28F3D),
    onAccent: Color(0xFF1A1408),
    accentSubtle: Color(0x24E0A64B),
    up: Color(0xFF34C759),
    down: Color(0xFFFF453A),
    flat: Color(0xFF8A9099),
    upSubtle: Color(0x2434C759),
    downSubtle: Color(0x24FF453A),
    isDark: true,
  );

  static const light = AppColors(
    bg: Color(0xFFF4F5F7),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceInput: Color(0xFFEDEFF2),
    hairline: Color(0x14000000),
    hairlineStrong: Color(0x24000000),
    textPrimary: Color(0xFF16181B),
    textSecondary: Color(0xFF5F6570),
    textTertiary: Color(0xFF8A9099),
    textGhost: Color(0xFFB3B9C2),
    // Bronze escurecido: o tom do escuro não passa contraste sobre branco.
    accent: Color(0xFF9A6E14),
    accentPressed: Color(0xFF7E5A0F),
    onAccent: Color(0xFFFFFFFF),
    accentSubtle: Color(0x1F9A6E14),
    up: Color(0xFF1B7F3B),
    down: Color(0xFFC5221F),
    flat: Color(0xFF6E7378),
    upSubtle: Color(0x1F1B7F3B),
    downSubtle: Color(0x1FC5221F),
    isDark: false,
  );

  /// Cor do grupo muscular, usada só em detalhes pequenos: barra lateral do
  /// card e ponto ao lado do nome.
  ///
  /// Nenhum tom fica na faixa do bronze (para não confundir com ação) nem na
  /// do verde de evolução (para não sugerir progresso).
  Color forMuscleGroup(MuscleGroup group) {
    final base = switch (group) {
      MuscleGroup.peito => const Color(0xFFE0645A),
      MuscleGroup.costas => const Color(0xFF4C8FD9),
      MuscleGroup.ombros => const Color(0xFFB072E0),
      MuscleGroup.trapezio => const Color(0xFF6E76CC),
      MuscleGroup.biceps => const Color(0xFFE05A96),
      MuscleGroup.triceps => const Color(0xFFC95AE0),
      MuscleGroup.antebraco => const Color(0xFF8891A3),
      MuscleGroup.quadriceps => const Color(0xFF3FB6D9),
      MuscleGroup.posteriorCoxa => const Color(0xFF4FBFA8),
      MuscleGroup.gluteos => const Color(0xFFD9789E),
      MuscleGroup.panturrilha => const Color(0xFF7E8FB8),
      MuscleGroup.abdomen => const Color(0xFFA98CD9),
    };

    if (isDark) return base;
    // Os tons foram calibrados no escuro; no claro precisam escurecer para
    // continuarem legíveis sobre branco.
    final hsl = HSLColor.fromColor(base);
    return hsl
        .withLightness((hsl.lightness - 0.16).clamp(0.0, 1.0))
        .withSaturation((hsl.saturation + 0.08).clamp(0.0, 1.0))
        .toColor();
  }

  /// A cor do veredito, para não repetir o switch em cada tela.
  Color verdict(bool? improved) => switch (improved) {
    true => up,
    false => down,
    null => flat,
  };

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(AppColors? other, double t) {
    // Trocar de tema é uma mudança discreta de estado, não uma animação de
    // cor: interpolar cada slot só produziria um cinza intermediário.
    if (other == null) return this;
    return t < 0.5 ? this : other;
  }
}
