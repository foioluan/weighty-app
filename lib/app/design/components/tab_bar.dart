import 'package:flutter/material.dart';

import '../../theme.dart';

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

/// Barra de abas inferior.
///
/// Não é o `NavigationBar` do Material: aquele tem 80 px de altura, pílula de
/// destaque atrás do ícone e animação própria — a assinatura visual do Android
/// que estávamos tentando sair. Este tem 54 px, hairline no topo e marca a aba
/// ativa só por cor e peso.
class AppTabBar extends StatelessWidget {
  /// Altura da barra sem a área segura. Pública porque a casca precisa dela
  /// para dizer ao toast quanto espaço reservar na base.
  static const height = 54.0;

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

    return Container(
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(top: BorderSide(color: c.hairline, width: 0.5)),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  child: _Tab(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () => onTap(i),
                  ),
                ),
            ],
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
    final tone = selected ? c.accent : c.textTertiary;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(selected ? item.activeIcon : item.icon, size: 21, color: tone),
            const SizedBox(height: 3),
            Text(
              item.label,
              style: AppText.caption.copyWith(
                color: tone,
                fontSize: 10,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
