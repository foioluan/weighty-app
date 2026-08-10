// material.dart e não widgets.dart: o card precisa do Material para o texto
// não sair com o sublinhado de "faltou Material" quando rasterizado isolado.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/design/brand.dart';
import '../../app/formatting.dart';
import '../../app/theme.dart';
import '../../data/repos/progress_repository.dart';
import 'widgets/muscle_donut.dart';

/// Tamanho lógico do card e a largura final em pixels. 4:5 — cabe o conteúdo
/// com folga sem virar uma tira comprida, e é a proporção que melhor aproveita
/// a tela em qualquer lugar onde a imagem for aberta depois.
const shareCardSize = Size(400, 500);
const shareCardPixelWidth = 1080.0;

/// Escala de captura que fecha em 1080 × 1350.
const shareCardPixelRatio = shareCardPixelWidth / 400;

/// Teto de linhas nas listas. Existe porque a instrução era não poluir: uma
/// lista que cresce sem limite é o jeito mais rápido de perder a leitura de
/// relance. O teto vale para a legenda e para os recordes, nunca para a rosca.
const _maxRecords = 3;
const _maxGroups = 5;

/// A imagem do treino. Não é uma tela: é um desenho de tamanho fixo que a tela
/// de imagem mostra reduzido e o botão de salvar rasteriza em 1080 × 1350.
///
/// A paleta é a do tema em que o app está no momento. Consequência aceita: o
/// mesmo treino gera imagens diferentes no claro e no escuro.
class SessionShareCard extends StatelessWidget {
  const SessionShareCard({super.key, required this.data});

  final SessionShareData data;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final summary = data.summary;
    final finished = summary.session.finishedAt ?? summary.session.startedAt;

