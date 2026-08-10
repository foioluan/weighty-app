import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/design/design.dart';
import '../../app/formatting.dart';
import '../../app/providers.dart';
import 'history_page.dart' show confirmSessionDelete, deleteSession;
import '../../data/repos/progress_repository.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/performance.dart';

/// Resumo de uma sessão. Serve tanto para o pós-treino quanto para abrir uma
/// sessão antiga a partir do histórico.
class SessionSummaryPage extends ConsumerWidget {
  const SessionSummaryPage({
    super.key,
    required this.sessionId,
    this.backLabel = 'Histórico',
  });

  final int sessionId;
  final String backLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summary = ref.watch(sessionSummaryProvider(sessionId));
    final session = summary.valueOrNull?.session;

    return AppScaffold(
      // O nome do treino é o título da tela, não uma repetição no corpo: era
      // "Resumo" na barra e "Upper 1" logo abaixo, dizendo a mesma coisa duas
      // vezes em dois tamanhos.
      largeTitle: session?.routineName ?? 'Resumo',
      subtitle: session == null
          ? null
          : session.finishedAt == null
          ? 'em andamento'
          : '${formatRelativeDate(session.finishedAt!)}'
                ' · ${formatDuration(session.finishedAt!.difference(session.startedAt))}',
      backLabel: backLabel,
      actions: [
        // Só sessões finalizadas: a em andamento se descarta pela tela de
        // treino, não pelo resumo.
        if (session?.finishedAt != null) ...[
          AppNavIcon(
            icon: LucideIcons.imageDown,
            label: 'Imagem do treino',
            onTap: () => context.push('/sessao/$sessionId/imagem?de=Resumo'),
          ),
          AppNavIcon(
            icon: LucideIcons.trash2,
            label: 'Excluir sessão',
            onTap: () => _delete(context, ref, session!.routineName),
          ),
        ],
      ],
      body: summary.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => EmptyState(title: 'Erro', message: '$e'),
        data: (data) => data == null
            ? const EmptyState(
                title: 'Sessão não encontrada',
                message: 'Ela pode ter sido descartada.',
              )
            : _SummaryBody(summary: data),
      ),
      bottomBar: Center(
        child: AppButton(label: 'Concluir', onPressed: () => context.go('/')),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, String name) async {
    final confirmed = await confirmSessionDelete(context, name);
    if (confirmed != true || !context.mounted) return;

    await deleteSession(context, ref, sessionId);
    if (context.mounted) context.go('/historico');
  }
}

class _SummaryBody extends StatelessWidget {
  const _SummaryBody({required this.summary});

  final SessionSummary summary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final improved = summary.improvedCount;

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.xl,
        Space.md,
        Space.xl,
        Space.xxxl,
      ),
      children: [
        if (improved > 0) ...[
          Row(
            children: [
              Icon(LucideIcons.trendingUp, size: 15, color: c.up),
              const SizedBox(width: Space.xs),
              Text(
                improved == 1
                    ? '1 exercício evoluiu'
                    : '$improved exercícios evoluíram',
                style: AppText.bodyStrong.copyWith(color: c.up),
              ),
            ],
          ),
          const SizedBox(height: Space.xxl),
        ],
        Row(
          children: [
            Expanded(
              child: StatTile(
                label: 'volume',
                value: formatVolume(summary.totalVolumeKg),
                unit: 'kg',
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: StatTile(label: 'séries', value: '${summary.totalSets}'),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: StatTile(
                label: 'duração',
                value: summary.duration == null
                    ? '—'
                    : formatDuration(summary.duration!),
              ),
            ),
          ],
        ),
        if (summary.exercises.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: Space.xxxl),
            child: EmptyState(
              title: 'Nenhuma série concluída',
              message:
                  'Séries sem marcar como concluídas não entram no histórico.',
            ),
          )
        else ...[
          const SectionLabel('Por exercício'),
          InsetGroup(
            children: [
              for (final exercise in summary.exercises)
                _ExerciseSummaryRow(summary: exercise),
            ],
          ),
        ],
      ],
    );
  }
}

class _ExerciseSummaryRow extends StatelessWidget {
  const _ExerciseSummaryRow({required this.summary});

  final ExerciseSummary summary;

  @override
  Widget build(BuildContext context) {
    final delta = summary.loadDeltaKg;

    return AppRow(
      minHeight: 60,
      title: summary.exercise.name,
      subtitle: setsLine(summary.sets),
      leading: ExerciseAvatar(
        name: summary.exercise.name,
        group: summary.exercise.muscleGroup,
      ),
      showChevron: true,
      onTap: () => context.push('/exercicio/${summary.exercise.id}?de=Resumo'),
      trailing: VerdictBadge(
        verdict: summary.verdict,
        detail: delta == null || delta == 0 ? null : '${formatDelta(delta)} kg',
      ),
    );
  }
}

/// "70 × 9 · 67,5 × 8" — a leitura rápida do que foi feito.
///
/// Cada tipo tem sua notação, porque a seta significa carga caindo: usá-la no
/// cluster (onde a carga é a mesma) diria a coisa errada.
String setsLine(List<PerformedSet> sets) {
  final parts = <String>[];

  for (final set in sets) {
    if (!set.type.countsForProgress || !set.hasData) continue;
    final segments = set.filledSegments.toList();

    parts.add(switch (set.type) {
      // Drop: carga decrescente, uma seta entre as quedas.
      SetType.drop =>
        segments
            .map((s) => '${formatWeight(s.weightKg)}×${s.reps}')
            .join(' → '),
      // Cluster: carga única, repetições somadas em blocos.
      SetType.cluster =>
        '${formatWeight(segments.first.weightKg)} × '
            '(${segments.map((s) => s.reps).join('+')})',
      _ => '${formatWeight(segments.first.weightKg)} × ${segments.first.reps}',
    });
  }

  return parts.isEmpty ? 'sem séries de trabalho' : parts.join(' · ');
}
