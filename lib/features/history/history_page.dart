import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/design/design.dart';
import '../../app/formatting.dart';
import '../../app/providers.dart';
import '../../data/db/database.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(finishedSessionsProvider);

    return AppScaffold(
      largeTitle: 'Histórico',
      slivers: sessions.when(
        loading: () => const [],
        error: (e, _) => [
          AppSliverFill(
            child: EmptyState(title: 'Erro', message: '$e'),
          ),
        ],
        data: (list) {
          if (list.isEmpty) {
            return const [
              AppSliverFill(
                child: EmptyState(
                  title: 'Nenhum treino finalizado',
                  message:
                      'Depois da primeira sessão, o histórico e os gráficos de '
                      'evolução aparecem aqui.',
                  icon: LucideIcons.history,
                ),
              ),
            ];
          }

          // Agrupa por mês: rolar uma lista longa de datas soltas não dá noção
          // de tempo.
          final byMonth = <String, List<Session>>{};
          for (final session in list) {
            final key = DateFormat(
              "MMMM 'de' y",
              'pt_BR',
            ).format(session.finishedAt!);
            byMonth.putIfAbsent(key, () => []).add(session);
          }

          return [
            AppSliverList(
              children: [
                for (final entry in byMonth.entries) ...[
                  SectionLabel('${entry.key} · ${entry.value.length}'),
                  InsetGroup(
                    separatorIndent: AppRow.textInset(40),
                    children: [
                      for (final session in entry.value)
                        _SessionRow(session: session),
                    ],
                  ),
                ],
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.xs,
                    Space.lg,
                    Space.xs,
                    0,
                  ),
                  child: Text(
                    'Deslize uma sessão para a esquerda para excluí-la. Um treino '
                    'excluído deixa de contar na evolução.',
                    style: AppText.footnote.copyWith(
                      color: context.colors.textTertiary,
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );
  }
}

class _SessionRow extends ConsumerWidget {
  const _SessionRow({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final finished = session.finishedAt!;
    final duration = finished.difference(session.startedAt);

    return Dismissible(
      key: ValueKey(session.id),
      direction: DismissDirection.endToStart,
      background: Container(
        color: c.down.withValues(alpha: 0.16),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.xl),
        child: Icon(LucideIcons.trash2, size: 19, color: c.down),
      ),
      confirmDismiss: (_) => _confirmDelete(context, ref),
      child: AppRow(
        minHeight: 58,
        title: session.routineName,
        subtitle:
            '${formatRelativeDate(finished)} · ${formatDuration(duration)}',
        showChevron: true,
        onTap: () => context.push('/sessao/${session.id}?de=Histórico'),
        leading: Container(
          width: 40,
          height: 40,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: c.surfaceInput,
            shape: AppShapes.superellipse(Radii.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat('d').format(finished),
                style: AppText.numberSmall.copyWith(color: c.textPrimary),
              ),
              Text(
                DateFormat('MMM', 'pt_BR').format(finished).toLowerCase(),
                style: AppText.caption2.copyWith(
                  color: c.textSecondary,
                  fontSize: 10,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await confirmSessionDelete(context, session.routineName);
    if (confirmed != true || !context.mounted) return false;

    await deleteSession(context, ref, session.id);
    return true;
  }
}

/// Confirmação compartilhada entre a lista e o resumo.
Future<bool?> confirmSessionDelete(BuildContext context, String name) {
  return showAppDialog<bool>(
    context,
    title: 'Excluir esta sessão?',
    message:
        'O registro de "$name" será apagado. Ele sai dos gráficos e deixa de '
        'servir de referência para o próximo treino. Não dá para desfazer.',
    actions: const [
      AppDialogAction(label: 'Cancelar', value: false),
      AppDialogAction(
        label: 'Excluir',
        value: true,
        isDestructive: true,
        isPreferred: true,
      ),
    ],
  );
}

/// Apaga a sessão e invalida tudo que dependia dela.
Future<void> deleteSession(
  BuildContext context,
  WidgetRef ref,
  int sessionId,
) async {
  // A linha desaparece assim que o banco reemite a lista, então o contexto
  // dela já está morto quando chega a hora de avisar — e o aviso não aparecia.
  final toast = AppToast.capture(context);

  await ref.read(sessionRepositoryProvider).delete(sessionId);

  ref.invalidate(routineSummariesProvider);
  ref.invalidate(activeSessionProvider);
  // O resumo da semana é calculado uma vez e guardado; sem isto, o treino
  // excluído continuava contando em "esta semana" até reabrir o app — que é
  // justamente o que a exclusão existe para desfazer.
  ref.invalidate(weekSummaryProvider);
  // Famílias inteiras: qualquer exercício pode ter sido afetado, e o gráfico
  // precisa recalcular sem essa sessão.
  ref.invalidate(exerciseHistoryProvider);
  ref.invalidate(sessionSummaryProvider);
  ref.invalidate(lastPerformanceProvider);
  // Apagar uma sessão pode desfazer o recorde de outra: aquela carga inflada
  // deixa de ser a marca a bater.
  ref.invalidate(sessionShareProvider);

  toast.show('Sessão excluída.', kind: ToastKind.success);
}
