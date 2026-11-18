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

  /// Margem lateral das telas. 20, como nas telas do iOS: com cartões de canto
  /// grande, 16 deixava a curva encostada na borda do aparelho.
  static const page = 20.0;
}

/// Raios. Os grandes seguem o iOS 26: cartão de 26 e folha de 32, concêntricos
/// com o canto do aparelho. Todos são desenhados como superelipse
/// ([AppShapes]), e não como arco de círculo — é a curva contínua, sem a
/// "quina" onde o arco encontra a reta, que faz um canto grande parecer Apple
/// e não um retângulo arredondado qualquer.
abstract final class Radii {
  static const sm = 10.0;
  static const md = 12.0;

  /// Cartão e grupo de lista.
  static const lg = 26.0;

  /// Folha, diálogo e menu.
  static const xl = 32.0;
  static const pill = 999.0;
}

/// Formas de canto contínuo.
abstract final class AppShapes {
  static RoundedSuperellipseBorder superellipse(
    double radius, {
    BorderSide side = BorderSide.none,
  }) => RoundedSuperellipseBorder(
    borderRadius: BorderRadius.all(Radius.circular(radius)),
    side: side,
  );

  /// Decoração de superfície com canto contínuo. Substitui o
  /// `BoxDecoration(borderRadius: ...)`, cujo arco circular é exatamente a
  /// quina que se tenta evitar.
  static ShapeDecoration surface(
    Color color, {
    double radius = Radii.lg,
    List<BoxShadow>? shadows,
  }) => ShapeDecoration(
    color: color,
    shape: superellipse(radius),
    shadows: shadows,
  );
}

/// Alturas de controle. 50 é o botão grande do iOS e o que a mão suada
/// precisa; 36 é para controles secundários que não são o caminho principal.
/// Linha de lista com 52 acompanha o corpo de 17 px.
abstract final class Heights {
  static const control = 50.0;
  static const controlCompact = 36.0;
  static const cell = 44.0;
  static const row = 52.0;
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
    required this.fill,
    required this.glassFill,
    required this.glassEdge,
    required this.glassHighlight,
    required this.glassShadow,
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

  /// Preenchimento neutro: realce de toque, trilho de controle, polegar
  /// inativo. É o `systemFill` do iOS.
  final Color fill;

  /// Vidro (Liquid Glass): preenchimento translúcido por cima do desfoque.
  final Color glassFill;

  /// Borda de 1 px do vidro, que some em degradê para baixo.
  final Color glassEdge;

  /// Realce interno no topo do vidro — o reflexo que faz a superfície ler
  /// como volume e não como película.
  final Color glassHighlight;

  final Color glassShadow;

  final bool isDark;

  // Cinzas de sistema da Apple. Fundo preto puro no escuro: é o que deixa o
  // cartão #1C1C1E se separar sem borda nenhuma, e o que o vidro precisa para
  // parecer vidro.
  static const dark = AppColors(
    bg: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    surfaceRaised: Color(0xFF232325),
    surfaceInput: Color(0xFF2E2E31),
    hairline: Color(0x2EFFFFFF),
    hairlineStrong: Color(0x47FFFFFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFF98989F),
    textTertiary: Color(0xFF6C6C72),
    textGhost: Color(0xFF48484A),
    accent: Color(0xFFF5B24A),
    accentPressed: Color(0xFFDA9C3A),
    onAccent: Color(0xFF1E1405),
    accentSubtle: Color(0x2EF5B24A),
    up: Color(0xFF30D158),
    down: Color(0xFFFF453A),
    flat: Color(0xFF8E8E93),
    upSubtle: Color(0x2930D158),
    downSubtle: Color(0x29FF453A),
    fill: Color(0x3D78788C),
    glassFill: Color(0x70232327),
    glassEdge: Color(0x33FFFFFF),
    glassHighlight: Color(0x40FFFFFF),
    glassShadow: Color(0x66000000),
    isDark: true,
  );

  static const light = AppColors(
    bg: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    surfaceRaised: Color(0xFFFFFFFF),
    surfaceInput: Color(0xFFEEEEF0),
    hairline: Color(0x1F000000),
    hairlineStrong: Color(0x33000000),
    textPrimary: Color(0xFF000000),
    textSecondary: Color(0xFF6C6C70),
    textTertiary: Color(0xFF8E8E93),
    textGhost: Color(0xFFC4C4C7),
    // Bronze escurecido: o tom do escuro não passa contraste sobre branco.
    // #A36800 e não o #A86B00 do estudo, que ficava em 4,4:1 — abaixo dos
    // 4,5:1 que o texto pequeno precisa.
    accent: Color(0xFFA36800),
    accentPressed: Color(0xFF855500),
    onAccent: Color(0xFFFFFFFF),
    accentSubtle: Color(0x1FA36800),
    up: Color(0xFF248A3D),
    down: Color(0xFFD70015),
    flat: Color(0xFF6C6C70),
    upSubtle: Color(0x1F248A3D),
    downSubtle: Color(0x1FD70015),
    fill: Color(0x24787880),
    glassFill: Color(0xA6FFFFFF),
    glassEdge: Color(0xCCFFFFFF),
    glassHighlight: Color(0xFFFFFFFF),
    glassShadow: Color(0x24000000),
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
