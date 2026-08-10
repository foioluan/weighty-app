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

    return Container(
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        // Gradiente sutil: dá profundidade sem virar um bloco colorido.
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.isDark
              ? [const Color(0xFF191D22), const Color(0xFF111418)]
              : [Colors.white, const Color(0xFFF7F8FA)],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.hairline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'ESTA SEMANA',
                  style: AppText.overline.copyWith(color: c.textTertiary),
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
                      size: 13,
                      color: delta >= 0 ? c.up : c.down,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${delta >= 0 ? '+' : ''}${(delta * 100).round()}%',
                      style: AppText.caption.copyWith(
                        color: delta >= 0 ? c.up : c.down,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
            ],
          ),
          const SizedBox(height: Space.lg),
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
                          style: AppText.caption.copyWith(
                            color: c.textTertiary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'volume levantado',
                    style: AppText.caption.copyWith(color: c.textTertiary),
                  ),
                ],
              ),
              const SizedBox(width: Space.xl),
              Expanded(
                child: SizedBox(
                  height: 38,
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
                      height: 3,
                      margin: EdgeInsets.only(
                        right: i == summary.plannedRoutines - 1 ? 0 : 4,
                      ),
                      decoration: BoxDecoration(
                        color: i < summary.sessions
                            ? c.accent
                            : c.hairlineStrong,
                        borderRadius: BorderRadius.circular(2),
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
              style: AppText.caption.copyWith(color: c.textTertiary),
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
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final max = values.reduce((a, b) => a > b ? a : b);
    if (max == 0) return;

    final dx = size.width / (values.length - 1);
    // Reserva 4 px em cima e embaixo para o ponto final não ser cortado.
    double y(double v) => size.height - 4 - (v / max) * (size.height - 8);

    final path = Path()..moveTo(0, y(values.first));
    for (var i = 1; i < values.length; i++) {
      path.lineTo(dx * i, y(values[i]));
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
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    canvas.drawCircle(
      Offset(size.width, y(values.last)),
      2.8,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.values != values || old.color != color;
}
