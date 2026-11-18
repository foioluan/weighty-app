import 'package:flutter/material.dart';

/// Escala tipográfica do iOS (Dynamic Type no tamanho padrão): corpo de 17,
/// título grande de 34 em negrito.
///
/// A versão anterior era compacta — corpo 15, título 28 em semibold — e a
/// hierarquia vinha quase só de cor. Com a escala do sistema, o título grande
/// em negrito é o que dá o "ar Apple" das telas raiz, e o corpo de 17 é o que
/// o olho espera ler num app de iPhone.
///
/// Inter não tem corte óptico para títulos, então o tracking dos tamanhos
/// grandes é apertado à mão — é o que o SF Display faz sozinho.
abstract final class AppText {
  static const family = 'Inter';

  /// Numerais de largura fixa: sem isso a coluna "dança" quando 9 vira 10 no
  /// meio da série.
  static const _tabular = [FontFeature.tabularFigures()];

  static const largeTitle = TextStyle(
    fontFamily: family,
    fontSize: 34,
    height: 1.12,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
  );

  static const title1 = TextStyle(
    fontFamily: family,
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.7,
  );

  /// Título de seção ("Treinos", "Esta semana"), como no Fitness e no Saúde.
  static const title2 = TextStyle(
    fontFamily: family,
    fontSize: 22,
    height: 1.2,
    fontWeight: FontWeight.w700,
    letterSpacing: -0.45,
  );

  static const title3 = TextStyle(
    fontFamily: family,
    fontSize: 20,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  /// Corpo em destaque: nome do exercício, título de linha forte.
  static const headline = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.3,
  );

  static const body = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.3,
  );

  static const bodyStrong = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.3,
  );

  static const callout = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.32,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.25,
  );

  /// Subtítulo de linha e de cartão.
  static const subheadline = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.33,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.2,
  );

  static const footnote = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.3,
    fontWeight: FontWeight.w400,
    letterSpacing: -0.05,
  );

  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w400,
  );

  static const caption2 = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.05,
  );

  /// Cabeçalho de coluna (CARGA, REPS). Maiúsculas com tracking aberto.
  ///
  /// Não é mais o rótulo de seção: no iOS atual a seção tem título em caixa
  /// normal e negrito, e a maiúscula pequena ficou só onde rotula dados.
  static const overline = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: 0.6,
  );

  /// A carga em destaque (resumo, cartão de métrica).
  static const numberLarge = TextStyle(
    fontFamily: family,
    fontSize: 34,
    height: 1.05,
    fontWeight: FontWeight.w700,
    letterSpacing: -1.0,
    fontFeatures: _tabular,
  );

  static const numberMedium = TextStyle(
    fontFamily: family,
    fontSize: 22,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
    fontFeatures: _tabular,
  );

  /// Valor dentro da célula de carga ou repetição.
  static const numberCell = TextStyle(
    fontFamily: family,
    fontSize: 17,
    height: 1.15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.3,
    fontFeatures: _tabular,
  );

  static const numberSmall = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.2,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    fontFeatures: _tabular,
  );
}
