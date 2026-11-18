import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../app/design/design.dart';
import '../../app/formatting.dart';
import '../../app/providers.dart';
import '../../data/db/database.dart' show SetSegment;
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
        final total = exercises.fold(0, (sum, e) => sum + e.sets.length);
        final done = exercises.fold(
          0,
          (sum, e) => sum + e.sets.where((s) => s.set.completed).length,
        );

        return AppScaffold(
          title: live.session.routineName,
          // O cronômetro e o progresso cabem embaixo do título: a faixa com
          // barra que ocupava uma linha inteira da tela saiu.
          subtitle: '${formatDuration(_elapsed)} · $done de $total séries',
          actions: [
            if (exercises.length > 1)
              AppNavIcon(
                icon: LucideIcons.listOrdered,
                label: 'Exercícios do treino',
                onTap: () => _openList(live),
              ),
            GlassTextButton(label: 'Finalizar', onTap: () => _finish(live)),
          ],
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
                    index: i,
                    count: exercises.length,
                    next: i + 1 < exercises.length ? exercises[i + 1] : null,
                    onNext: () => _goTo(i + 1),
                    onFinish: () => _finish(live),
                  ),
                ),
        );
      },
    );
  }

  /// Lista dos exercícios com o progresso de cada um, para pular direto.
  Future<void> _openList(LiveSession live) async {
    final c = context.colors;
    final chosen = await showAppSheet<int>(
      context,
      title: 'Exercícios',
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.xl,
          Space.md,
          Space.xl,
          Space.xl,
        ),
        child: SingleChildScrollView(
          child: InsetGroup(
            separatorIndent: AppRow.textInset(),
            children: [
              for (var i = 0; i < live.exercises.length; i++)
                Builder(
                  builder: (_) {
                    final e = live.exercises[i];
                    final doneSets = e.sets
                        .where((s) => s.set.completed)
                        .length;
                    final complete =
                        e.sets.isNotEmpty && doneSets == e.sets.length;
                    return AppRow(
                      title: e.exercise.name,
                      subtitle: '$doneSets de ${e.sets.length} séries',
                      titleColor: i == _page ? c.accent : null,
                      leading: ExerciseAvatar(
                        name: e.exercise.name,
                        group: e.exercise.muscleGroup,
                      ),
                      trailing: complete
                          ? Icon(LucideIcons.circleCheck, size: 20, color: c.up)
                          : null,
                      onTap: () => Navigator.pop(sheetContext, i),
                    );
                  },
                ),
            ],
          ),
        ),
      ),
    );
    if (chosen != null) _goTo(chosen);
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

/// Um exercício da sessão: as séries em pílulas, a série escolhida em
/// destaque e a ação na base.
///
/// Uma decisão por tela. A versão anterior empilhava a série de agora num
/// cartão e todas as outras em linhas apagadas abaixo dele; o olho tinha que
/// achar a série certa no meio da lista, e as futuras, a 45%, pareciam
/// desabilitadas.
class _ExercisePanel extends ConsumerStatefulWidget {
  const _ExercisePanel({
    required this.sessionId,
    required this.exercise,
    required this.index,
    required this.count,
    required this.next,
    required this.onNext,
    required this.onFinish,
  });

  final int sessionId;
  final LiveExercise exercise;
  final int index;
  final int count;
  final LiveExercise? next;
  final VoidCallback onNext;
  final VoidCallback onFinish;

  @override
  ConsumerState<_ExercisePanel> createState() => _ExercisePanelState();
}

class _ExercisePanelState extends ConsumerState<_ExercisePanel> {
  /// Série escolhida pelo toque numa pílula. Nulo segue a série de agora — a
  /// primeira não concluída —, que é o que acontece depois de concluir.
  int? _selected;

  /// Resultado da série que acabou de ser concluída, mostrado por um instante
  /// no topo do cartão.
  _Flash? _flash;
  Timer? _flashTimer;

  @override
  void dispose() {
    _flashTimer?.cancel();
    super.dispose();
  }

