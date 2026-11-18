import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../app/design/design.dart';
import '../../../app/formatting.dart';
import '../../../data/repos/progress_repository.dart';

/// Resumo da semana no topo da home: volume levantado, variação contra a
/// semana anterior, minigráfico das últimas semanas e quantos treinos saíram.
///
/// Usa só dados que o app já registra — não é meta nem pontuação, é a leitura
/// do que aconteceu.
class WeekSummaryCard extends StatelessWidget {
  const WeekSummaryCard({super.key, required this.summary});

  final WeekSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final delta = summary.deltaRatio;

    // Sem degradê e sem borda: o cartão #1C1C1E contra o preto já tem a
    // profundidade que o degradê tentava simular.
    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        Space.xxl,
        Space.xl + 2,
        Space.xxl,
        Space.xxl,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Esta semana',
                  style: AppText.headline.copyWith(color: c.textPrimary),
                ),
              ),
              if (delta != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      delta >= 0
                          ? LucideIcons.trendingUp
                          : LucideIcons.trendingDown,
                      size: 16,
                      color: delta >= 0 ? c.up : c.down,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '${delta >= 0 ? '+' : ''}${(delta * 100).round()}%',
                      style: AppText.subheadline.copyWith(
                        color: delta >= 0 ? c.up : c.down,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: Space.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.baseline,
                    textBaseline: TextBaseline.alphabetic,
                    children: [
                      AnimatedNumber(
                        value: summary.volumeKg,
                        format: formatTonnage,
                        style: AppText.numberLarge.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(left: 3),
                        child: Text(
                          summary.volumeKg >= 1000 ? 't' : 'kg',
                          style: AppText.headline.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'volume levantado',
                    style: AppText.footnote.copyWith(color: c.textSecondary),
                  ),
                ],
              ),
              const SizedBox(width: Space.xl),
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: _Sparkline(points: summary.recentWeeks),
                ),
              ),
            ],
          ),
          if (summary.plannedRoutines > 0) ...[
            const SizedBox(height: Space.xl),
            Row(
              children: [
                for (var i = 0; i < summary.plannedRoutines; i++)
                  Expanded(
                    child: Container(
                      height: 6,
                      margin: EdgeInsets.only(
                        right: i == summary.plannedRoutines - 1 ? 0 : 4,
                      ),
                      decoration: ShapeDecoration(
                        color: i < summary.sessions ? c.accent : c.fill,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: Space.sm),
            Text(
              summary.sessions == 0
                  ? 'nenhum treino esta semana'
                  : '${summary.sessions} de ${summary.plannedRoutines} '
                        '${summary.plannedRoutines == 1 ? 'treino feito' : 'treinos feitos'}',
              style: AppText.footnote.copyWith(color: c.textSecondary),
            ),
          ],
        ],
      ),
    );
  }
}

/// Minigráfico de volume das últimas semanas, desenhado à mão — o fl_chart
/// traria eixos e toque que este espaço não comporta.
class _Sparkline extends StatelessWidget {
  const _Sparkline({required this.points});

  final List<WeekPoint> points;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    if (points.length < 2) return const SizedBox.shrink();

    return CustomPaint(
      painter: _SparklinePainter(
        values: points.map((p) => p.volumeKg).toList(),
        color: c.accent,
        ring: c.surface,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.color,
    required this.ring,
  });

  final List<double> values;
  final Color color;
  final Color ring;

  @override
  void paint(Canvas canvas, Size size) {
    final max = values.reduce((a, b) => a > b ? a : b);
    if (max == 0) return;

    final dx = size.width / (values.length - 1);
    // Reserva 4 px em cima e embaixo para o ponto final não ser cortado.
    double y(double v) => size.height - 4 - (v / max) * (size.height - 8);

    final points = [
      for (var i = 0; i < values.length; i++) Offset(dx * i, y(values[i])),
    ];
    // Curva suave entre os pontos, com as alças no meio do caminho — o traço
    // dos gráficos do Saúde. Reta a reta, o minigráfico parecia um eletro.
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      final mx = (a.dx + b.dx) / 2;
      path.cubicTo(mx, a.dy, mx, b.dy, b.dx, b.dy);
    }

    final fill = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    // Ponto final com anel na cor do cartão, para destacar "esta semana".
    final end = points.last;
    canvas.drawCircle(end, 5, Paint()..color = ring);
    canvas.drawCircle(end, 3.4, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color || old.ring != ring;
}
