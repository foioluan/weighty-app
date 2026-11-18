import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/design/design.dart';
import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../data/repos/routine_repository.dart';
import '../../domain/models/enums.dart';
import '../exercises/exercise_catalog_page.dart';
import 'routines_page.dart' show promptForName, startRoutineSession;

/// A página do treino: os exercícios com as séries resumidas ("3 × 10"), um
/// aberto por vez para editar no lugar, e "Iniciar treino" na base.
///
/// Antes cada série era um chip e qualquer ajuste de repetições abria uma
/// folha com a lista de tipos, dois campos e dois botões. Agora o ajuste comum
/// — uma repetição a mais, uma série a mais — é um toque, e a folha só aparece
/// para digitar.
class RoutineEditorPage extends ConsumerStatefulWidget {
  const RoutineEditorPage({
    super.key,
    required this.routineId,
    this.backLabel = 'Treinos',
  });

  final int routineId;
  final String backLabel;

  @override
  ConsumerState<RoutineEditorPage> createState() => _RoutineEditorPageState();
}

class _RoutineEditorPageState extends ConsumerState<RoutineEditorPage> {
  /// O exercício aberto, pelo id do vínculo. Um por vez: com todos abertos a
  /// tela voltava a ser a parede de séries que o resumo existe para evitar.
  int? _expanded;

  /// O primeiro exercício abre sozinho na primeira carga, para a edição no
  /// lugar ser descoberta sem instrução.
  var _opened = false;

  /// Séries apagadas por deslize que o banco ainda não devolveu sem elas. O
  /// Dismissible exige sair da árvore no mesmo instante; esperar o treino
  /// recarregar deixava a linha apagada ali e o Flutter acusava erro.
  final _hiddenSets = <int>{};

  int get routineId => widget.routineId;

