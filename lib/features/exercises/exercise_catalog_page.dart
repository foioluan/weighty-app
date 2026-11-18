import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/design/design.dart';
import '../../app/providers.dart';
import '../../data/db/database.dart';
import '../../domain/models/enums.dart';

/// Catálogo de exercícios. Como aba, mostra título grande; como seletor (aberto
/// pelo editor de treino), vira uma tela empilhada com barra e botão de voltar.
class ExerciseCatalogPage extends ConsumerStatefulWidget {
  const ExerciseCatalogPage({
    super.key,
    this.selecting = false,
    this.title = 'Escolher exercício',
    this.selectIcon = LucideIcons.plus,
  });

  final bool selecting;

  /// Título da barra em modo de escolha — muda conforme o motivo da escolha
  /// (adicionar um exercício ao treino, ou substituir um que já está lá).
  final String title;

  /// Ícone no fim de cada linha em modo de escolha. Um "+" só faz sentido
  /// quando a escolha adiciona; substituindo, ele contradiz o título.
  final IconData selectIcon;

  @override
  ConsumerState<ExerciseCatalogPage> createState() =>
      _ExerciseCatalogPageState();
}

class _ExerciseCatalogPageState extends ConsumerState<ExerciseCatalogPage> {
  late final TextEditingController _search;