  List<LiveSet> get _sets => widget.exercise.sets;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final exercise = widget.exercise;
    final last = ref.watch(
      lastPerformanceProvider((
        exerciseId: exercise.exercise.id,
        sessionId: widget.sessionId,
      )),
    );
    final lastSets = last.valueOrNull ?? const <PerformedSet>[];

    final active = _sets.indexWhere((s) => !s.set.completed);
    final selected = (_selected != null && _selected! < _sets.length)
        ? _selected
        : null;
    final current = selected ?? (active >= 0 ? active : null);

    final liveSet = current == null ? null : _sets[current];
    final previous = liveSet == null
        ? null
        : _previousFor(lastSets, liveSet.set.position);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              Space.page,
              Space.sm,
              Space.page,
              Space.xl,
            ),
            children: [
              Text(
                'Exercício ${widget.index + 1} de ${widget.count} · '
                '${exercise.exercise.muscleGroup.label}',
                style: AppText.subheadline.copyWith(
                  color: c.textSecondary,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                exercise.exercise.name,
                style: AppText.title1.copyWith(color: c.textPrimary),
              ),
              const SizedBox(height: Space.lg),
              _SetPills(
                sets: _sets,
                current: current,
                onSelect: (i) {
                  Haptics.tick();
                  setState(() => _selected = i == active ? null : i);
                },
                onAdd: () {
                  Haptics.tick();
                  ref
                      .read(sessionRepositoryProvider)
                      .addExtraSet(exercise.link.id);
                },
              ),
              const SizedBox(height: Space.xl),
              if (liveSet != null)
                _SetHero(
                  sessionId: widget.sessionId,
                  liveSet: liveSet,
                  previous: previous,
                  title: _titleFor(current!),
                  flash: _flash,
                )
              else
                _ExerciseDone(sets: _sets, lastSets: lastSets, flash: _flash),
            ],
          ),
        ),
        _Footer(
          next: widget.next,
          onNext: widget.onNext,
          primary: _primaryAction(context, liveSet, previous, active),
        ),
      ],
    );
  }

  /// A ação cheia da base muda conforme o momento: concluir a série,
  /// desfazer uma já concluída, ou seguir adiante quando o exercício acabou.
  Widget _primaryAction(
    BuildContext context,
    LiveSet? liveSet,
    PerformedSet? previous,
    int active,
  ) {
    if (liveSet != null && liveSet.set.completed) {
      return AppButton(
        label: 'Desfazer conclusão',
        icon: LucideIcons.undo2,
        style: AppButtonStyle.tinted,
        expand: true,
        onPressed: () async {
          Haptics.tick();
          await ref
              .read(sessionRepositoryProvider)
              .setCompleted(liveSet.set.id, false);
          if (mounted) setState(() => _selected = null);
        },
      );
    }
    if (liveSet != null) {
      // A única ação cheia de largura total do app: é tocada com a mão
      // suada, entre séries, sem olhar a tela.
      return AppButton(
        label: 'Concluir série',
        icon: LucideIcons.check,
        expand: true,
        onPressed: () => _complete(context, liveSet, previous),
      );
    }
    final isLast = widget.next == null;
    return AppButton(
      label: isLast ? 'Finalizar treino' : 'Próximo exercício',
      icon: isLast ? LucideIcons.flag : LucideIcons.arrowRight,
      expand: true,
      onPressed: isLast ? widget.onFinish : widget.onNext,
    );
  }

  String _titleFor(int index) {
    final set = _sets[index].set;
    return switch (set.setType) {
      SetType.aquecimento => 'Aquecimento',
      SetType.drop => 'Drop set',
      SetType.cluster => 'Cluster set',
      SetType.normal =>
        'Série ${_workingNumber(_sets, index)} de '
            '${_sets.where((s) => s.set.setType != SetType.aquecimento).length}',
    };
  }

  Future<void> _complete(
    BuildContext context,
    LiveSet liveSet,
    PerformedSet? previous,
  ) async {
    final repo = ref.read(sessionRepositoryProvider);

    // Concluir sem digitar repete a última vez. O preenchimento é campo a
    // campo: subir só a carga no passo não pode deixar as reps zeradas.
    final filled = <SegmentData>[];
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
      filled.add(
        SegmentData(
          weightKg: weight ?? segment.weightKg,
          reps: reps ?? segment.reps,
        ),
      );
    }

    // Série sem repetição nenhuma não é dado, é engano de digitação.
    if (!filled.any((s) => s.isFilled)) {
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
    if (!mounted) return;

    final index = _sets.indexOf(liveSet);
    final performed = PerformedSet(
      position: liveSet.set.position,
      type: liveSet.set.setType,
      segments: filled,
    );
    _flashTimer?.cancel();
    setState(() {
      _selected = null;
      _flash = _Flash(
        label: liveSet.set.setType == SetType.normal
            ? 'Série ${_workingNumber(_sets, index)} concluída'
            : '${_titleFor(index)} concluído',
        comparison: compareSet(performed, previous),
      );
    });
    _flashTimer = Timer(const Duration(milliseconds: 2400), () {
      if (mounted) setState(() => _flash = null);
    });
  }
}

