import 'package:flutter/cupertino.dart' show CupertinoSheetRoute;
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
import 'routines_page.dart' show promptForName;

class RoutineEditorPage extends ConsumerWidget {
  const RoutineEditorPage({
    super.key,
    required this.routineId,
    this.backLabel = 'Treinos',
  });

  final int routineId;
  final String backLabel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(routineDetailProvider(routineId));
    final data = detail.valueOrNull;

    return AppScaffold(
      largeTitle: data?.routine.name ?? 'Treino',
      backLabel: backLabel,
      actions: [
        AppNavIcon(
          icon: LucideIcons.pencil,
          label: 'Renomear treino',
          onTap: () => _rename(context, ref, data),
        ),
        AppNavIcon(
          icon: LucideIcons.trash2,
          label: 'Excluir treino',
          onTap: () => _delete(context, ref, data),
        ),
      ],
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
                  _AddExerciseRow(routineId: routineId),
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
                    _reorder(ref, data, oldIndex, newIndex),
                proxyDecorator: _liftCard,
                // Toque longo em qualquer ponto do card, sem pegador visível —
                // o mesmo gesto que o ReorderableListView dava sozinho.
                itemBuilder: (context, i) =>
                    ReorderableDelayedDragStartListener(
                      key: ValueKey(data.exercises[i].link.id),
                      index: i,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: Space.lg),
                        child: StaggeredEntry(
                          index: i,
                          child: _ExerciseCard(
                            routineId: routineId,
                            detail: data.exercises[i],
                            index: i,
                          ),
                        ),
                      ),
                    ),
              ),
            ),
            AppSliverList(
              padding: const EdgeInsets.fromLTRB(
                Space.page,
                Space.md,
                Space.page,
                0,
              ),
              children: [_AddExerciseRow(routineId: routineId)],
            ),
          ];
        },
      ),
    );
  }

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

  Future<void> _rename(
    BuildContext context,
    WidgetRef ref,
    RoutineDetail? data,
  ) async {
    if (data == null) return;
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

  Future<void> _delete(
    BuildContext context,
    WidgetRef ref,
    RoutineDetail? data,
  ) async {
    if (data == null) return;

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

    if (context.mounted) {
      AppToast.show(context, '"${data.routine.name}" excluído.');
      context.pop();
    }
  }

  Future<void> _reorder(
    WidgetRef ref,
    RoutineDetail data,
    int oldIndex,
    int newIndex,
  ) async {
    // onReorderItem já entrega o índice de destino ajustado.
    final ids = data.exercises.map((e) => e.link.id).toList();
    if (oldIndex >= ids.length) return;
    final moved = ids.removeAt(oldIndex);
    ids.insert(newIndex.clamp(0, ids.length), moved);

    await ref.read(routineRepositoryProvider).reorderExercises(ids);
    ref.invalidate(routineDetailProvider(routineId));
  }
}

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
    CupertinoSheetRoute<Exercise>(
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
  const _AddExerciseRow({required this.routineId});

  final int routineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return InsetGroup(
      children: [
        AppRow(
          title: 'Adicionar exercício',
          titleColor: c.accent,
          leading: Icon(LucideIcons.plus, size: 19, color: c.accent),
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

    await ref
        .read(routineRepositoryProvider)
        .addExercise(routineId, exercise.id);
    ref.invalidate(routineDetailProvider(routineId));
    ref.invalidate(routineSummariesProvider);
  }
}

/// O que o menu de três pontos pode devolver.
enum _ExerciseAction { replace, duplicateLast, remove }

class _ExerciseCard extends ConsumerWidget {
  const _ExerciseCard({
    required this.routineId,
    required this.detail,
    required this.index,
  });

  final int routineId;
  final RoutineExerciseDetail detail;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    // Arrastar por toque longo no card inteiro, em vez de por um pegador
    // visível: o pegador ocupava a mesma linha do nome e do X e deixava o
    // cabeçalho com três coisas competindo.
    return ReorderableDelayedDragStartListener(
      index: index,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.lg,
          Space.md,
          Space.lg,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
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
                        style: AppText.headline.copyWith(color: c.textPrimary),
                      ),
                      Text(
                        detail.exercise.muscleGroup.label,
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
              ],
            ),
            const SizedBox(height: Space.lg),
            Padding(
              padding: const EdgeInsets.only(right: Space.sm),
              child: Wrap(
                spacing: Space.sm,
                runSpacing: Space.sm,
                children: [
                  for (var i = 0; i < detail.sets.length; i++)
                    SetChip(
                      type: detail.sets[i].setType,
                      targetReps: detail.sets[i].targetReps,
                      targetRepsMax: detail.sets[i].targetRepsMax,
                      segmentCount: detail.sets[i].segmentCount,
                      onTap: () =>
                          _editSet(context, ref, detail.sets[i], i + 1),
                    ),
                  SetChip.add(onTap: () => _addSet(ref)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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

  /// Montar "4 x 10" fica em dois toques em vez de quatro.
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

  Future<void> _editSet(
    BuildContext context,
    WidgetRef ref,
    PlannedSet set,
    int number,
  ) async {
    Haptics.tick();
    final result = await showAppSheet<_SetResult>(
      context,
      title: 'Série $number',
      builder: (context) => _SetConfigSheet(set: set),
    );
    if (result == null) return;

    final repo = ref.read(routineRepositoryProvider);
    switch (result) {
      case _SetSaved(:final config):
        await repo.updateSet(
          set.id,
          type: config.type,
          targetReps: config.targetReps,
          targetRepsMax: config.targetRepsMax,
          segmentCount: config.segmentCount,
        );
        // A contagem de séries não mudou, então o resumo da home não precisa
        // ser refeito.
        ref.invalidate(routineDetailProvider(routineId));
      case _SetDeleted():
        Haptics.warn();
        await repo.removeSet(set.id);
        _invalidate(ref);
    }
  }
}

sealed class _SetResult {
  const _SetResult();
}

class _SetSaved extends _SetResult {
  const _SetSaved(this.config);
  final _SetConfig config;
}

class _SetDeleted extends _SetResult {
  const _SetDeleted();
}

class _SetConfig {
  const _SetConfig({
    required this.type,
    required this.targetReps,
    required this.targetRepsMax,
    required this.segmentCount,
  });

  final SetType type;
  final int? targetReps;
  final int? targetRepsMax;
  final int segmentCount;
}

class _SetConfigSheet extends StatefulWidget {
  const _SetConfigSheet({required this.set});

  final PlannedSet set;

  @override
  State<_SetConfigSheet> createState() => _SetConfigSheetState();
}

class _SetConfigSheetState extends State<_SetConfigSheet> {
  late SetType _type = widget.set.setType;
  late int _segmentCount = widget.set.segmentCount;

  // Os alvos são estado da folha, não texto num controller paralelo. Com o
  // controller, o `value` do campo ficava congelado no build inicial e, ao
  // perder o foco, o campo se re-sincronizava com o valor velho — o número
  // digitado era salvo, mas a tela mostrava o antigo de volta.
  late int? _targetReps = widget.set.targetReps;
  late int? _targetRepsMax = widget.set.targetRepsMax;

  void _onTypeChanged(SetType type) {
    setState(() {
      _type = type;
      // Normal e aquecimento têm sempre um segmento; drop e cluster começam
      // com três, que é o mais comum.
      _segmentCount = type.isMultiSegment
          ? (_segmentCount > 1 ? _segmentCount : 3)
          : 1;
    });
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          Space.xxl,
          Space.lg,
          Space.xxl,
          MediaQuery.viewInsetsOf(context).bottom + Space.xxl,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SectionLabel('Tipo'),
            const SizedBox(height: Space.md),
            InsetGroup(
              children: [
                for (final type in SetType.values)
                  AppChoiceRow<SetType>(
                    value: type,
                    groupValue: _type,
                    onChanged: _onTypeChanged,
                    title: type.label,
                    subtitle: type.description,
                  ),
              ],
            ),
            if (_type.isMultiSegment) ...[
              const SizedBox(height: Space.xxl),
              SectionLabel(
                _type == SetType.drop ? 'Quedas de carga' : 'Blocos',
              ),
              const SizedBox(height: Space.md),
              Row(
                children: [
                  Text(
                    '$_segmentCount',
                    style: AppText.numberMedium.copyWith(color: c.textPrimary),
                  ),
                  const Spacer(),
                  AppStepper(
                    stepLabel: 'quantidade',
                    onDecrement: _segmentCount > 2
                        ? () => setState(() => _segmentCount--)
                        : null,
                    onIncrement: _segmentCount < 8
                        ? () => setState(() => _segmentCount++)
                        : null,
                  ),
                ],
              ),
            ],
            const SizedBox(height: Space.xxl),
            const SectionLabel('Alvo de repetições'),
            const SizedBox(height: Space.md),
            Row(
              children: [
                Expanded(
                  child: NumberCell(
                    value: (_targetReps ?? 0).toDouble(),
                    hint: 'de',
                    onChanged: (v) =>
                        setState(() => _targetReps = v == 0 ? null : v.round()),
                  ),
                ),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: NumberCell(
                    value: (_targetRepsMax ?? 0).toDouble(),
                    hint: 'até',
                    onChanged: (v) => setState(
                      () => _targetRepsMax = v == 0 ? null : v.round(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: Space.xxl),
            Row(
              children: [
                // Excluir mora aqui porque o chip não tem espaço para um ⊖ sem
                // virar alvo de toque duvidoso — e porque abrir a série antes
                // de apagá-la já mostra o que se está apagando.
                AppButton(
                  label: 'Excluir série',
                  style: AppButtonStyle.danger,
                  onPressed: () => Navigator.pop(context, const _SetDeleted()),
                ),
                const Spacer(),
                AppButton(
                  label: 'Salvar série',
                  onPressed: () => Navigator.pop(
                    context,
                    _SetSaved(
                      _SetConfig(
                        type: _type,
                        targetReps: _targetReps,
                        targetRepsMax: _targetRepsMax,
                        segmentCount: _segmentCount,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
