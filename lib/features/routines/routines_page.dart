import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/design/design.dart';
import '../../app/formatting.dart';
import '../../app/providers.dart';
import '../../data/repos/routine_repository.dart';
import 'widgets/week_summary_card.dart';

class RoutinesPage extends ConsumerWidget {
  const RoutinesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaries = ref.watch(routineSummariesProvider);
    final active = ref.watch(activeSessionProvider);

    return AppScaffold(
      // A marca ocupa o lugar do título: a barra de abas já diz "Treinos", e
      // repetir a palavra desperdiçaria o único ponto alto da tela.
      largeTitleContent: const WeightyLockup(
        markSize: 26,
        style: AppText.largeTitle,
      ),
      actions: [
        AppNavIcon(
          icon: LucideIcons.plus,
          label: 'Novo treino',
          onTap: () => _createRoutine(context, ref),
        ),
      ],
      // A sessão aberta é a única coisa que pode estar pela metade, então fica
      // acima de tudo.
      banner: active.maybeWhen(
        data: (session) => session == null
            ? null
            : _ResumeBanner(
                name: session.routineName,
                onResume: () => context.push('/treino/${session.id}'),
              ),
        orElse: () => null,
      ),
      body: summaries.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => EmptyState(
          title: 'Não deu para carregar',
          message: '$e',
          icon: LucideIcons.circleAlert,
        ),
        data: (list) {
          if (list.isEmpty) {
            return Column(
              children: [
                const Expanded(
                  child: EmptyState(
                    title: 'Monte seu primeiro treino',
                    message:
                        'Crie um treino como "Upper 1", escolha os exercícios '
                        'e as séries. Depois é só começar e registrar as '
                        'cargas.',
                    icon: LucideIcons.dumbbell,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.xl,
                    0,
                    Space.xl,
                    Space.xxl,
                  ),
                  child: Center(
                    child: AppButton(
                      label: 'Criar treino',
                      icon: LucideIcons.plus,
                      onPressed: () => _createRoutine(context, ref),
                    ),
                  ),
                ),
              ],
            );
          }

          final week = ref.watch(weekSummaryProvider).valueOrNull;

          return ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.xl,
              Space.xs,
              Space.xl,
              Space.xxxl,
            ),
            children: [
              if (week != null && !week.isEmpty) ...[
                StaggeredEntry(index: 0, child: WeekSummaryCard(summary: week)),
                const SizedBox(height: Space.xxl),
              ],
              for (var i = 0; i < list.length; i++)
                StaggeredEntry(
                  index: i + 1,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: Space.lg),
                    child: _RoutineCard(summary: list[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Card do treino. Ganhou peso em relação à linha de lista: os treinos são a
/// entrada principal do app e merecem ser o elemento mais presente da tela.
class _RoutineCard extends ConsumerWidget {
  const _RoutineCard({required this.summary});

  final RoutineSummary summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final last = summary.lastPerformedAt;
    final empty = summary.exerciseCount == 0;

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.hairline, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          _Pressable(
            onTap: () => context.push('/treino/${summary.routine.id}/editar'),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.xl,
                Space.xl,
                Space.lg,
                Space.lg,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          summary.routine.name,
                          style: AppText.title1.copyWith(color: c.textPrimary),
                        ),
                        const SizedBox(height: Space.xs),
                        Text(
                          empty
                              ? 'sem exercícios'
                              : '${summary.exerciseCount} '
                                    '${summary.exerciseCount == 1 ? 'exercício' : 'exercícios'}'
                                    ' · ${summary.setCount} '
                                    '${summary.setCount == 1 ? 'série' : 'séries'}',
                          style: AppText.footnote.copyWith(
                            color: c.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (summary.muscleGroups.isNotEmpty)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // No máximo quatro pontos: mais que isso deixa de ser
                        // leitura rápida e vira ruído.
                        for (final g in summary.muscleGroups.take(4))
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: MuscleDot(g, size: 8),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
          Container(height: 0.5, color: c.hairline),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.lg,
              Space.md,
              Space.lg,
              Space.md,
            ),
            child: Row(
              children: [
                Icon(LucideIcons.clock3, size: 13, color: c.textTertiary),
                const SizedBox(width: Space.sm),
                Expanded(
                  child: Text(
                    last == null ? 'nunca feito' : formatRelativeDate(last),
                    style: AppText.footnote.copyWith(color: c.textTertiary),
                  ),
                ),
                AppButton(
                  label: 'Iniciar',
                  icon: LucideIcons.play,
                  compact: true,
                  onPressed: empty
                      ? null
                      : () {
                          Haptics.tick();
                          _startSession(context, ref, summary.routine.id);
                        },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> _createRoutine(BuildContext context, WidgetRef ref) async {
  final name = await promptForName(context, title: 'Novo treino');
  if (name == null || name.isEmpty) return;

  final id = await ref.read(routineRepositoryProvider).createRoutine(name);
  ref.invalidate(routineSummariesProvider);
  if (context.mounted) context.push('/treino/$id/editar');
}

Future<void> _startSession(
  BuildContext context,
  WidgetRef ref,
  int routineId,
) async {
  final repo = ref.read(sessionRepositoryProvider);

  // Duas sessões abertas ao mesmo tempo bagunçariam a referência de "última
  // vez", então a anterior tem que ser resolvida antes.
  final existing = await repo.activeSession();
  if (existing != null && context.mounted) {
    final action = await showAppDialog<String>(
      context,
      title: 'Treino em andamento',
      message: '"${existing.routineName}" foi iniciado e não foi finalizado.',
      actions: const [
        AppDialogAction(label: 'Cancelar', value: 'cancel'),
        AppDialogAction(
          label: 'Descartar e começar',
          value: 'discard',
          isDestructive: true,
        ),
        AppDialogAction(label: 'Retomar', value: 'resume', isPreferred: true),
      ],
    );

    if (action == null || action == 'cancel') return;
    if (action == 'resume') {
      if (context.mounted) context.push('/treino/${existing.id}');
      return;
    }
    await repo.delete(existing.id);
  }

  final sessionId = await repo.startFromRoutine(routineId);
  ref.invalidate(activeSessionProvider);
  if (context.mounted) context.push('/treino/$sessionId');
}

class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        color: _down ? context.colors.hairline : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}

class _ResumeBanner extends StatelessWidget {
  const _ResumeBanner({required this.name, required this.onResume});

  final String name;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, 0, Space.xl, Space.lg),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onResume,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.lg,
          ),
          decoration: BoxDecoration(
            color: c.accentSubtle,
            borderRadius: BorderRadius.circular(Radii.md),
            border: Border.all(
              color: c.accent.withValues(alpha: 0.35),
              width: 0.5,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: c.accent,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'EM ANDAMENTO',
                      style: AppText.overline.copyWith(color: c.accent),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      name,
                      style: AppText.bodyStrong.copyWith(color: c.textPrimary),
                    ),
                  ],
                ),
              ),
              Text(
                'Retomar',
                style: AppText.callout.copyWith(
                  color: c.accent,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Icon(LucideIcons.chevronRight, size: 16, color: c.accent),
            ],
          ),
        ),
      ),
    );
  }
}

/// Diálogo de nome, reaproveitado pelo editor para renomear.
Future<String?> promptForName(
  BuildContext context, {
  required String title,
  String? initial,
}) {
  return showAppSheet<String>(
    context,
    title: title,
    builder: (context) => _NameSheet(initial: initial),
  );
}

class _NameSheet extends StatefulWidget {
  const _NameSheet({this.initial});

  final String? initial;

  @override
  State<_NameSheet> createState() => _NameSheetState();
}

class _NameSheetState extends State<_NameSheet> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.pop(context, _controller.text.trim());

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        Space.xxl,
        Space.lg,
        Space.xxl,
        MediaQuery.viewInsetsOf(context).bottom + Space.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppTextField(
            controller: _controller,
            autofocus: true,
            hint: 'Upper 1',
            onSubmitted: (_) => _submit(),
          ),
          const SizedBox(height: Space.xl),
          Align(
            alignment: Alignment.centerRight,
            child: AppButton(label: 'Salvar', onPressed: _submit),
          ),
        ],
      ),
    );
  }
}
