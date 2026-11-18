import 'package:flutter/material.dart';

import '../../theme.dart';
import 'glass.dart';

class AppTabItem {
  const AppTabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });

  final IconData icon;
  final IconData activeIcon;
  final String label;
}

/// Barra de abas em cápsula de vidro, flutuando sobre o conteúdo — a barra do
/// iOS 26.
///
/// A aba ativa fica numa pílula que desliza de uma aba para a outra. A lista
/// passa por baixo da cápsula, e é sobre ela que o vidro mostra o que é: o
/// conteúdo colorido aparece desfocado através da barra.
class AppTabBar extends StatelessWidget {
  /// Altura da cápsula.
  static const height = 62.0;

  /// Folga entre a cápsula e as bordas da tela.
  static const _sideMargin = 16.0;
  static const _bottomMargin = 8.0;

  /// Espaço que a barra ocupa na base, já com a área segura. Público porque a
  /// casca precisa dele para dizer ao toast quanto espaço reservar.
  static double reservedHeight(BuildContext context) =>
      height + _bottomMargin + MediaQuery.paddingOf(context).bottom;

  const AppTabBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
  });

  final List<AppTabItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final n = items.length;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          _sideMargin,
          0,
          _sideMargin,
          _bottomMargin,
        ),
        child: SizedBox(
          height: height,
          child: GlassSurface.capsule(
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Stack(
                children: [
                  // A pílula da aba ativa. Mola com um leve passar do ponto:
                  // ela "chega" na aba em vez de só parar.
                  AnimatedAlign(
                    duration: const Duration(milliseconds: 380),
                    curve: const Cubic(0.3, 1.35, 0.45, 1),
                    alignment: Alignment(
                      n == 1 ? 0 : -1 + 2 * currentIndex / (n - 1),
                      0,
                    ),
                    child: FractionallySizedBox(
                      widthFactor: 1 / n,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: ShapeDecoration(
                          color: c.fill,
                          shape: const StadiumBorder(),
                        ),
                      ),
                    ),
                  ),
                  Row(
                    children: [
                      for (var i = 0; i < n; i++)
                        Expanded(
                          child: _Tab(
                            item: items[i],
                            selected: i == currentIndex,
                            onTap: () => onTap(i),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final AppTabItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = selected ? c.accent : c.textPrimary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: PressScale(
        onTap: onTap,
        scale: 0.9,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? item.activeIcon : item.icon, size: 22, color: tone),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.fade,
              softWrap: false,
              style: AppText.caption2.copyWith(
                color: tone,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
