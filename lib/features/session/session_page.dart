import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/design/design.dart';
import '../../app/formatting.dart';
import '../../app/providers.dart';
import '../../data/repos/session_repository.dart';
import '../../domain/metrics/progress_metrics.dart';
import '../../domain/models/enums.dart';
import '../../domain/models/performance.dart';

class SessionPage extends ConsumerStatefulWidget {
  const SessionPage({super.key, required this.sessionId});

  final int sessionId;

  @override
  ConsumerState<SessionPage> createState() => _SessionPageState();
}

class _SessionPageState extends ConsumerState<SessionPage> {
  final _pageController = PageController();
  Timer? _ticker;
  var _page = 0;
  var _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    // A tela fica ligada o treino inteiro: o celular passa a maior parte do
    // tempo no banco, sem toques.
    WakelockPlus.enable();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final started = ref
          .read(liveSessionProvider(widget.sessionId))
          .valueOrNull
          ?.session
          .startedAt;
      if (started != null && mounted) {
        setState(() => _elapsed = DateTime.now().difference(started));
      }
    });
  }

  @override
  void dispose() {
    WakelockPlus.disable();
    _ticker?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = ref.watch(liveSessionProvider(widget.sessionId));

    return session.when(
      loading: () => const AppScaffold(body: SizedBox.shrink()),
      error: (e, _) => AppScaffold(
        body: EmptyState(title: 'Erro', message: '$e'),
      ),
      data: (live) {
        if (live == null) {
          return const AppScaffold(
            body: EmptyState(
              title: 'Sessão não encontrada',
              message: 'Ela pode ter sido descartada.',
            ),
          );
        }

        final exercises = live.exercises;
        final current = exercises.isEmpty
            ? 0
            : _page.clamp(0, exercises.length - 1);

        return AppScaffold(
          title: live.session.routineName,
          actions: [
            GlassTextButton(label: 'Finalizar', onTap: () => _finish(live)),
          ],
          banner: exercises.isEmpty
              ? null
              : _SessionStrip(
                  exercises: exercises,
                  current: current,
                  elapsed: _elapsed,
                ),
          body: exercises.isEmpty
              ? const EmptyState(
                  title: 'Treino vazio',
                  message: 'Este treino não tem exercícios cadastrados.',
                )
              : PageView.builder(
                  controller: _pageController,
                  itemCount: exercises.length,
                  onPageChanged: (i) {
                    Haptics.tick();
                    setState(() => _page = i);
                  },
                  itemBuilder: (context, i) => _ExercisePanel(
                    sessionId: widget.sessionId,
                    exercise: exercises[i],
                  ),
                ),
          bottomBar: exercises.length < 2
              ? null
              : Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        label: 'Anterior',
                        icon: LucideIcons.chevronLeft,
                        style: AppButtonStyle.plain,
                        compact: true,
                        onPressed: current == 0
                            ? null
                            : () => _goTo(current - 1),
                      ),
                    ),
                    const SizedBox(width: Space.md),
                    Expanded(
                      child: AppButton(
                        label: 'Próximo',
                        style: AppButtonStyle.tinted,
                        compact: true,
                        onPressed: current == exercises.length - 1
                            ? null
                            : () => _goTo(current + 1),
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }

  void _goTo(int page) {
    _pageController.animateToPage(
      page,
      duration: AppDurations.base,
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _finish(LiveSession live) async {
    final pending = live.exercises
        .expand((e) => e.sets)
        .where((s) => !s.set.completed)
        .length;

    final confirmed = await showAppDialog<bool>(
      context,
      title: 'Finalizar treino?',
      message: pending == 0
          ? 'Todas as séries foram concluídas.'
          : 'Ainda há $pending ${pending == 1 ? 'série' : 'séries'} sem '
                'concluir. Elas não vão entrar no histórico.',
      actions: const [
        AppDialogAction(label: 'Voltar', value: false),
        AppDialogAction(label: 'Finalizar', value: true, isPreferred: true),
      ],
    );
    if (confirmed != true) return;

    Haptics.confirm();
    await ref.read(sessionRepositoryProvider).finish(widget.sessionId);
    ref.invalidate(activeSessionProvider);
    ref.invalidate(routineSummariesProvider);
    ref.invalidate(finishedSessionsProvider);
    ref.invalidate(weekSummaryProvider);
    ref.invalidate(exerciseHistoryProvider);
    // Vai direto para o resumo: é o momento em que a comparação com a semana
    // passada interessa mais.
    if (mounted) context.pushReplacement('/sessao/${widget.sessionId}');
  }
}

/// Faixa de contexto: onde você está no treino, quanto já concluiu e o tempo.
class _SessionStrip extends StatelessWidget {
  const _SessionStrip({
    required this.exercises,
    required this.current,
    required this.elapsed,
  });

  final List<LiveExercise> exercises;
  final int current;
  final Duration elapsed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final total = exercises.fold(0, (sum, e) => sum + e.sets.length);
    final done = exercises.fold(
      0,
      (sum, e) => sum + e.sets.where((s) => s.set.completed).length,
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(
        Space.xl,
        Space.md,
        Space.xl,
        Space.md,
      ),
      child: Row(
        children: [
          Text(
            '$done DE $total SÉRIES',
            style: AppText.overline.copyWith(color: c.textTertiary),
          ),
          const SizedBox(width: Space.lg),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: total == 0 ? 0 : done / total),
                duration: AppDurations.slow,
                curve: Curves.easeOutCubic,
                builder: (context, value, _) => LinearProgressIndicator(
                  value: value,
                  minHeight: 3,
                  backgroundColor: c.hairlineStrong,
                  valueColor: AlwaysStoppedAnimation(c.accent),
                ),
              ),
            ),
          ),
          const SizedBox(width: Space.lg),
          Text(
            formatDuration(elapsed),
            style: AppText.numberSmall.copyWith(color: c.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _ExercisePanel extends ConsumerWidget {
  const _ExercisePanel({required this.sessionId, required this.exercise});

  final int sessionId;
  final LiveExercise exercise;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final last = ref.watch(
      lastPerformanceProvider((
        exerciseId: exercise.exercise.id,
        sessionId: sessionId,
      )),
    );
    final lastSets = last.valueOrNull ?? const <PerformedSet>[];

    // A primeira série sem concluir é a "de agora": ela recebe o card em foco.
    // As demais viram linha compacta — concluídas com o delta, futuras apagadas.
    final activeIndex = exercise.sets.indexWhere((s) => !s.set.completed);

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        Space.xl,
        Space.lg,
        Space.xl,
        Space.xxxl,
      ),
      children: [
        Row(
          children: [
            ExerciseAvatar(
              name: exercise.exercise.name,
              group: exercise.exercise.muscleGroup,
              size: 40,
            ),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    exercise.exercise.name,
                    style: AppText.title2.copyWith(color: c.textPrimary),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    _planLine(exercise, lastSets.isEmpty),
                    style: AppText.footnote.copyWith(color: c.textTertiary),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: Space.xl),
        for (var i = 0; i < exercise.sets.length; i++)
          _SetSlot(
            sessionId: sessionId,
            liveSet: exercise.sets[i],
            number: _workingNumber(exercise.sets, i),
            previous: _previousFor(lastSets, exercise.sets[i].set.position),
            isActive: i == activeIndex,
          ),
        const SizedBox(height: Space.md),
        Center(
          child: AppButton(
            label: 'Série extra',
            icon: LucideIcons.plus,
            style: AppButtonStyle.plain,
            compact: true,
            onPressed: () {
              Haptics.tick();
              ref.read(sessionRepositoryProvider).addExtraSet(exercise.link.id);
            },
          ),
        ),
      ],
    );
  }

  /// Resumo do planejado. Fica no subtítulo em vez de dentro de cada célula —
  /// era o rótulo por célula que desalinhava a coluna de repetições.
  String _planLine(LiveExercise exercise, bool isFirstTime) {
    final targets = exercise.sets
        .where((s) => s.set.setType != SetType.aquecimento)
        .map((s) => s.plannedTargetReps)
        .whereType<int>()
        .toSet();

    final plan = switch (targets.length) {
      0 => '${exercise.sets.length} séries',
      1 => '${exercise.sets.length} séries · alvo ${targets.first} reps',
      _ => '${exercise.sets.length} séries · alvo variado',
    };

    return isFirstTime ? '$plan · primeira vez' : plan;
  }

  /// Aquecimento não entra na numeração das séries de trabalho.
  String _workingNumber(List<LiveSet> sets, int index) {
    if (sets[index].set.setType == SetType.aquecimento) return 'aq';
    var n = 0;
    for (var i = 0; i <= index; i++) {
      if (sets[i].set.setType != SetType.aquecimento) n++;
    }
    return '$n';
  }

  PerformedSet? _previousFor(List<PerformedSet> lastSets, int position) {
    for (final set in lastSets) {
      if (set.position == position) return set;
    }
    return null;
  }
}

/// Decide qual das três formas a série assume.
class _SetSlot extends ConsumerWidget {
  const _SetSlot({
    required this.sessionId,
    required this.liveSet,
    required this.number,
    required this.previous,
    required this.isActive,
  });

  final int sessionId;
  final LiveSet liveSet;
  final String number;
  final PerformedSet? previous;
  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (liveSet.set.completed) {
      return _CompactRow(
        number: number,
        liveSet: liveSet,
        previous: previous,
        completed: true,
        onTap: () => _setCompleted(ref, false),
      );
    }
    if (isActive) {
      return _FocusCard(
        number: number,
        liveSet: liveSet,
        previous: previous,
        onComplete: () => _complete(context, ref),
        onUpdate: (i, {weightKg, reps}) =>
            _updateSegment(ref, i, weightKg: weightKg, reps: reps),
        onStep: (delta) => _stepWeight(ref, delta),
      );
    }
    return _CompactRow(
      number: number,
      liveSet: liveSet,
      previous: previous,
      completed: false,
      onTap: null,
    );
  }

  Future<void> _updateSegment(
    WidgetRef ref,
    int index, {
    double? weightKg,
    int? reps,
  }) async {
    if (index >= liveSet.segments.length) return;
    await ref
        .read(sessionRepositoryProvider)
        .updateSegment(
          liveSet.segments[index].id,
          weightKg: weightKg,
          reps: reps,
        );
  }

  Future<void> _stepWeight(WidgetRef ref, double delta) async {
    if (liveSet.segments.isEmpty) return;
    final segment = liveSet.segments.first;

    // Partindo do zero, o passo sobe a partir da carga da última vez em vez de
    // começar em 2,5 kg — é quase sempre o que se quer.
    final base = segment.weightKg > 0
        ? segment.weightKg
        : (previous?.referenceLoadKg ?? 0);
    final next = (base + delta).clamp(0.0, 999.0);

    Haptics.tick();
    await ref
        .read(sessionRepositoryProvider)
        .updateSegment(segment.id, weightKg: next);
  }

  Future<void> _setCompleted(WidgetRef ref, bool value) async {
    Haptics.tick();
    await ref
        .read(sessionRepositoryProvider)
        .setCompleted(liveSet.set.id, value);
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(sessionRepositoryProvider);

    // Concluir sem digitar repete a última vez. O preenchimento é campo a
    // campo: subir só a carga no passo não pode deixar as reps zeradas.
    var filledReps = false;
    for (var i = 0; i < liveSet.segments.length; i++) {
      final segment = liveSet.segments[i];
      final source = previous?.segments;
      final reference =
          (source != null && i < source.length && source[i].isFilled)
          ? source[i]
          : null;

      final weight = segment.weightKg == 0 ? reference?.weightKg : null;
      final reps = segment.reps == 0 ? reference?.reps : null;

      if (weight != null || reps != null) {
        await repo.updateSegment(segment.id, weightKg: weight, reps: reps);
      }
      if (segment.reps > 0 || reps != null) filledReps = true;
    }

    // Série sem repetição nenhuma não é dado, é engano de digitação.
    if (!filledReps) {
      Haptics.warn();
      if (context.mounted) {
        AppToast.show(
          context,
          'Informe as repetições da série.',
          kind: ToastKind.error,
        );
      }
      return;
    }

    Haptics.confirm();
    await repo.setCompleted(liveSet.set.id, true);
  }
}

/// A série de agora. Recebe a carga em corpo grande, os passos ao lado e o
/// botão de concluir — é a única coisa da tela que exige ação.
class _FocusCard extends ConsumerWidget {
  const _FocusCard({
    required this.number,
    required this.liveSet,
    required this.previous,
    required this.onComplete,
    required this.onUpdate,
    required this.onStep,
  });

  final String number;
  final LiveSet liveSet;
  final PerformedSet? previous;
  final VoidCallback onComplete;
  final void Function(int index, {double? weightKg, int? reps}) onUpdate;
  final ValueChanged<double> onStep;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final type = liveSet.set.setType;
    final step = ref.watch(weightIncrementProvider);

    final target = liveSet.plannedTargetReps;
    final targetMax = liveSet.plannedTargetRepsMax;
    final reference = previous?.hasData == true
        ? 'última vez ${formatWeight(previous!.referenceLoadKg!)} × '
              '${previous!.totalReps}'
        : 'primeira vez neste exercício';

    return Container(
      margin: const EdgeInsets.only(bottom: Space.lg),
      padding: const EdgeInsets.all(Space.xl),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: c.isDark
              ? [const Color(0xFF1C2026), const Color(0xFF14171B)]
              : [Colors.white, const Color(0xFFFBF7EF)],
        ),
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.accent.withValues(alpha: 0.35), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  type == SetType.aquecimento
                      ? 'AQUECIMENTO · AGORA'
                      : '${type == SetType.normal ? 'SÉRIE' : type.label.toUpperCase()} $number · AGORA',
                  style: AppText.overline.copyWith(color: c.accent),
                ),
              ),
              Text(
                reference,
                style: AppText.caption.copyWith(color: c.textTertiary),
              ),
            ],
          ),
          const SizedBox(height: Space.lg),
          if (type.isMultiSegment) ...[
            for (var i = 0; i < liveSet.segments.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: Space.md),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        '${i + 1}ª',
                        style: AppText.caption.copyWith(color: c.textTertiary),
                      ),
                    ),
                    const SizedBox(width: Space.sm),
                    Expanded(
                      child: NumberCell(
                        value: liveSet.segments[i].weightKg,
                        hint: _hint(i, weight: true),
                        decimal: true,
                        emphasized: true,
                        onChanged: (v) => onUpdate(i, weightKg: v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Space.md),
                      child: Text(
                        '×',
                        style: AppText.footnote.copyWith(color: c.textTertiary),
                      ),
                    ),
                    Expanded(
                      child: NumberCell(
                        value: liveSet.segments[i].reps.toDouble(),
                        hint: _hint(i, weight: false),
                        onChanged: (v) => onUpdate(i, reps: v.round()),
                      ),
                    ),
                  ],
                ),
              ),
          ] else ...[
            Row(
              children: [
                _StepSquare(
                  icon: LucideIcons.minus,
                  onTap: () => onStep(-step),
                  label: 'Diminuir ${formatWeight(step)} kg',
                ),
                Expanded(
                  child: BigNumberField(
                    value: liveSet.segments.isEmpty
                        ? 0
                        : liveSet.segments.first.weightKg,
                    hint: _hint(0, weight: true),
                    onChanged: (v) => onUpdate(0, weightKg: v),
                  ),
                ),
                _StepSquare(
                  icon: LucideIcons.plus,
                  onTap: () => onStep(step),
                  label: 'Aumentar ${formatWeight(step)} kg',
                ),
              ],
            ),
            const SizedBox(height: Space.lg),
            Row(
              children: [
                SizedBox(
                  width: 78,
                  child: NumberCell(
                    value: liveSet.segments.isEmpty
                        ? 0
                        : liveSet.segments.first.reps.toDouble(),
                    hint: _hint(0, weight: false),
                    onChanged: (v) => onUpdate(0, reps: v.round()),
                  ),
                ),
                const SizedBox(width: Space.md),
                Text(switch ((target, targetMax)) {
                  (null, _) => 'reps',
                  (final a?, null) => 'reps · alvo $a',
                  (final a?, final b?) => 'reps · alvo $a-$b',
                }, style: AppText.caption.copyWith(color: c.textTertiary)),
                const Spacer(),
              ],
            ),
          ],
          const SizedBox(height: Space.xl),
          // A única ação do app que ocupa a largura inteira: é tocada com a
          // mão suada, entre séries, sem olhar a tela.
          AppButton(
            label: 'Concluir série',
            icon: LucideIcons.check,
            expand: true,
            onPressed: onComplete,
          ),
        ],
      ),
    );
  }

  String? _hint(int index, {required bool weight}) {
    final segments = previous?.segments;
    if (segments == null || index >= segments.length) return null;
    final segment = segments[index];
    if (!segment.isFilled) return null;
    return weight ? formatWeight(segment.weightKg) : '${segment.reps}';
  }
}

