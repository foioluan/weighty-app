import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'design/design.dart';
import 'providers.dart';

/// Casca com a barra de abas. Cada aba mantém sua própria pilha e seu scroll,
/// então voltar para "Treinos" não perde onde você estava.
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  /// Índice da aba de exercícios, cujo filtro é zerado a cada entrada.
  static const _catalogTab = 2;

  static const tabs = [
    AppTabItem(
      icon: LucideIcons.dumbbell,
      activeIcon: LucideIcons.dumbbell,
      label: 'Treinos',
    ),
    AppTabItem(
      icon: LucideIcons.history,
      activeIcon: LucideIcons.history,
      label: 'Histórico',
    ),
    AppTabItem(
      icon: LucideIcons.clipboardList,
      activeIcon: LucideIcons.clipboardList,
      label: 'Exercícios',
    ),
    AppTabItem(
      icon: LucideIcons.settings2,
      activeIcon: LucideIcons.settings2,
      label: 'Ajustes',
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.colors.bg,
      body: navigationShell,
      bottomNavigationBar: AppTabBar(
        items: tabs,
        currentIndex: navigationShell.currentIndex,
        onTap: (index) {
          Haptics.tick();
          // A aba guarda o estado dela (é o ponto da casca), mas o filtro de
          // busca é a exceção: abrir a lista de exercícios sempre começa
          // limpa, senão a lista aparece cortada por uma busca antiga.
          // Entrar num exercício e voltar não passa por aqui, então o filtro
          // sobrevive à navegação dentro da própria aba.
          if (index == _catalogTab) {
            ref.invalidate(catalogSearchProvider);
            ref.invalidate(catalogGroupProvider);
          }
          navigationShell.goBranch(
            index,
            // Tocar na aba já ativa volta para a raiz dela.
            initialLocation: index == navigationShell.currentIndex,
          );
        },
      ),
    );
  }
}