    return MediaQuery.withNoTextScaling(
      // Sem isto, o tamanho da fonte do sistema entraria no arquivo salvo e o
      // mesmo treino geraria imagens com quebras de linha diferentes.
      //
      // O Material é o que torna o card autossuficiente: ele é rasterizado
      // isolado, e sem um Material acima o Flutter desenha todo texto com o
      // sublinhado amarelo de "faltou Material" — que iria para o arquivo.
      child: Material(
        type: MaterialType.transparency,
        child: Container(
          width: shareCardSize.width,
          height: shareCardSize.height,
          decoration: BoxDecoration(
            // No escuro o card clareia no topo; no claro ele escurece de leve, o
            // que dá a mesma sensação de luz vindo de cima nos dois temas.
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [c.surface, c.bg],
              stops: const [0, 0.72],
            ),
          ),
          child: Stack(
            children: [
              // Brilho bronze no topo: dá profundidade e amarra o card à marca.
              Positioned(
                top: -shareCardSize.width * 0.42,
                left: shareCardSize.width * 0.12,
                child: Container(
                  width: shareCardSize.width,
                  height: shareCardSize.width,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        c.accent.withValues(alpha: c.isDark ? 0.10 : 0.07),
                        c.accent.withValues(alpha: 0),
                      ],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(26, 24, 26, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _Header(finishedAt: finished, duration: summary.duration),
                    const SizedBox(height: Space.xxl),
                    Text(
                      summary.session.routineName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.largeTitle.copyWith(color: c.textPrimary),
                    ),
                    const SizedBox(height: Space.xs),
                    Text(
                      '${_plural(summary.exercises.length, 'exercício', 'exercícios')}'
                      ' · ${_plural(summary.totalSets, 'série', 'séries')}',
                      style: AppText.footnote.copyWith(color: c.textTertiary),
                    ),
                    const SizedBox(height: Space.xxl),
                    // Dois Spacers dividem a folga em partes iguais acima e
                    // abaixo do gráfico. Num treino sem recorde a sobra é grande,
                    // e sem isso ela viraria um vão morto no meio do card.
                    const Spacer(),
                    _VolumeRing(summary: summary),
                    if (data.records.isNotEmpty) ...[
                      const SizedBox(height: Space.xxl),
                      _Records(records: data.records),
                    ],
                    const Spacer(),
                    const SizedBox(height: Space.lg),
                    _Highlights(summary: summary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _plural(int count, String one, String many) =>
    '$count ${count == 1 ? one : many}';

class _Header extends StatelessWidget {
  const _Header({required this.finishedAt, required this.duration});

  final DateTime finishedAt;
  final Duration? duration;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // "5 ago 2026": o mês abreviado do pt_BR vem com ponto, que aqui só
    // atrapalha a leitura junto do ano.
    final date = DateFormat(
      'd MMM y',
      'pt_BR',
    ).format(finishedAt).replaceAll('.', '');

    return Row(
      children: [
        WeightyLockup(
          style: AppText.callout,
          color: c.textSecondary,
          markColor: c.accent,
        ),
        const Spacer(),
        Text(
          duration == null ? date : '$date · ${duration!.inMinutes} min',
          style: AppText.caption.copyWith(color: c.textTertiary),
        ),
      ],
    );
  }
}

/// A rosca com o volume no miolo, e a legenda ao lado em vez de embaixo — é o
/// que mantém o card respirando na altura que ele tem.
class _VolumeRing extends StatelessWidget {
  const _VolumeRing({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final all = summary.volumeByGroup;
    final listed = all.take(_maxGroups).toList();
    final hidden = all.skip(_maxGroups).toList();
    final total = summary.totalVolumeKg;

    return Row(
      children: [
        MuscleDonut(
          size: 140,
          stroke: 16,
          track: c.hairlineStrong,
          // A rosca mostra **todos** os grupos na cor deles. Só a legenda tem
          // teto: jogar oito grupos num "outros" cinza deixaria o gráfico
          // quase todo neutro, que é o oposto do que ele existe para mostrar.
          slices: [
            for (final slice in all)
              DonutSlice(
                color: c.forMuscleGroup(slice.group),
                value: slice.volumeKg,
              ),
          ],
          center: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                child: Text(
                  formatVolume(total),
                  style: AppText.numberLarge.copyWith(color: c.textPrimary),
                ),
              ),
              const SizedBox(height: 3),
              Text(
                'KG DE VOLUME',
                textAlign: TextAlign.center,
                style: AppText.overline.copyWith(
                  color: c.textTertiary,
                  fontSize: 8.5,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: Space.xxl),
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final slice in listed)
                Padding(
                  padding: const EdgeInsets.only(bottom: Space.md),
                  child: Row(
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          color: c.forMuscleGroup(slice.group),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: Space.md),
                      Expanded(
                        child: Text(
                          slice.group.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.footnote.copyWith(
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                      Text(
                        _percent(slice.volumeKg, total),
                        style: AppText.numberSmall.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              // O que não caber na legenda é resumido numa linha, com a fatia
              // que sobrou — assim as porcentagens continuam fechando em 100%.
              if (hidden.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 15),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '+ ${hidden.length} grupos',
                          style: AppText.footnote.copyWith(
                            color: c.textTertiary,
                          ),
                        ),
                      ),
                      Text(
                        _percent(
                          hidden.fold(0, (sum, s) => sum + s.volumeKg),
                          total,
                        ),
                        style: AppText.numberSmall.copyWith(
                          color: c.textTertiary,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

String _percent(double part, double total) =>
    total == 0 ? '—' : '${(part / total * 100).round()}%';

class _Records extends StatelessWidget {
  const _Records({required this.records});

  final List<LoadRecord> records;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final shown = records.take(_maxRecords).toList();
    final hidden = records.length - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              'RECORDES DE CARGA',
              style: AppText.overline.copyWith(color: Brand.bronze),
            ),
            const SizedBox(width: Space.md),
            Expanded(child: Container(height: 0.5, color: c.hairline)),
            // O que não caber vira uma contagem aqui, ao lado do rótulo, e não
            // uma linha própria embaixo: uma linha a mais no pior caso (três
            // recordes) empurraria o rodapé para fora do card.
            if (hidden > 0) ...[
              const SizedBox(width: Space.md),
              Text(
                '+ ${_plural(hidden, 'outro', 'outros')}',
                style: AppText.overline.copyWith(color: c.textTertiary),
              ),
            ],
          ],
        ),
        const SizedBox(height: Space.lg),
        for (final record in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: Space.sm),
            child: Row(
              children: [
                Icon(LucideIcons.arrowUp, size: 13, color: c.up),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    record.exercise.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.footnote.copyWith(color: c.textPrimary),
                  ),
                ),
                const SizedBox(width: Space.md),
                Text(
                  '${formatWeight(record.previousBestKg)} → '
                  '${formatWeight(record.loadKg)} kg',
                  style: AppText.numberSmall.copyWith(color: c.up),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Os dois indicadores extras, no rodapé: a série mais pesada do dia e quantos
/// exercícios evoluíram.
class _Highlights extends StatelessWidget {
  const _Highlights({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final heaviest = summary.heaviestSet;
    final comparable = summary.comparableCount;

    // IntrinsicHeight para as duas células fecharem na mesma altura: uma tem
    // legenda mais longa que a outra, e sem isto uma ficaria mais baixa.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Cell(
              label: 'SÉRIE MAIS PESADA',
              value: heaviest == null
                  ? '—'
                  : '${formatWeight(heaviest.loadKg)} kg × ${heaviest.reps}',
              detail: heaviest?.exercise.name,
            ),
          ),
          const SizedBox(width: Space.lg),
          Expanded(
            child: _Cell(
              label: 'EVOLUÍRAM',
              // Um exercício estreando não tinha como evoluir, então ele não
              // entra no denominador: "1 de 3" mentiria sobre o dia.
              value: comparable == 0
                  ? 'estreia'
                  : '${summary.improvedCount} de $comparable',
              detail: comparable == 0
                  ? 'primeira vez neles'
                  : 'acima da vez anterior',
              valueColor: summary.improvedCount > 0 ? c.up : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    required this.label,
    required this.value,
    this.detail,
    this.valueColor,
  });

  final String label;
  final String value;
  final String? detail;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.lg,
        Space.lg,
        Space.lg,
      ),
      decoration: BoxDecoration(
        color: c.textPrimary.withValues(alpha: 0.045),
        borderRadius: BorderRadius.circular(Radii.md),
        border: Border.all(color: c.hairline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.overline.copyWith(
              color: c.textTertiary,
              fontSize: 8.5,
            ),
          ),
          const SizedBox(height: Space.sm),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: AppText.numberMedium.copyWith(
                color: valueColor ?? c.textPrimary,
              ),
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 3),
            Text(
              detail!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.caption.copyWith(
                color: c.textTertiary,
                fontSize: 9.5,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
