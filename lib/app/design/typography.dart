import 'package:flutter/material.dart';

/// Escala tipográfica compacta, na linha do iOS: a hierarquia vem de peso e
/// cor, não de tamanho. Só a carga levantada usa corpo grande, porque é o
/// único número que precisa ser lido de longe.
abstract final class AppText {
  static const family = 'Inter';

  /// Numerais de largura fixa: sem isso a coluna "dança" quando 9 vira 10 no
  /// meio da série.
  static const _tabular = [FontFeature.tabularFigures()];

  static const largeTitle = TextStyle(
    fontFamily: family,
    fontSize: 28,
    height: 1.15,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.6,
  );

  static const title1 = TextStyle(
    fontFamily: family,
    fontSize: 21,
    height: 1.2,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
  );

  static const title2 = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.25,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.2,
  );

  static const title3 = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.3,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.1,
  );

  static const body = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );

  static const bodyStrong = TextStyle(
    fontFamily: family,
    fontSize: 15,
    height: 1.35,
    fontWeight: FontWeight.w500,
  );

  static const callout = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.35,
    fontWeight: FontWeight.w400,
  );

  static const footnote = TextStyle(
    fontFamily: family,
    fontSize: 12,
    height: 1.3,
    fontWeight: FontWeight.w400,
  );

  static const caption = TextStyle(
    fontFamily: family,
    fontSize: 11,
    height: 1.25,
    fontWeight: FontWeight.w400,
  );

  /// Rótulo de seção e cabeçalho de coluna. Maiúsculas com tracking aberto —
  /// o recurso que mais rende "sofisticado" por linha de código.
  static const overline = TextStyle(
    fontFamily: family,
    fontSize: 10,
    height: 1.2,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.9,
  );

  /// A carga em destaque (resumo, cartão de métrica).
  static const numberLarge = TextStyle(
    fontFamily: family,
    fontSize: 27,
    height: 1.05,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.8,
    fontFeatures: _tabular,
  );

  static const numberMedium = TextStyle(
    fontFamily: family,
    fontSize: 19,
    height: 1.1,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.4,
    fontFeatures: _tabular,
  );

  /// Valor dentro da célula de carga ou repetição.
  static const numberCell = TextStyle(
    fontFamily: family,
    fontSize: 16,
    height: 1.15,
    fontWeight: FontWeight.w500,
    letterSpacing: -0.2,
    fontFeatures: _tabular,
  );

  static const numberSmall = TextStyle(
    fontFamily: family,
    fontSize: 13,
    height: 1.2,
    fontWeight: FontWeight.w500,
    fontFeatures: _tabular,
  );
}