/// Resultado de uma série recém-concluída.
class _Flash {
  const _Flash({required this.label, required this.comparison});

  final String label;
  final SetComparison comparison;
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

/// "+2,5 kg", "+1 rep", "igual", ou nulo sem referência.
String? _describeDelta(SetComparison comparison) {
  if (!comparison.hasReference) return null;
  final kg = comparison.deltaKg ?? 0;
  if (kg != 0) return '${formatDelta(kg)} kg';
  final reps = comparison.deltaReps ?? 0;
  if (reps != 0) {
    final unit = reps.abs() == 1 ? 'rep' : 'reps';
    return '${reps > 0 ? '+' : '−'}${reps.abs()} $unit';
  }
  return 'igual';
}

/// As séries do exercício numa fileira: concluídas em verde, a escolhida
/// cheia, as demais neutras. Tocar escolhe; o "+" acrescenta uma série extra.
class _SetPills extends StatelessWidget {
  const _SetPills({
    required this.sets,
    required this.current,
    required this.onSelect,
    required this.onAdd,
  });

  final List<LiveSet> sets;
  final int? current;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Wrap(
      spacing: Space.sm,
      runSpacing: Space.sm,
      children: [
        for (var i = 0; i < sets.length; i++)
          Builder(
            builder: (context) {
              final type = sets[i].set.setType;
              final done = sets[i].set.completed;
              final selected = i == current;
              final label = switch (type) {
                SetType.aquecimento => 'aq',
                SetType.drop => 'D',
                SetType.cluster => 'C',
                SetType.normal => _workingNumber(sets, i),
              };

              final (bg, fg) = switch ((selected, done)) {
                (true, true) => (c.up, Colors.white),
                (true, false) => (c.accent, c.onAccent),
                (false, true) => (c.upSubtle, c.up),
                (false, false) => (c.fill, c.textSecondary),
              };

              return Semantics(
                button: true,
                selected: selected,
                label: done ? 'Série $label, concluída' : 'Série $label',
                excludeSemantics: true,
                child: PressScale(
                  onTap: () => onSelect(i),
                  scale: 0.9,
                  child: AnimatedContainer(
                    duration: AppDurations.base,
                    curve: Curves.easeOutCubic,
                    height: 40,
                    constraints: const BoxConstraints(minWidth: 48),
                    padding: const EdgeInsets.symmetric(horizontal: Space.lg),
                    decoration: ShapeDecoration(
                      color: bg,
                      shape: const StadiumBorder(),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (done) ...[
                          Icon(LucideIcons.check, size: 14, color: fg),
                          const SizedBox(width: 3),
                        ],
                        Text(
                          label,
                          style: AppText.subheadline.copyWith(
                            color: fg,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        Semantics(
          button: true,
          label: 'Série extra',
          excludeSemantics: true,
          child: PressScale(
            onTap: onAdd,
            scale: 0.9,
            child: Container(
              height: 40,
              width: 48,
              decoration: ShapeDecoration(
                color: c.accentSubtle,
                shape: const StadiumBorder(),
              ),
              child: Icon(LucideIcons.plus, size: 18, color: c.accent),
            ),
          ),
        ),
      ],
    );
  }
}

/// A série escolhida, em destaque: carga grande com − e +, repetições logo
/// abaixo, e a comparação com a última vez ao vivo.
class _SetHero extends ConsumerWidget {
  const _SetHero({
    required this.sessionId,
    required this.liveSet,
    required this.previous,
    required this.title,
    required this.flash,
  });

  final int sessionId;
  final LiveSet liveSet;
  final PerformedSet? previous;
  final String title;
  final _Flash? flash;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final type = liveSet.set.setType;
    final step = ref.watch(weightIncrementProvider);
    final done = liveSet.set.completed;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        Space.xxl,
        Space.xl,
        Space.xxl,
        Space.xxl,
      ),
      child: Column(
        children: [
          _FlashLine(flash: flash),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (done) ...[
                Icon(LucideIcons.circleCheck, size: 16, color: c.up),
                const SizedBox(width: Space.xs),
              ],
              Text(
                done ? '$title · concluída' : title,
                style: AppText.subheadline.copyWith(
                  color: done ? c.up : c.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          if (type.isMultiSegment)
            for (var i = 0; i < liveSet.segments.length; i++)
              Padding(
                padding: const EdgeInsets.only(top: Space.md),
                child: _SegmentRow(
                  index: i,
                  type: type,
                  segment: liveSet.segments[i],
                  previous: _segmentOf(previous, i),
                  onWeight: (v) => _update(ref, i, weightKg: v),
                  onReps: (v) => _update(ref, i, reps: v),
                ),
              )
          else ...[
            Row(
              children: [
                _RoundStep(
                  icon: LucideIcons.minus,
                  size: 58,
                  label: 'Diminuir ${formatWeight(step)} kg',
                  onTap: () => _stepWeight(ref, -step),
                ),
                Expanded(
                  child: _TapValue(
                    value: _first?.weightKg ?? 0,
                    ghost: _segmentOf(previous, 0)?.weightKg,
                    unit: 'kg',
                    style: AppText.numberLarge.copyWith(fontSize: 56),
                    semantics: 'Carga',
                    onTap: () => _pickWeight(context, ref, 0),
                  ),
                ),
                _RoundStep(
                  icon: LucideIcons.plus,
                  size: 58,
                  label: 'Aumentar ${formatWeight(step)} kg',
                  onTap: () => _stepWeight(ref, step),
                ),
              ],
            ),
            const SizedBox(height: Space.sm),
            _ReferenceLine(liveSet: liveSet, previous: previous),
            const SizedBox(height: Space.xl),
            Container(height: 0.5, color: c.hairline),
            const SizedBox(height: Space.xl),
            Row(
              children: [
                _RoundStep(
                  icon: LucideIcons.minus,
                  size: 46,
                  label: 'Diminuir uma repetição',
                  onTap: () => _stepReps(ref, -1),
                ),
                Expanded(
                  child: _TapValue(
                    value: (_first?.reps ?? 0).toDouble(),
                    ghost: _segmentOf(previous, 0)?.reps.toDouble(),
                    unit: 'reps',
                    style: AppText.numberLarge.copyWith(fontSize: 34),
                    semantics: 'Repetições',
                    onTap: () => _pickReps(context, ref, 0),
                  ),
                ),
                _RoundStep(
                  icon: LucideIcons.plus,
                  size: 46,
                  label: 'Aumentar uma repetição',
                  onTap: () => _stepReps(ref, 1),
                ),
              ],
            ),
            if (_target != null) ...[
              const SizedBox(height: Space.xs),
              Text(
                _target!,
                style: AppText.footnote.copyWith(color: c.textSecondary),
              ),
            ],
          ],
          if (type.isMultiSegment) ...[
            const SizedBox(height: Space.lg),
            _ReferenceLine(liveSet: liveSet, previous: previous),
          ],
        ],
      ),
    );
  }

  SetSegment? get _first =>
      liveSet.segments.isEmpty ? null : liveSet.segments.first;

  String? get _target =>
      switch ((liveSet.plannedTargetReps, liveSet.plannedTargetRepsMax)) {
        (null, _) => null,
        (final a?, null) => 'alvo $a',
        (final a?, final b?) => 'alvo $a–$b',
      };

  SegmentData? _segmentOf(PerformedSet? set, int index) {
    final segments = set?.segments;
    if (segments == null || index >= segments.length) return null;
    return segments[index].isFilled ? segments[index] : null;
  }

  Future<void> _update(
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
    final segment = _first;
    if (segment == null) return;

    // Partindo do zero, o passo sobe a partir da carga da última vez em vez de
    // começar em 2,5 kg — é quase sempre o que se quer.
    final base = segment.weightKg > 0
        ? segment.weightKg
        : (previous?.referenceLoadKg ?? 0);
    Haptics.tick();
    await _update(ref, 0, weightKg: (base + delta).clamp(0.0, 999.0));
  }

  Future<void> _stepReps(WidgetRef ref, int delta) async {
    final segment = _first;
    if (segment == null) return;
    final base = segment.reps > 0
        ? segment.reps
        : (_segmentOf(previous, 0)?.reps ?? liveSet.plannedTargetReps ?? 0);
    Haptics.tick();
    await _update(ref, 0, reps: (base + delta).clamp(0, 999));
  }

  Future<void> _pickWeight(BuildContext context, WidgetRef ref, int i) async {
    final value = await showNumberPad(
      context,
      title: 'Carga',
      initial: liveSet.segments[i].weightKg,
      decimal: true,
      unit: 'kg',
      lastValue: _segmentOf(previous, i)?.weightKg,
    );
    if (value != null) await _update(ref, i, weightKg: value);
  }

  Future<void> _pickReps(BuildContext context, WidgetRef ref, int i) async {
    final value = await showNumberPad(
      context,
      title: 'Repetições',
      initial: liveSet.segments[i].reps.toDouble(),
      unit: 'reps',
      lastValue: _segmentOf(previous, i)?.reps.toDouble(),
    );
    if (value != null) await _update(ref, i, reps: value.round());
  }
}

/// "última vez 75 × 7 · +2,5 kg". O delta é o que a série vai registrar se for
/// concluída agora — o que foi digitado, ou a última vez onde nada foi.
class _ReferenceLine extends StatelessWidget {
  const _ReferenceLine({required this.liveSet, required this.previous});

  final LiveSet liveSet;
  final PerformedSet? previous;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final style = AppText.footnote.copyWith(color: c.textSecondary);
    final prev = previous;

    if (prev == null || !prev.hasData) {
      return Text('primeira vez neste exercício', style: style);
    }

    final effective = PerformedSet(
      position: liveSet.set.position,
      type: liveSet.set.setType,
      segments: [
        for (var i = 0; i < liveSet.segments.length; i++)
          SegmentData(
            weightKg: liveSet.segments[i].weightKg > 0
                ? liveSet.segments[i].weightKg
                : (i < prev.segments.length ? prev.segments[i].weightKg : 0),
            reps: liveSet.segments[i].reps > 0
                ? liveSet.segments[i].reps
                : (i < prev.segments.length ? prev.segments[i].reps : 0),
          ),
      ],
    );
    final comparison = compareSet(effective, prev);
    final delta = comparison.verdict == Verdict.manteve
        ? null
        : _describeDelta(comparison);

    return Text.rich(
      TextSpan(
        style: style,
        children: [
          TextSpan(
            text:
                'última vez ${formatWeight(prev.referenceLoadKg!)} × '
                '${prev.totalReps}',
          ),
          if (delta != null)
            TextSpan(
              text: ' · $delta',
              style: TextStyle(
                color: c.verdict(comparison.verdict == Verdict.evoluiu),
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }
}

/// A linha "Série 1 concluída · +2,5 kg" que aparece por um instante depois
/// de concluir — o delta é o motivo do app existir, e merece ser visto na
/// hora, não só no resumo.
class _FlashLine extends StatelessWidget {
  const _FlashLine({required this.flash});

  final _Flash? flash;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final f = flash;

    return AnimatedSize(
      duration: AppDurations.base,
      curve: Curves.easeOutCubic,
      child: f == null
          ? const SizedBox(width: double.infinity)
          : Padding(
              padding: const EdgeInsets.only(bottom: Space.lg),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: Space.lg,
                  vertical: Space.sm,
                ),
                decoration: ShapeDecoration(
                  color: switch (f.comparison.verdict) {
                    Verdict.evoluiu => c.upSubtle,
                    Verdict.reduziu => c.downSubtle,
                    _ => c.fill,
                  },
                  shape: const StadiumBorder(),
                ),
                child: Text(
                  [f.label, ?_describeDelta(f.comparison)].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: AppText.subheadline.copyWith(
                    color: switch (f.comparison.verdict) {
                      Verdict.evoluiu => c.up,
                      Verdict.reduziu => c.down,
                      _ => c.textPrimary,
                    },
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
    );
  }
}

/// Um segmento de drop ou cluster: carga × reps, cada um tocável.
class _SegmentRow extends StatelessWidget {
  const _SegmentRow({
    required this.index,
    required this.type,
    required this.segment,
    required this.previous,
    required this.onWeight,
    required this.onReps,
  });

  final int index;
  final SetType type;
  final SetSegment segment;
  final SegmentData? previous;
  final ValueChanged<double> onWeight;
  final ValueChanged<int> onReps;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final noun = type == SetType.drop ? 'queda' : 'bloco';

    return Row(
      children: [
        SizedBox(
          width: 52,
          child: Text(
            '${index + 1}º $noun',
            style: AppText.footnote.copyWith(color: c.textSecondary),
          ),
        ),
        Expanded(
          child: _BoxValue(
            value: segment.weightKg,
            ghost: previous?.weightKg,
            unit: 'kg',
            semantics: 'Carga do ${index + 1}º $noun',
            onTap: () async {
              final v = await showNumberPad(
                context,
                title: 'Carga · ${index + 1}º $noun',
                initial: segment.weightKg,
                decimal: true,
                unit: 'kg',
                lastValue: previous?.weightKg,
              );
              if (v != null) onWeight(v);
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Space.md),
          child: Text(
            '×',
            style: AppText.headline.copyWith(color: c.textTertiary),
          ),
        ),
        Expanded(
          child: _BoxValue(
            value: segment.reps.toDouble(),
            ghost: previous?.reps.toDouble(),
            unit: 'reps',
            semantics: 'Repetições do ${index + 1}º $noun',
            onTap: () async {
              final v = await showNumberPad(
                context,
                title: 'Repetições · ${index + 1}º $noun',
                initial: segment.reps.toDouble(),
                unit: 'reps',
                lastValue: previous?.reps.toDouble(),
              );
              if (v != null) onReps(v.round());
            },
          ),
        ),
      ],
    );
  }
}

/// Número grande que abre o teclado ao toque. Vazio, mostra a última vez
/// apagada — concluir sem digitar repete esse valor.
class _TapValue extends StatelessWidget {
  const _TapValue({
    required this.value,
    required this.ghost,
    required this.unit,
    required this.style,
    required this.semantics,
    required this.onTap,
  });

  final double value;
  final double? ghost;
  final String unit;
  final TextStyle style;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final empty = value == 0;
    final shown = empty ? ghost : value;

    return Semantics(
      button: true,
      label: semantics,
      value: shown == null ? 'vazio' : formatWeight(shown),
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        scale: 0.95,
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                shown == null ? '—' : formatWeight(shown),
                style: style.copyWith(
                  color: empty ? c.textGhost : c.textPrimary,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: AppText.headline.copyWith(color: c.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Valor em caixa, para os segmentos de drop e cluster.
class _BoxValue extends StatelessWidget {
  const _BoxValue({
    required this.value,
    required this.ghost,
    required this.unit,
    required this.semantics,
    required this.onTap,
  });

  final double value;
  final double? ghost;
  final String unit;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final empty = value == 0;
    final shown = empty ? ghost : value;

    return Semantics(
      button: true,
      label: semantics,
      value: shown == null ? 'vazio' : formatWeight(shown),
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        scale: 0.95,
        child: Container(
          height: 52,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: c.surfaceInput,
            shape: AppShapes.superellipse(Radii.md + 2),
          ),
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: shown == null ? '—' : formatWeight(shown),
                  style: AppText.numberMedium.copyWith(
                    color: empty ? c.textGhost : c.textPrimary,
                  ),
                ),
                TextSpan(
                  text: ' $unit',
                  style: AppText.footnote.copyWith(color: c.textSecondary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Botão redondo de passo, grande o bastante para acertar sem olhar.
class _RoundStep extends StatelessWidget {
  const _RoundStep({
    required this.icon,
    required this.size,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final double size;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        scale: 0.88,
        child: Container(
          width: size,
          height: size,
          decoration: ShapeDecoration(
            color: c.fill,
            shape: const CircleBorder(),
          ),
          child: Icon(icon, size: size * 0.42, color: c.textPrimary),
        ),
      ),
    );
  }
}

/// Exercício terminado: o que foi feito em cada série, com o delta.
class _ExerciseDone extends StatelessWidget {
  const _ExerciseDone({
    required this.sets,
    required this.lastSets,
    required this.flash,
  });

  final List<LiveSet> sets;
  final List<PerformedSet> lastSets;
  final _Flash? flash;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return AppCard(
      padding: const EdgeInsets.fromLTRB(
        Space.xxl,
        Space.xl,
        Space.xxl,
        Space.lg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _FlashLine(flash: flash),
          Row(
            children: [
              Icon(LucideIcons.circleCheck, size: 18, color: c.up),
              const SizedBox(width: Space.sm),
              Text(
                'Exercício concluído',
                style: AppText.headline.copyWith(color: c.textPrimary),
              ),
            ],
          ),
          const SizedBox(height: Space.md),
          for (var i = 0; i < sets.length; i++)
            Builder(
              builder: (context) {
                final live = sets[i];
                final performed = PerformedSet(
                  position: live.set.position,
                  type: live.set.setType,
                  segments: [
                    for (final s in live.segments)
                      SegmentData(weightKg: s.weightKg, reps: s.reps),
                  ],
                );
                final comparison = compareSet(
                  performed,
                  _previousFor(lastSets, live.set.position),
                );
                final delta = _describeDelta(comparison);

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: Space.sm),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 28,
                        child: Text(
                          _workingNumber(sets, i),
                          style: AppText.footnote.copyWith(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          _describe(performed),
                          style: AppText.body.copyWith(color: c.textPrimary),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (delta != null)
                        Text(
                          delta == 'igual' ? '=' : delta,
                          style: AppText.footnote.copyWith(
                            color: switch (comparison.verdict) {
                              Verdict.evoluiu => c.up,
                              Verdict.reduziu => c.down,
                              _ => c.textSecondary,
                            },
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  String _describe(PerformedSet set) {
    final segments = set.filledSegments.toList();
    if (segments.isEmpty) return '—';
    return switch (set.type) {
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

/// A base do painel: o próximo exercício numa cápsula de vidro e a ação cheia
/// embaixo, onde o polegar alcança.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.next,
    required this.onNext,
    required this.primary,
  });

  final LiveExercise? next;
  final VoidCallback onNext;
  final Widget primary;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = next;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.page,
          Space.xs,
          Space.page,
          Space.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (n != null) ...[
              Semantics(
                button: true,
                label: 'A seguir: ${n.exercise.name}',
                excludeSemantics: true,
                child: PressScale(
                  onTap: onNext,
                  scale: 0.97,
                  child: SizedBox(
                    height: 46,
                    child: GlassSurface.capsule(
                      child: Padding(
                        padding: const EdgeInsets.only(
                          left: Space.sm,
                          right: Space.lg,
                        ),
                        child: Row(
                          children: [
                            ExerciseAvatar(
                              name: n.exercise.name,
                              group: n.exercise.muscleGroup,
                              size: 30,
                            ),
                            const SizedBox(width: Space.md),
                            Text(
                              'A seguir · ',
                              style: AppText.subheadline.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                n.exercise.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.subheadline.copyWith(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Icon(
                              LucideIcons.chevronRight,
                              size: 18,
                              color: c.textTertiary,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Space.md),
            ],
            primary,
          ],
        ),
      ),
    );
  }
}