class _StepSquare extends StatelessWidget {
  const _StepSquare({
    required this.icon,
    required this.onTap,
    required this.label,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            color: c.surfaceInput,
            borderRadius: BorderRadius.circular(Radii.md),
          ),
          child: Center(child: Icon(icon, size: 19, color: c.textSecondary)),
        ),
      ),
    );
  }
}

/// Série concluída ou ainda por vir, em uma linha.
class _CompactRow extends StatelessWidget {
  const _CompactRow({
    required this.number,
    required this.liveSet,
    required this.previous,
    required this.completed,
    required this.onTap,
  });

  final String number;
  final LiveSet liveSet;
  final PerformedSet? previous;
  final bool completed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final type = liveSet.set.setType;

    final performed = PerformedSet(
      position: liveSet.set.position,
      type: type,
      segments: [
        for (final s in liveSet.segments)
          SegmentData(weightKg: s.weightKg, reps: s.reps),
      ],
    );

    // Concluída mostra o que foi feito; futura mostra a referência apagada.
    final source = completed ? performed : previous;
    final text = source == null || !source.hasData
        ? (type.isMultiSegment ? type.label.toLowerCase() : 'sem referência')
        : _describe(source, type);

    return Opacity(
      opacity: completed ? 1 : 0.45,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.sm,
            vertical: Space.md,
          ),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                child: Text(
                  number,
                  style: AppText.caption.copyWith(color: c.textGhost),
                ),
              ),
              const SizedBox(width: Space.sm),
              Icon(
                completed ? LucideIcons.circleCheck : LucideIcons.circle,
                size: 16,
                color: completed ? c.up : c.textGhost,
              ),
              const SizedBox(width: Space.lg),
              Expanded(
                child: Text(
                  text,
                  style: AppText.callout.copyWith(
                    color: completed ? c.textSecondary : c.textTertiary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (completed) _Delta(current: performed, previous: previous),
            ],
          ),
        ),
      ),
    );
  }

  String _describe(PerformedSet set, SetType type) {
    final segments = set.filledSegments.toList();
    return switch (type) {
      SetType.drop =>
        segments
            .map((s) => '${formatWeight(s.weightKg)}×${s.reps}')
            .join(' → '),
      SetType.cluster =>
        '${formatWeight(segments.first.weightKg)} kg × '
            '(${segments.map((s) => s.reps).join('+')})',
      _ =>
        '${formatWeight(segments.first.weightKg)} kg × '
            '${segments.first.reps}',
    };
  }
}

/// O delta da série, ao lado do que foi feito. É o motivo do app existir.
class _Delta extends StatelessWidget {
  const _Delta({required this.current, required this.previous});

  final PerformedSet current;
  final PerformedSet? previous;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final comparison = compareSet(current, previous);

    if (!comparison.hasReference) {
      return Text(
        'novo',
        style: AppText.caption.copyWith(color: c.textTertiary),
      );
    }

    final tone = switch (comparison.verdict) {
      Verdict.evoluiu => c.up,
      Verdict.reduziu => c.down,
      _ => c.flat,
    };

    final delta = comparison.deltaKg ?? 0;
    final label = delta != 0
        ? formatDelta(delta)
        : (comparison.deltaReps == 0
              ? '='
              : '${comparison.deltaReps! > 0 ? '+' : ''}${comparison.deltaReps} rep');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (comparison.verdict != Verdict.manteve)
          Icon(
            comparison.verdict == Verdict.evoluiu
                ? LucideIcons.arrowUp
                : LucideIcons.arrowDown,
            size: 12,
            color: tone,
          ),
        Text(
          label,
          style: AppText.caption.copyWith(
            color: tone,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