  @override
  Widget build(BuildContext context) {
    final detail = ref.watch(routineDetailProvider(routineId));
    final data = detail.valueOrNull;

    if (!_opened && data != null) {
      _opened = true;
      if (data.exercises.isNotEmpty) _expanded = data.exercises.first.link.id;
    }

    return AppScaffold(
      largeTitle: data?.routine.name ?? 'Treino',
      subtitle: data == null
          ? null
          : '${_plural(data.exercises.length, 'exercício', 'exercícios')} · '
                '${_plural(data.totalSets, 'série', 'séries')}',
      backLabel: widget.backLabel,
      actions: [
        // Renomear e excluir moram no ⋯: eram dois círculos (lápis, lixeira)
        // disputando o topo com o título, para ações que se usam raramente.
        Builder(
          builder: (anchor) => AppNavIcon(
            icon: LucideIcons.ellipsis,
            label: 'Opções do treino',
            onTap: () => _openMenu(anchor, data),
          ),
        ),
      ],
      bottomBar: data == null
          ? null
          : AppButton(
              label: 'Iniciar treino',
              icon: LucideIcons.play,
              expand: true,
              onPressed: data.exercises.isEmpty
                  ? null
                  : () {
                      Haptics.tick();
                      startRoutineSession(context, ref, routineId);
                    },
            ),
      slivers: detail.when(
        loading: () => const [],
        error: (e, _) => [
          AppSliverFill(
            child: EmptyState(title: 'Erro', message: '$e'),
          ),
        ],
        data: (data) {
          if (data == null) {
            return const [
              AppSliverFill(
                child: EmptyState(
                  title: 'Treino não encontrado',
                  message: 'Ele pode ter sido arquivado.',
                ),
              ),
            ];
          }

          // O estado vazio fica fora da lista reordenável: dentro dela ele era
          // um item arrastável, o que não faz sentido nenhum.
          if (data.exercises.isEmpty) {
            return [
              AppSliverList(
                padding: _listPadding,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: Space.xxl, bottom: Space.xxl),
                    child: EmptyState(
                      title: 'Nenhum exercício',
                      message:
                          'Adicione exercícios abaixo para montar este treino.',
                    ),
                  ),
                  _AddExerciseRow(routineId: routineId, onAdded: _expand),
                ],
              ),
            ];
          }

          return [
            SliverPadding(
              padding: _listPadding,
              sliver: SliverReorderableList(
                itemCount: data.exercises.length,
                onReorderStart: (_) => Haptics.tick(),
                onReorderItem: (oldIndex, newIndex) =>
                    _reorder(data, oldIndex, newIndex),
                proxyDecorator: _liftCard,
                // Toque longo em qualquer ponto do card, sem pegador visível.
                itemBuilder: (context, i) {
                  final item = data.exercises[i];
                  return ReorderableDelayedDragStartListener(
                    key: ValueKey(item.link.id),
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: Space.md + 2),
                      child: StaggeredEntry(
                        index: i,
                        child: _ExerciseCard(
                          routineId: routineId,
                          detail: item,
                          expanded: _expanded == item.link.id,
                          hiddenSets: _hiddenSets,
                          onHideSet: (id) =>
                              setState(() => _hiddenSets.add(id)),
                          onToggle: () {
                            Haptics.tick();
                            setState(
                              () => _expanded = _expanded == item.link.id
                                  ? null
                                  : item.link.id,
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            AppSliverList(
              padding: const EdgeInsets.fromLTRB(
                Space.page,
                Space.xs,
                Space.page,
                0,
              ),
              children: [
                _AddExerciseRow(routineId: routineId, onAdded: _expand),
                const SizedBox(height: Space.lg),
                Text(
                  'Deslize uma série para apagar · '
                  'segure um exercício para mover',
                  textAlign: TextAlign.center,
                  style: AppText.footnote.copyWith(
                    color: context.colors.textTertiary,
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );
  }

  void _expand(int linkId) => setState(() => _expanded = linkId);

  static const _listPadding = EdgeInsets.fromLTRB(
    Space.page,
    Space.xs,
    Space.page,
    0,
  );

  /// Realce do card arrastado. O padrão do `ReorderableListView` embrulha o
  /// item num Material com elevação — a sombra que mais entrega "Android
  /// padrão". Aqui o item só cresce um tico.
  static Widget _liftCard(
    Widget child,
    int index,
    Animation<double> animation,
  ) {
    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        final t = Curves.easeOut.transform(animation.value);
        return Material(
          // O proxy vai para um Overlay: sem Material aqui, o texto do card
          // arrastado ganharia o sublinhado amarelo de "faltou Material".
          color: Colors.transparent,
          child: Transform.scale(scale: 1 + 0.03 * t, child: child),
        );
      },
      child: child,
    );
  }

  Future<void> _openMenu(BuildContext anchor, RoutineDetail? data) async {
    if (data == null) return;
    final action = await showAppMenu<String>(
      anchor,
      items: const [
        AppMenuItem(
          label: 'Renomear',
          icon: LucideIcons.pencil,
          value: 'rename',
        ),
        AppMenuItem(
          label: 'Excluir treino',
          icon: LucideIcons.trash2,
          value: 'delete',
          isDestructive: true,
        ),
      ],
    );
    if (!mounted) return;
    switch (action) {
      case 'rename':
        await _rename(data);
      case 'delete':
        await _delete(data);
    }
  }

  Future<void> _rename(RoutineDetail data) async {
    final name = await promptForName(
      context,
      title: 'Renomear treino',
      initial: data.routine.name,
    );
    if (name == null || name.isEmpty) return;

    await ref.read(routineRepositoryProvider).renameRoutine(routineId, name);
    ref.invalidate(routineDetailProvider(routineId));
    ref.invalidate(routineSummariesProvider);
  }

  Future<void> _delete(RoutineDetail data) async {
    final confirmed = await showAppDialog<bool>(
      context,
      title: 'Excluir "${data.routine.name}"?',
      message:
          'O treino e as séries planejadas dele serão apagados. '
          'As sessões já registradas continuam no histórico e seguem contando '
          'na evolução dos exercícios.',
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
    if (confirmed != true) return;

    Haptics.warn();
    await ref.read(routineRepositoryProvider).deleteRoutine(routineId);
    ref.invalidate(routineSummariesProvider);
    ref.invalidate(weekSummaryProvider);

    if (mounted) {
      AppToast.show(context, '"${data.routine.name}" excluído.');
      context.pop();
    }
  }

  Future<void> _reorder(RoutineDetail data, int oldIndex, int newIndex) async {
    // onReorderItem já entrega o índice de destino ajustado.
    final ids = data.exercises.map((e) => e.link.id).toList();
    if (oldIndex >= ids.length) return;
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex.clamp(0, ids.length), moved);

    await ref.read(routineRepositoryProvider).reorderExercises(ids);
    ref.invalidate(routineDetailProvider(routineId));
  }
}

String _plural(int n, String one, String many) => '$n ${n == 1 ? one : many}';

/// Abre o catálogo em modo de escolha e devolve o exercício escolhido.
Future<Exercise?> pickExercise(
  BuildContext context, {
  required String title,
  required IconData icon,
}) {
  // Folha, e não tela empurrada: escolher é uma tarefa que se conclui e
  // volta, e a folha deixa o editor visível atrás, encolhido.
  return Navigator.push<Exercise>(
    context,
    FastSheetRoute<Exercise>(
      scrollableBuilder: (_, controller) => ExerciseCatalogPage(
        selecting: true,
        title: title,
        selectIcon: icon,
        scrollController: controller,
      ),
    ),
  );
}

class _AddExerciseRow extends ConsumerWidget {
  const _AddExerciseRow({required this.routineId, required this.onAdded});

  final int routineId;

  /// Recebe o id do vínculo novo, para o exercício já abrir expandido.
  final ValueChanged<int> onAdded;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return InsetGroup(
      children: [
        AppRow(
          title: 'Adicionar exercício',
          titleColor: c.accent,
          leading: Icon(LucideIcons.plus, size: 20, color: c.accent),
          onTap: () => _add(context, ref),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final exercise = await pickExercise(
      context,
      title: 'Escolher exercício',
      icon: LucideIcons.plus,
    );
    if (exercise == null) return;

    final linkId = await ref
        .read(routineRepositoryProvider)
        .addExercise(routineId, exercise.id);
    ref.invalidate(routineDetailProvider(routineId));
    ref.invalidate(routineSummariesProvider);
    onAdded(linkId);
  }
}

/// O que o menu de três pontos pode devolver.
enum _ExerciseAction { replace, duplicateLast, remove }

/// Resumo das séries em uma linha: "aquecimento + 3 × 8–10 + drop".
///
/// Séries vizinhas iguais se juntam. É o que substitui a fileira de chips
/// "8-10 8-10 8-10", que repetia a mesma informação três vezes.
String summarizeSets(List<PlannedSet> sets) {
  if (sets.isEmpty) return 'sem séries';

  String keyOf(PlannedSet s) =>
      '${s.setType.name}:${_targetLabel(s.targetReps, s.targetRepsMax)}';

  final parts = <String>[];
  var i = 0;
  while (i < sets.length) {
    final key = keyOf(sets[i]);
    var n = 0;
    while (i + n < sets.length && keyOf(sets[i + n]) == key) {
      n++;
    }
    final set = sets[i];
    final target = _targetLabel(set.targetReps, set.targetRepsMax);
    parts.add(switch (set.setType) {
      SetType.aquecimento => n == 1 ? 'aquecimento' : '$n aquecimentos',
      SetType.drop => n == 1 ? 'drop' : '$n drops',
      SetType.cluster => n == 1 ? 'cluster' : '$n clusters',
      SetType.normal =>
        target == null ? _plural(n, 'série', 'séries') : '$n × $target',
    });
    i += n;
  }
  return parts.join(' + ');
}

/// "10", "8–12" ou nulo sem alvo.
String? _targetLabel(int? min, int? max) => switch ((min, max)) {
  (null, _) => null,
  (final a?, null) => '$a',
  (final a?, final b?) => '$a–$b',
};

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    required this.routineId,
    required this.detail,
    required this.expanded,
    required this.onToggle,
    required this.hiddenSets,
    required this.onHideSet,
  });

  final int routineId;
  final RoutineExerciseDetail detail;
  final bool expanded;
  final VoidCallback onToggle;
  final Set<int> hiddenSets;
  final ValueChanged<int> onHideSet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final sets = [
      for (final s in detail.sets)
        if (!hiddenSets.contains(s.id)) s,
    ];

    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: ColoredBox(
        color: c.surface,
        child: Column(
          children: [
            Semantics(
              button: true,
              expanded: expanded,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.xl,
                    Space.lg + 2,
                    Space.sm,
                    Space.lg + 2,
                  ),
                  child: Row(
                    children: [
                      ExerciseAvatar(
                        name: detail.exercise.name,
                        group: detail.exercise.muscleGroup,
                      ),
                      const SizedBox(width: Space.lg),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              detail.exercise.name,
                              style: AppText.headline.copyWith(
                                color: c.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              summarizeSets(sets),
                              style: AppText.footnote.copyWith(
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Builder(
                        builder: (anchor) => AppIconButton(
                          icon: LucideIcons.ellipsis,
                          size: 20,
                          tapSize: 40,
                          label: 'Opções de ${detail.exercise.name}',
                          onPressed: () => _openMenu(context, anchor, ref),
                        ),
                      ),
                      AnimatedRotation(
                        turns: expanded ? 0.5 : 0,
                        duration: AppDurations.base,
                        curve: Curves.easeOutCubic,
                        child: Icon(
                          LucideIcons.chevronDown,
                          size: 20,
                          color: c.textTertiary,
                        ),
                      ),
                      const SizedBox(width: Space.sm),
                    ],
                  ),
                ),
              ),
            ),
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: !expanded
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.lg,
                        0,
                        Space.lg,
                        Space.lg,
                      ),
                      child: Column(
                        children: [
                          for (var i = 0; i < sets.length; i++) ...[
                            if (i > 0)
                              Padding(
                                padding: const EdgeInsets.only(left: 44),
                                child: Container(
                                  height: 0.5,
                                  color: c.hairline,
                                ),
                              ),
                            _SetRow(
                              key: ValueKey(sets[i].id),
                              set: sets[i],
                              number: _workingNumber(sets, i),
                              onChanged: () => _invalidate(ref),
                              onDeleted: () => _deleteSet(ref, sets[i]),
                            ),
                          ],
                          const SizedBox(height: Space.md),
                          Row(
                            children: [
                              AppButton(
                                label: 'Série',
                                icon: LucideIcons.plus,
                                style: AppButtonStyle.tinted,
                                compact: true,
                                onPressed: () => _addSet(ref),
                              ),
                              const SizedBox(width: Space.sm),
                              if (sets.isNotEmpty)
                                AppButton(
                                  label: 'Repetir última',
                                  icon: LucideIcons.copyPlus,
                                  style: AppButtonStyle.plain,
                                  compact: true,
                                  onPressed: () => _duplicateLast(ref),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  /// Aquecimento não entra na numeração das séries de trabalho.
  static String _workingNumber(List<PlannedSet> sets, int index) {
    if (sets[index].setType == SetType.aquecimento) return 'aq';
    var n = 0;
    for (var i = 0; i <= index; i++) {
      if (sets[i].setType != SetType.aquecimento) n++;
    }
    return '$n';
  }

  void _invalidate(WidgetRef ref) {
    ref.invalidate(routineDetailProvider(routineId));
    ref.invalidate(routineSummariesProvider);
  }

  /// [anchor] é o contexto do botão `⋯`: o menu nasce dele, e não do card.
  Future<void> _openMenu(
    BuildContext context,
    BuildContext anchor,
    WidgetRef ref,
  ) async {
    final hasSets = detail.sets.isNotEmpty;

    final action = await showAppMenu<_ExerciseAction>(
      anchor,
      items: [
        const AppMenuItem(
          label: 'Substituir exercício',
          icon: LucideIcons.repeat,
          value: _ExerciseAction.replace,
        ),
        if (hasSets)
          const AppMenuItem(
            label: 'Duplicar última série',
            icon: LucideIcons.copyPlus,
            value: _ExerciseAction.duplicateLast,
          ),
        const AppMenuItem(
          label: 'Remover do treino',
          icon: LucideIcons.trash2,
          value: _ExerciseAction.remove,
          isDestructive: true,
        ),
      ],
    );
    if (action == null || !context.mounted) return;

    switch (action) {
      case _ExerciseAction.replace:
        await _replace(context, ref);
      case _ExerciseAction.duplicateLast:
        await _duplicateLast(ref);
      case _ExerciseAction.remove:
        await _remove(context, ref);
    }
  }

  Future<void> _replace(BuildContext context, WidgetRef ref) async {
    final chosen = await pickExercise(
      context,
      title: 'Substituir exercício',
      icon: LucideIcons.repeat,
    );
    if (chosen == null || chosen.id == detail.exercise.id) return;

    final previous = detail.exercise.name;
    await ref
        .read(routineRepositoryProvider)
        .replaceExercise(detail.link.id, chosen.id);
    _invalidate(ref);

    if (context.mounted) {
      Haptics.confirm();
      AppToast.show(context, '$previous → ${chosen.name}');
    }
  }

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    // Remover joga fora as séries planejadas junto, então confirma — era a
    // única ação destrutiva do app que acontecia calada.
    final confirmed = await showAppDialog<bool>(
      context,
      title: 'Remover "${detail.exercise.name}"?',
      message:
          'As séries planejadas dele neste treino serão apagadas. '
          'O histórico já registrado não muda.',
      actions: const [
        AppDialogAction(label: 'Cancelar', value: false),
        AppDialogAction(
          label: 'Remover',
          value: true,
          isDestructive: true,
          isPreferred: true,
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;

    Haptics.warn();
    final name = detail.exercise.name;
    // Capturado antes: este card sai da lista na hora, e com ele o contexto
    // que mostraria o aviso.
    final toast = AppToast.capture(context);

    await ref.read(routineRepositoryProvider).removeExercise(detail.link.id);
    _invalidate(ref);

    toast.show('$name removido do treino.');
  }

  Future<void> _addSet(WidgetRef ref) async {
    Haptics.tick();
    await ref
        .read(routineRepositoryProvider)
        .addSet(detail.link.id, targetReps: 10);
    _invalidate(ref);
  }

  /// Montar "4 × 10" fica em dois toques em vez de quatro.
  Future<void> _duplicateLast(WidgetRef ref) async {
    final last = detail.sets.last;
    Haptics.tick();
    await ref
        .read(routineRepositoryProvider)
        .addSet(
          detail.link.id,
          type: last.setType,
          targetReps: last.targetReps,
          targetRepsMax: last.targetRepsMax,
          segmentCount: last.segmentCount,
        );
    _invalidate(ref);
  }

  Future<void> _deleteSet(WidgetRef ref, PlannedSet set) async {
    Haptics.warn();
    onHideSet(set.id);
    await ref.read(routineRepositoryProvider).removeSet(set.id);
    _invalidate(ref);
  }
}

/// Uma série planejada, editável no lugar: o selo troca o tipo, o − e + mexem
/// nas repetições, tocar no número abre o teclado, e deslizar apaga.
class _SetRow extends ConsumerWidget {
  const _SetRow({
    super.key,
    required this.set,
    required this.number,
    required this.onChanged,
    required this.onDeleted,
  });

  final PlannedSet set;
  final String number;
  final VoidCallback onChanged;
  final VoidCallback onDeleted;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final type = set.setType;
    final target = _targetLabel(set.targetReps, set.targetRepsMax);

    final title = switch (type) {
      SetType.normal => 'Série $number',
      _ => type.label,
    };
    final noun = type == SetType.drop ? 'quedas' : 'blocos';

    return Dismissible(
      key: ValueKey('dismiss-${set.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: Space.lg),
        decoration: ShapeDecoration(
          color: c.downSubtle,
          shape: AppShapes.superellipse(Radii.md),
        ),
        child: Icon(LucideIcons.trash2, size: 19, color: c.down),
      ),
      onDismissed: (_) => onDeleted(),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: Space.sm),
        child: Row(
          children: [
            Builder(
              builder: (anchor) => _TypeBadge(
                type: type,
                number: number,
                onTap: () => _pickType(anchor, ref),
              ),
            ),
            const SizedBox(width: Space.lg),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppText.body.copyWith(color: c.textPrimary),
                  ),
                  if (type.isMultiSegment)
                    Builder(
                      builder: (anchor) => GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _pickCount(anchor, ref),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '${set.segmentCount} $noun',
                              style: AppText.footnote.copyWith(
                                color: c.accent,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            Icon(
                              LucideIcons.chevronDown,
                              size: 14,
                              color: c.accent,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            _RepsStepper(
              label: target ?? '—',
              semantics: 'Repetições da ${title.toLowerCase()}',
              onStep: (delta) => _step(ref, delta),
              onTap: () => _type(context, ref, title),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(
    WidgetRef ref, {
    SetType? type,
    int? segmentCount,
    required int? min,
    required int? max,
  }) async {
    await ref
        .read(routineRepositoryProvider)
        .updateSet(
          set.id,
          type: type,
          segmentCount: segmentCount,
          targetReps: min,
          // Faixa que não é faixa ("10–10") vira alvo único.
          targetRepsMax: (min == null || max == null || max <= min)
              ? null
              : max,
        );
    onChanged();
  }

  /// Com alvo único, ±1. Com faixa, a faixa inteira anda junto (8–10 → 9–11):
  /// é o ajuste que se faz de uma semana para a outra.
  Future<void> _step(WidgetRef ref, int delta) async {
    Haptics.tick();
    final min = set.targetReps ?? 10;
    final max = set.targetRepsMax;
    final nextMin = (min + delta).clamp(1, 99);
    final shift = nextMin - min;
    await _save(ref, min: nextMin, max: max == null ? null : max + shift);
  }

  Future<void> _type(BuildContext context, WidgetRef ref, String title) async {
    final result = await showRangePad(
      context,
      title: 'Repetições · $title',
      from: set.targetReps,
      to: set.targetRepsMax,
    );
    if (result == null) return;
    await _save(ref, min: result.$1, max: result.$2);
  }

  Future<void> _pickType(BuildContext anchor, WidgetRef ref) async {
    final type = await showAppMenu<SetType>(
      anchor,
      items: [
        for (final t in SetType.values)
          AppMenuItem(label: t.label, value: t, selected: t == set.setType),
      ],
    );
    if (type == null || type == set.setType) return;
    Haptics.tick();
    // Normal e aquecimento têm sempre um segmento; drop e cluster começam
    // com três, que é o mais comum.
    await _save(
      ref,
      type: type,
      segmentCount: type.isMultiSegment
          ? (set.segmentCount > 1 ? set.segmentCount : 3)
          : 1,
      min: set.targetReps,
      max: set.targetRepsMax,
    );
  }

  Future<void> _pickCount(BuildContext anchor, WidgetRef ref) async {
    final noun = set.setType == SetType.drop ? 'quedas' : 'blocos';
    final count = await showAppMenu<int>(
      anchor,
      items: [
        for (var n = 2; n <= 6; n++)
          AppMenuItem(
            label: '$n $noun',
            value: n,
            selected: n == set.segmentCount,
          ),
      ],
    );
    if (count == null || count == set.segmentCount) return;
    Haptics.tick();
    await _save(
      ref,
      segmentCount: count,
      min: set.targetReps,
      max: set.targetRepsMax,
    );
  }
}

/// Selo da série: número para as de trabalho, "aq" só com contorno (não conta
/// para indicador nenhum), "D"/"C" tingidos. Tocar troca o tipo.
class _TypeBadge extends StatelessWidget {
  const _TypeBadge({
    required this.type,
    required this.number,
    required this.onTap,
  });

  final SetType type;
  final String number;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (label, bg, fg, side) = switch (type) {
      SetType.aquecimento => (
        'aq',
        Colors.transparent,
        c.textSecondary,
        BorderSide(color: c.hairlineStrong, width: 1.5),
      ),
      SetType.drop => ('D', c.accentSubtle, c.accent, BorderSide.none),
      SetType.cluster => ('C', c.accentSubtle, c.accent, BorderSide.none),
      SetType.normal => (number, c.fill, c.textPrimary, BorderSide.none),
    };

    return Semantics(
      button: true,
      label: 'Tipo: ${type.label}',
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        scale: 0.88,
        child: Container(
          width: 32,
          height: 32,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: bg,
            shape: AppShapes.superellipse(Radii.sm, side: side),
          ),
          child: Text(
            label,
            style: AppText.footnote.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

/// − valor + das repetições, num controle só. Tocar no valor abre o teclado.
class _RepsStepper extends StatelessWidget {
  const _RepsStepper({
    required this.label,
    required this.semantics,
    required this.onStep,
    required this.onTap,
  });

  final String label;
  final String semantics;
  final ValueChanged<int> onStep;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget half(IconData icon, int delta, String what) => Semantics(
      button: true,
      label: '$what · $semantics',
      excludeSemantics: true,
      child: PressScale(
        onTap: () => onStep(delta),
        scale: 0.85,
        child: SizedBox(
          width: 36,
          height: 38,
          child: Icon(icon, size: 17, color: c.textSecondary),
        ),
      ),
    );

    return Container(
      height: 38,
      decoration: ShapeDecoration(
        color: c.surfaceInput,
        shape: AppShapes.superellipse(Radii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          half(LucideIcons.minus, -1, 'Menos'),
          Semantics(
            button: true,
            label: semantics,
            value: label,
            excludeSemantics: true,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 52),
                child: Center(
                  widthFactor: 1,
                  child: Text(
                    label,
                    style: AppText.numberSmall.copyWith(
                      color: c.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ),
          half(LucideIcons.plus, 1, 'Mais'),
        ],
      ),
    );
  }
}
