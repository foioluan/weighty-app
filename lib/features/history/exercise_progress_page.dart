import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/design/design.dart';
import '../../app/formatting.dart';
import '../../app/providers.dart';
import '../../data/repos/progress_repository.dart';
import 'session_summary_page.dart' show setsLine;

class ExerciseProgressPage extends ConsumerWidget {
  const ExerciseProgressPage({
    super.key,
    required this.exerciseId,
    this.backLabel = 'Exercícios',
  });

  final int exerciseId;
  final String backLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exercise = ref.watch(exerciseByIdProvider(exerciseId));
    final history = ref.watch(exerciseHistoryProvider(exerciseId));

    return AppScaffold(
      largeTitle: exercise.valueOrNull?.name ?? 'Progressão',
      subtitle: exercise.valueOrNull?.muscleGroup.label,
      backLabel: backLabel,
      slivers: [
        history.when(
          loading: () => const SliverToBoxAdapter(),
          error: (e, _) => AppSliverFill(
            child: EmptyState(title: 'Erro', message: '$e'),
          ),
          data: (points) => points.isEmpty
              ? const AppSliverFill(
                  child: EmptyState(
                    title: 'Sem histórico',
                    message:
                        'Este exercício ainda não foi registrado em nenhuma '
                        'sessão finalizada.',
                    icon: LucideIcons.chartLine,
                  ),
                )
              : _ProgressBody(points: points),
        ),
      ],
    );
  }
}

class _ProgressBody extends ConsumerWidget {
  const _ProgressBody({required this.points});

  final List<ProgressPoint> points;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final kind = ref.watch(progressMetricProvider);

    final latest = points.last;
    final previous = points.length > 1 ? points[points.length - 2] : null;

    final loadDelta = _delta(
      latest.metrics.topLoadKg,
      previous?.metrics.topLoadKg,
    );
    final volumeDelta = _delta(
      latest.metrics.volumeKg,
      previous?.metrics.volumeKg,
    );

    return AppSliverList(
      padding: const EdgeInsets.fromLTRB(Space.page, Space.xxl, Space.page, 0),
      children: [
        Text(
          points.length == 1
              ? '1 sessão registrada'
              : '${points.length} sessões registradas',
          style: AppText.callout.copyWith(color: c.textTertiary),
        ),
        const SizedBox(height: Space.lg),
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'carga máxima',
                value: latest.metrics.topLoadKg == null
                    ? '—'
                    : formatWeight(latest.metrics.topLoadKg!),
                unit: 'kg',
                footnote: loadDelta?.$1 ?? 'sem referência',
                footnoteColor: _tone(context, loadDelta?.$2),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: StatTile(
                label: 'volume',
                value: formatVolume(latest.metrics.volumeKg),
                unit: 'kg',
                footnote: volumeDelta?.$1 ?? 'sem referência',
                footnoteColor: _tone(context, volumeDelta?.$2),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: StatTile(
                label: '1RM est.',
                value: latest.metrics.estimatedOneRmKg == null
                    ? '—'
                    : formatWeight(latest.metrics.estimatedOneRmKg!),
                unit: 'kg',
                footnote: 'Epley',
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xxl),
        AppSegmented<ProgressMetricKind>(
          segments: {for (final k in ProgressMetricKind.values) k: k.label},
          selected: kind,
          onChanged: (v) => ref.read(progressMetricProvider.notifier).state = v,
        ),
        const SizedBox(height: Space.xl),
        Container(
          height: 190,
          padding: const EdgeInsets.fromLTRB(
            Space.xl,
            Space.xl,
            Space.sm,
            Space.md,
          ),
          decoration: AppShapes.surface(c.surface),
          child: _Chart(points: points, kind: kind),
        ),
        const SectionLabel('Sessões'),
        InsetGroup(
          children: [
            for (final point in points.reversed)
              AppRow(
                minHeight: 56,
                title: setsLine(point.sets),
                subtitle: point.metrics.estimatedOneRmKg == null
                    ? formatShortDate(point.date)
                    : '${formatShortDate(point.date)} · 1RM ~'
                          '${formatWeight(point.metrics.estimatedOneRmKg!)} kg',
                trailing: Text(
                  point.metrics.topLoadKg == null
                      ? '—'
                      : '${formatWeight(point.metrics.topLoadKg!)} kg',
                  style: AppText.numberSmall.copyWith(color: c.textSecondary),
                ),
              ),
          ],
        ),
      ],
    );
  }

  /// Texto do delta e se subiu, para escolher a cor sem repetir a conta.
  (String, bool?)? _delta(double? current, double? previous) {
    if (current == null || previous == null) return null;
    final diff = current - previous;
    if (diff == 0) return ('igual à anterior', null);
    return ('${formatDelta(diff)} vs anterior', diff > 0);
  }

  Color? _tone(BuildContext context, bool? improved) {
    if (improved == null) return null;
    return improved ? context.colors.up : context.colors.down;
  }
}

class _Chart extends StatelessWidget {
  const _Chart({required this.points, required this.kind});

  final List<ProgressPoint> points;
  final ProgressMetricKind kind;

