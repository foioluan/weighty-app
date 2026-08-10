import 'dart:math' as math;

import 'package:flutter/widgets.dart';

/// Uma fatia da rosca, já reduzida ao que o desenho precisa saber.
class DonutSlice {
  const DonutSlice({required this.color, required this.value});

  final Color color;
  final double value;
}

/// Como a fatia termina.
enum DonutCaps {
  /// Ponta arredondada. Bonita em fatias grandes, mas a compensação necessária
  /// para manter a proporção honesta come meio traço de cada lado — o que
  /// transforma fatias pequenas em pastilhas soltas.
  round,

  /// Corte reto. A fatia ocupa exatamente o ângulo que lhe cabe, então uma
  /// fatia de 3% continua sendo um arco de 3%.
  butt,
}

/// Rosca de proporções. Rosca e não pizza porque o buraco do meio aproveita o
/// espaço para o número que importa (o volume), e porque fatias pequenas ficam
/// mais legíveis num anel fino do que num setor apontando para o centro.
class MuscleDonut extends StatelessWidget {
  const MuscleDonut({
    super.key,
    required this.slices,
    required this.track,
    this.size = 148,
    this.stroke = 17,
    this.center,
    this.caps = DonutCaps.butt,
    this.gapDeg = 1.6,
  });

  final DonutCaps caps;

  /// Fresta entre fatias, em graus. Zero fecha o anel.
  final double gapDeg;

  final List<DonutSlice> slices;

  /// Anel de fundo. Aparece nas frestas entre as fatias e faz as divisões
  /// lerem como separação, não como falha no desenho.
  final Color track;

  final double size;
  final double stroke;

  /// O que vai no buraco. Fica por conta de quem chama: aqui só sobra o espaço.
  final Widget? center;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          slices: slices,
          stroke: stroke,
          track: track,
          caps: caps,
          gapDeg: gapDeg,
        ),
        child: center == null
            ? null
            : Center(
                // O conteúdo tem que caber no buraco, não por cima do anel.
                child: SizedBox(width: size - stroke * 2 - 14, child: center),
              ),
      ),
    );
  }
}

class _DonutPainter extends CustomPainter {
  const _DonutPainter({
    required this.slices,
    required this.stroke,
    required this.track,
    required this.caps,
    required this.gapDeg,
  });

  final List<DonutSlice> slices;
  final double stroke;
  final Color track;
  final DonutCaps caps;
  final double gapDeg;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (math.min(size.width, size.height) - stroke) / 2;
    if (radius <= 0) return;

    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..color = track,
    );

    final total = slices.fold<double>(0, (sum, s) => sum + s.value);
    if (total <= 0) return;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Uma ponta arredondada avança meio traço para fora do fim do arco. Sem
    // descontar isso, cada fatia apareceria maior do que é — e a soma passaria
    // de 100%. É esse desconto que estraga as fatias pequenas: em traço de
    // 18 px num raio de 65, ele come 16° de cada lado, e uma fatia de 9% (32°)
    // não tem 32° para dar.
    final capAngle = caps == DonutCaps.round ? (stroke / 2) / radius : 0.0;
    final inset = capAngle + gapDeg * math.pi / 360;

    var start = -math.pi / 2;
    for (final slice in slices) {
      final sweep = 2 * math.pi * (slice.value / total);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = caps == DonutCaps.round ? StrokeCap.round : StrokeCap.butt
        ..color = slice.color;

      if (sweep > 2 * inset + 0.004) {
        canvas.drawArc(rect, start + inset, sweep - 2 * inset, false, paint);
      } else if (caps == DonutCaps.round) {
        // Fatia curta demais para virar arco: vira um ponto no meio dela. Fica
        // um pouco maior do que mereceria, e é de propósito — um grupo que foi
        // treinado precisa aparecer, ainda que com 1% do volume.
        final mid = start + sweep / 2;
        canvas.drawCircle(
          center + Offset(math.cos(mid), math.sin(mid)) * radius,
          stroke * 0.42,
          Paint()..color = slice.color,
        );
      } else {
        // De ponta reta a fatia mínima ainda é um arco, só bem fino: some a
        // fresta em vez de trocar a forma do desenho.
        canvas.drawArc(rect, start, sweep, false, paint);
      }

      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter old) =>
      old.stroke != stroke ||
      old.track != track ||
      old.caps != caps ||
      old.gapDeg != gapDeg ||
      old.slices.length != slices.length ||
      Iterable<int>.generate(slices.length).any(
        (i) =>
            old.slices[i].value != slices[i].value ||
            old.slices[i].color != slices[i].color,
      );
}
