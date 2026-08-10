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
    final c = context.colors;
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
      body: detail.when(
        loading: () => const SizedBox.shrink(),
        error: (e, _) => EmptyState(title: 'Erro', message: '$e'),
        data: (data) {
          if (data == null) {
            return const EmptyState(
              title: 'Treino não encontrado',
              message: 'Ele pode ter sido arquivado.',
            );
          }

          return ReorderableListView(
            padding: const EdgeInsets.fromLTRB(
              Space.xl,
              Space.lg,
              Space.xl,
              Space.xxxl,
            ),
            footer: Padding(
              padding: const EdgeInsets.only(top: Space.xl),
              child: InsetGroup(
                children: [
                  AppRow(
                    title: 'Adicionar exercício',
                    titleColor: c.accent,
                    leading: Icon(LucideIcons.plus, size: 19, color: c.accent),
                    onTap: () => _addExercise(context, ref),
                  ),
                ],
              ),
            ),
            onReorderItem: (oldIndex, newIndex) =>
                _reorder(ref, data, oldIndex, newIndex),
            children: [
              if (data.exercises.isEmpty)
                const Padding(
                  key: ValueKey('empty'),
                  padding: EdgeInsets.only(top: Space.xxxl),
                  child: EmptyState(
                    title: 'Nenhum exercício',
                    message:
                        'Adicione exercícios abaixo para montar este treino.',
                  ),
                )
              else
                for (var i = 0; i < data.exercises.length; i++)
                  Padding(
                    key: ValueKey(data.exercises[i].link.id),
                    padding: const EdgeInsets.only(bottom: Space.lg),
                    child: _ExerciseCard(
                      routineId: routineId,
                      detail: data.exercises[i],
                      index: i,
                    ),
                  ),
            ],
          );
        },
      ),
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

  Future<void> _addExercise(BuildContext context, WidgetRef ref) async {
    final exercise = await Navigator.push<Exercise>(
      context,
      MaterialPageRoute(
        builder: (_) => const ExerciseCatalogPage(selecting: true),
      ),
    );
    if (exercise == null) return;

    await ref
        .read(routineRepositoryProvider)
        .addExercise(routineId, exercise.id);
    ref.invalidate(routineDetailProvider(routineId));
    ref.invalidate(routineSummariesProvider);
  }
}

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

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.hairline, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          // Barra da cor do grupo muscular na borda superior: identifica o
          // exercício de relance sem ocupar espaço de texto.
          Container(
            height: 2,
            color: c.forMuscleGroup(detail.exercise.muscleGroup),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Space.lg, Space.md, Space.sm, 0),
            child: Row(
              children: [
                ReorderableDragStartListener(
                  index: index,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: Space.md),
                    child: Icon(
                      LucideIcons.gripVertical,
                      size: 17,
                      color: c.textGhost,
                    ),
                  ),
                ),
                const SizedBox(width: Space.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.exercise.name,
                        style: AppText.title2.copyWith(color: c.textPrimary),
                      ),
                      Text(
                        detail.exercise.muscleGroup.label,
                        style: AppText.caption.copyWith(color: c.textTertiary),
                      ),
                    ],
                  ),
                ),
                AppIconButton(
                  icon: LucideIcons.x,
                  size: 17,
                  tapSize: 38,
                  label: 'Remover ${detail.exercise.name} do treino',
                  onPressed: () => _removeExercise(context, ref),
                ),
              ],
            ),
          ),
          const SizedBox(height: Space.sm),
          for (var i = 0; i < detail.sets.length; i++)
            _SetRow(routineId: routineId, set: detail.sets[i], number: i + 1),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.md,
              Space.xs,
              Space.md,
              Space.md,
            ),
            child: Row(
              children: [
                AppButton(
                  label: 'Série',
                  icon: LucideIcons.plus,
                  style: AppButtonStyle.plain,
                  compact: true,
                  onPressed: () => _addSet(ref),
                ),
                if (detail.sets.isNotEmpty)
                  AppButton(
                    label: 'Duplicar última',
                    style: AppButtonStyle.plain,
                    compact: true,
                    onPressed: () => _duplicateLast(ref),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _removeExercise(BuildContext context, WidgetRef ref) async {
    await ref.read(routineRepositoryProvider).removeExercise(detail.link.id);
    ref.invalidate(routineDetailProvider(routineId));
    ref.invalidate(routineSummariesProvider);
  }

  Future<void> _addSet(WidgetRef ref) async {
    await ref
        .read(routineRepositoryProvider)
        .addSet(detail.link.id, targetReps: 10);
    ref.invalidate(routineDetailProvider(routineId));
    ref.invalidate(routineSummariesProvider);
  }

  /// Montar "4 x 10" fica em dois toques em vez de quatro.
  Future<void> _duplicateLast(WidgetRef ref) async {
    final last = detail.sets.last;
    await ref
        .read(routineRepositoryProvider)
        .addSet(
          detail.link.id,
          type: last.setType,
          targetReps: last.targetReps,
          targetRepsMax: last.targetRepsMax,
          segmentCount: last.segmentCount,
        );
    ref.invalidate(routineDetailProvider(routineId));
    ref.invalidate(routineSummariesProvider);
  }
}

class _SetRow extends ConsumerWidget {
  const _SetRow({
    required this.routineId,
    required this.set,
    required this.number,
  });

  final int routineId;
  final PlannedSet set;
  final int number;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final isWarmup = set.setType == SetType.aquecimento;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _editSet(context, ref),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.lg,
          Space.xs,
          Space.sm,
          Space.xs,
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              child: Text(
                isWarmup ? 'aq' : '$number',
                style: AppText.numberSmall.copyWith(color: c.textTertiary),
              ),
            ),
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                set.setType.label,
                style: AppText.callout.copyWith(
                  color: isWarmup ? c.textTertiary : c.textPrimary,
                ),
              ),
            ),
            Text(
              _repsLabel(set),
              style: AppText.footnote.copyWith(color: c.textTertiary),
            ),
            const SizedBox(width: Space.md),
            AppIconButton(
              icon: LucideIcons.circleMinus,
              size: 16,
              tapSize: 34,
              label: 'Remover série $number',
              onPressed: () async {
                await ref.read(routineRepositoryProvider).removeSet(set.id);
                ref.invalidate(routineDetailProvider(routineId));
                ref.invalidate(routineSummariesProvider);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editSet(BuildContext context, WidgetRef ref) async {
    final result = await showAppSheet<_SetConfig>(
      context,
      title: 'Série $number',
      builder: (context) => _SetConfigSheet(set: set),
    );
    if (result == null) return;

    await ref
        .read(routineRepositoryProvider)
        .updateSet(
          set.id,
          type: result.type,
          targetReps: result.targetReps,
          targetRepsMax: result.targetRepsMax,
          segmentCount: result.segmentCount,
        );
    ref.invalidate(routineDetailProvider(routineId));
  }
}

String _repsLabel(PlannedSet set) {
  final min = set.targetReps;
  final max = set.targetRepsMax;
  final reps = switch ((min, max)) {
    (null, _) => 'sem alvo',
    (final a?, null) => '$a reps',
    (final a?, final b?) => '$a-$b reps',
  };

  if (set.setType.isMultiSegment) {
    final unit = set.setType == SetType.drop ? 'quedas' : 'blocos';
    return '${set.segmentCount} $unit · $reps';
  }
  return reps;
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
            Text(
              'TIPO',
              style: AppText.overline.copyWith(color: c.textTertiary),
            ),
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
              Text(
                _type == SetType.drop ? 'QUEDAS DE CARGA' : 'BLOCOS',
                style: AppText.overline.copyWith(color: c.textTertiary),
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
            Text(
              'ALVO DE REPETIÇÕES',
              style: AppText.overline.copyWith(color: c.textTertiary),
            ),
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
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: 'Salvar série',
                onPressed: () => Navigator.pop(
                  context,
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
      ),
    );
  }
}