  @override
  void initState() {
    super.initState();
    // Semeado com o valor atual do provider para campo e filtro nunca
    // divergirem. Com os providers em autoDispose isso é '' na entrada, mas
    // deixa a tela correta mesmo se o filtro sobreviver por outro caminho.
    _search = TextEditingController(text: ref.read(catalogSearchProvider));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // A casca zera o filtro ao entrar na aba; sem isto o texto continuaria na
    // tela sem filtro por trás — o inverso exato do bug original.
    ref.listen<String>(catalogSearchProvider, (_, next) {
      if (_search.text != next) _search.text = next;
    });

    final catalog = ref.watch(exerciseCatalogProvider);
    final group = ref.watch(catalogGroupProvider);
    final search = ref.watch(catalogSearchProvider);
    final filtering = search.isNotEmpty || group != null;

    return AppScaffold(
      largeTitle: widget.selecting ? null : 'Exercícios',
      title: widget.selecting ? widget.title : null,
      showBack: widget.selecting,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.page,
              Space.xs,
              Space.page,
              Space.md,
            ),
            child: AppTextField(
              controller: _search,
              hint: 'Buscar exercício',
              prefixIcon: LucideIcons.search,
              textCapitalization: TextCapitalization.none,
              onChanged: (v) =>
                  ref.read(catalogSearchProvider.notifier).state = v,
              onClear: search.isEmpty
                  ? null
                  : () {
                      _search.clear();
                      ref.read(catalogSearchProvider.notifier).state = '';
                    },
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: SizedBox(
            height: 40,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: Space.page),
              children: [
                AppChip(
                  label: 'Todos',
                  selected: group == null,
                  onTap: () =>
                      ref.read(catalogGroupProvider.notifier).state = null,
                ),
                for (final g in MuscleGroup.values)
                  Padding(
                    padding: const EdgeInsets.only(left: Space.sm),
                    child: AppChip(
                      label: g.label,
                      selected: group == g,
                      accent: c.forMuscleGroup(g),
                      onTap: () =>
                          ref.read(catalogGroupProvider.notifier).state =
                              group == g ? null : g,
                    ),
                  ),
              ],
            ),
          ),
        ),
        catalog.when(
          loading: () => const SliverToBoxAdapter(),
          error: (e, _) => AppSliverFill(
            child: EmptyState(title: 'Erro', message: '$e'),
          ),
          data: (items) => AppSliverList(
            padding: const EdgeInsets.fromLTRB(
              Space.page,
              Space.lg,
              Space.page,
              0,
            ),
            children: [
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: Space.xxl),
                  child: EmptyState(
                    title: 'Nada encontrado',
                    message: filtering
                        ? 'Nenhum exercício com esse filtro. Limpe a busca '
                              'ou crie um novo abaixo.'
                        : 'Crie um exercício novo abaixo.',
                  ),
                )
              else
                InsetGroup(
                  separatorIndent: 0,
                  children: [
                    for (final exercise in items)
                      _ExerciseRow(
                        exercise,
                        selecting: widget.selecting,
                        selectIcon: widget.selectIcon,
                      ),
                  ],
                ),
              const SizedBox(height: Space.xl),
              InsetGroup(
                children: [
                  AppRow(
                    title: 'Novo exercício',
                    titleColor: c.accent,
                    leading: Icon(LucideIcons.plus, size: 20, color: c.accent),
                    onTap: () => _createExercise(context, ref),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ExerciseRow extends ConsumerWidget {
  const _ExerciseRow(
    this.exercise, {
    required this.selecting,
    required this.selectIcon,
  });

  final Exercise exercise;
  final bool selecting;
  final IconData selectIcon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;

    return AppRow(
      minHeight: 58,
      title: exercise.name,
      subtitle: '${exercise.muscleGroup.label} · ${exercise.equipment.label}',
      leading: ExerciseAvatar(name: exercise.name, group: exercise.muscleGroup),
      showChevron: !selecting,
      trailing: selecting
          ? Icon(selectIcon, size: 19, color: c.accent)
          : (exercise.isCustom
                ? AppIconButton(
                    icon: LucideIcons.circleMinus,
                    size: 18,
                    tapSize: 34,
                    label: 'Arquivar ${exercise.name}',
                    onPressed: () => _archive(context, ref),
                  )
                : null),
      onTap: selecting
          ? () => Navigator.pop(context, exercise)
          : () => context.push('/exercicio/${exercise.id}'),
    );
  }

  Future<void> _archive(BuildContext context, WidgetRef ref) async {
    final confirmed = await showAppDialog<bool>(
      context,
      title: 'Arquivar ${exercise.name}?',
      message:
          'Ele sai das listas, mas o histórico das sessões em que aparece '
          'continua no app.',
      actions: const [
        AppDialogAction(label: 'Cancelar', value: false),
        AppDialogAction(
          label: 'Arquivar',
          value: true,
          isDestructive: true,
          isPreferred: true,
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;

    // Esta linha sai da lista ao arquivar, levando junto o contexto do aviso.
    final toast = AppToast.capture(context);
    await ref.read(exerciseRepositoryProvider).archive(exercise.id);
    toast.show('${exercise.name} arquivado.');
  }
}

Future<void> _createExercise(BuildContext context, WidgetRef ref) async {
  final result = await showAppSheet<(String, MuscleGroup, Equipment)>(
    context,
    title: 'Novo exercício',
    builder: (context) => const _NewExerciseSheet(),
  );
  if (result == null) return;

  final (name, group, equipment) = result;
  await ref
      .read(exerciseRepositoryProvider)
      .create(name: name, group: group, equipment: equipment);

  if (context.mounted) {
    AppToast.show(context, '$name criado.', kind: ToastKind.success);
  }
}

class _NewExerciseSheet extends StatefulWidget {
  const _NewExerciseSheet();

  @override
  State<_NewExerciseSheet> createState() => _NewExerciseSheetState();
}

class _NewExerciseSheetState extends State<_NewExerciseSheet> {
  final _controller = TextEditingController();
  var _group = MuscleGroup.peito;
  var _equipment = Equipment.barra;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
            AppTextField(
              controller: _controller,
              autofocus: true,
              hint: 'Nome do exercício',
            ),
            const SizedBox(height: Space.xxl),
            Text(
              'GRUPO MUSCULAR',
              style: AppText.overline.copyWith(color: c.textTertiary),
            ),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final g in MuscleGroup.values)
                  AppChip(
                    label: g.label,
                    selected: _group == g,
                    accent: c.forMuscleGroup(g),
                    onTap: () => setState(() => _group = g),
                  ),
              ],
            ),
            const SizedBox(height: Space.xxl),
            Text(
              'EQUIPAMENTO',
              style: AppText.overline.copyWith(color: c.textTertiary),
            ),
            const SizedBox(height: Space.md),
            Wrap(
              spacing: Space.sm,
              runSpacing: Space.sm,
              children: [
                for (final e in Equipment.values)
                  AppChip(
                    label: e.label,
                    selected: _equipment == e,
                    onTap: () => setState(() => _equipment = e),
                  ),
              ],
            ),
            const SizedBox(height: Space.xxl),
            Align(
              alignment: Alignment.centerRight,
              child: AppButton(
                label: 'Criar exercício',
                onPressed: () {
                  final name = _controller.text.trim();
                  if (name.isEmpty) {
                    AppToast.show(
                      context,
                      'Dê um nome ao exercício.',
                      kind: ToastKind.error,
                    );
                    return;
                  }
                  Navigator.pop(context, (name, _group, _equipment));
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
