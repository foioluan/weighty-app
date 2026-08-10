import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/exercises/exercise_catalog_page.dart';
import '../features/history/exercise_progress_page.dart';
import '../features/history/history_page.dart';
import '../features/history/session_summary_page.dart';
import '../features/routines/routine_editor_page.dart';
import '../features/routines/routines_page.dart';
import '../features/session/session_page.dart';
import '../features/settings/settings_page.dart';
import '../features/share/session_share_page.dart';
import 'design/components/motion.dart';
import 'shell.dart';

final _rootKey = GlobalKey<NavigatorState>();

/// Nome de onde a tela foi aberta, para o link de voltar poder dizer o destino.
///
/// Vem na query e não fixo no código porque a mesma tela é aberta de lugares
/// diferentes: o resumo do treino abre a progressão de um exercício, e a aba de
/// exercícios também.
String _from(GoRouterState state, String fallback) =>
    state.uri.queryParameters['de'] ?? fallback;

/// As quatro abas ficam dentro da casca; as telas de detalhe são rotas de topo,
/// então cobrem a barra de abas. É proposital na sessão de treino: durante a
/// série não deve haver nada convidando a sair da tela.
final router = GoRouter(
  navigatorKey: _rootKey,
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(navigationShell: shell),
      branches: [
        StatefulShellBranch(
          routes: [GoRoute(path: '/', builder: (_, _) => const RoutinesPage())],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/historico', builder: (_, _) => const HistoryPage()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/exercicios',
              builder: (_, _) => const ExerciseCatalogPage(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/ajustes', builder: (_, _) => const SettingsPage()),
          ],
        ),
      ],
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: '/treino/:id/editar',
      pageBuilder: (_, state) => SpringPage(
        child: RoutineEditorPage(
          routineId: int.parse(state.pathParameters['id']!),
          backLabel: _from(state, 'Treinos'),
        ),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: '/treino/:id',
      pageBuilder: (_, state) => SpringPage(
        child: SessionPage(sessionId: int.parse(state.pathParameters['id']!)),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: '/sessao/:id',
      pageBuilder: (_, state) => SpringPage(
        child: SessionSummaryPage(
          sessionId: int.parse(state.pathParameters['id']!),
          backLabel: _from(state, 'Treinos'),
        ),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: '/sessao/:id/imagem',
      pageBuilder: (_, state) => SpringPage(
        child: SessionSharePage(
          sessionId: int.parse(state.pathParameters['id']!),
          backLabel: _from(state, 'Resumo'),
        ),
      ),
    ),
    GoRoute(
      parentNavigatorKey: _rootKey,
      path: '/exercicio/:id',
      pageBuilder: (_, state) => SpringPage(
        child: ExerciseProgressPage(
          exerciseId: int.parse(state.pathParameters['id']!),
          backLabel: _from(state, 'Exercícios'),
        ),
      ),
    ),
  ],
);