  double? _valueOf(ProgressPoint point) => switch (kind) {
    ProgressMetricKind.carga => point.metrics.topLoadKg,
    ProgressMetricKind.volume => point.metrics.volumeKg,
    ProgressMetricKind.oneRm => point.metrics.estimatedOneRmKg,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final spots = <FlSpot>[];
    for (var i = 0; i < points.length; i++) {
      final value = _valueOf(points[i]);
      if (value != null) spots.add(FlSpot(i.toDouble(), value));
    }

    if (spots.isEmpty) {
      return Center(
        child: Text(
          kind == ProgressMetricKind.oneRm
              ? 'Sem séries de até 12 repetições para estimar o 1RM.'
              : 'Sem dados para esta métrica.',
          textAlign: TextAlign.center,
          style: AppText.footnote.copyWith(color: c.textTertiary),
        ),
      );
    }

    final values = spots.map((s) => s.y).toList()..sort();
    final min = values.first;
    final max = values.last;
    // Um respiro em cima e embaixo para a linha não encostar nas bordas; com
    // valor único o gráfico ficaria achatado sem esta margem mínima.
    final pad = (max - min) == 0 ? (max.abs() * 0.1 + 1) : (max - min) * 0.2;

    return LineChart(
      LineChartData(
        minY: min - pad,
        maxY: max + pad,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: (max - min) == 0 ? null : (max - min) / 2,
          // Linhas de grade tracejadas e fracas, só na horizontal — o gráfico
          // do Saúde: a grade orienta o olho sem disputar com a linha.
          getDrawingHorizontalLine: (_) => FlLine(
            color: c.hairlineStrong,
            strokeWidth: 0.5,
            dashArray: const [3, 4],
          ),
        ),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(),
          leftTitles: const AxisTitles(),
          // Valores à direita, como no Saúde: a leitura começa pela linha, e
          // o número fica ao lado do ponto mais recente.
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 44,
              // As bordas do intervalo (mínimo e máximo com respiro) não caem
              // na grade e saíam como um "59" solto colado no "60".
              getTitlesWidget: (value, meta) =>
                  value == meta.min || value == meta.max
                  ? const SizedBox.shrink()
                  : SideTitleWidget(
                      meta: meta,
                      child: Text(
                        formatWeight(value),
                        style: AppText.caption.copyWith(
                          color: c.textSecondary,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 24,
              interval: 1,
              getTitlesWidget: (value, meta) {
                final index = value.round();
                if (index < 0 || index >= points.length) {
                  return const SizedBox.shrink();
                }
                // Com muitas sessões, mostrar toda data vira borrão.
                final step = (points.length / 4).ceil();
                if (points.length > 5 && index % step != 0) {
                  return const SizedBox.shrink();
                }
                return SideTitleWidget(
                  meta: meta,
                  space: 6,
                  child: Text(
                    formatShortDate(points[index].date),
                    style: AppText.caption.copyWith(color: c.textSecondary),
                  ),
                );
              },
            ),
          ),
        ),
        lineTouchData: LineTouchData(
          // Ao tocar: régua vertical e o ponto realçado, com o valor num balão
          // acima — em vez de só o balão solto.
          getTouchedSpotIndicator: (bar, indexes) => [
            for (final _ in indexes)
              TouchedSpotIndicatorData(
                FlLine(color: c.textTertiary, strokeWidth: 1),
                FlDotData(
                  getDotPainter: (_, _, _, _) => FlDotCirclePainter(
                    radius: 5.5,
                    color: c.accent,
                    strokeWidth: 3,
                    strokeColor: c.surface,
                  ),
                ),
              ),
          ],
          touchTooltipData: LineTouchTooltipData(
            getTooltipColor: (_) => c.surfaceInput,
            tooltipBorderRadius: BorderRadius.circular(Radii.md),
            tooltipPadding: const EdgeInsets.symmetric(
              horizontal: Space.lg,
              vertical: Space.sm,
            ),
            fitInsideHorizontally: true,
            fitInsideVertically: true,
            getTooltipItems: (touched) => [
              for (final spot in touched)
                LineTooltipItem(
                  '${formatWeight(spot.y)} kg',
                  AppText.headline.copyWith(
                    color: c.textPrimary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  children: [
                    TextSpan(
                      text: '\n${formatShortDate(points[spot.x.round()].date)}',
                      style: AppText.footnote.copyWith(color: c.textSecondary),
                    ),
                  ],
                ),
            ],
          ),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            // Curva suave, sem passar dos pontos: o traço não pode sugerir
            // uma carga que ninguém levantou.
            isCurved: true,
            curveSmoothness: 0.3,
            preventCurveOverShooting: true,
            barWidth: 2.5,
            isStrokeCapRound: true,
            isStrokeJoinRound: true,
            color: c.accent,
            // Só o ponto mais recente é marcado, com anel na cor do cartão:
            // é a sessão que a tela existe para comparar.
            dotData: FlDotData(
              show: true,
              checkToShowDot: (spot, bar) => spot == bar.spots.last,
              getDotPainter: (spot, _, _, _) => FlDotCirclePainter(
                radius: 5,
                color: c.accent,
                strokeWidth: 3,
                strokeColor: c.surface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  c.accent.withValues(alpha: c.isDark ? 0.34 : 0.24),
                  c.accent.withValues(alpha: 0.0),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
