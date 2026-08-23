import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme.dart';

/// Barra de navegação compacta (48 px). O Material 3 usa 64 e o large app bar
/// chega a 152 — parte do "grande demais" vinha daí. A hierarquia da tela vem
/// do título grande dentro do conteúdo, não da altura da barra.
class AppNavBar extends StatelessWidget {
  const AppNavBar({
    super.key,
    this.title,
    this.actions = const [],
    this.showBack = true,
    this.onBack,
  });

  final String? title;
  final List<Widget> actions;
  final bool showBack;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final canPop = showBack && (onBack != null || Navigator.canPop(context));

    return Container(
      height: 48,
      decoration: BoxDecoration(
        color: c.bg,
        border: Border(bottom: BorderSide(color: c.hairline, width: 0.5)),
      ),
      child: Row(
        children: [
          if (canPop)
            _NavAction(
              icon: LucideIcons.chevronLeft,
              size: 26,
              onTap: onBack ?? () => Navigator.maybePop(context),
              semanticLabel: 'Voltar',
            )
          else
            const SizedBox(width: Space.xl),
          Expanded(
            child: Text(
              title ?? '',
              style: AppText.title2.copyWith(color: c.textPrimary),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          ...actions,
          const SizedBox(width: Space.sm),
        ],
      ),
    );
  }
}

/// Ícone da barra de navegação. Área de toque de 44 px com o desenho em 20 —
/// o alvo é grande, o traço é leve.
class _NavAction extends StatelessWidget {
  const _NavAction({
    required this.icon,
    required this.onTap,
    required this.semanticLabel,
    this.size = 20,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Icon(icon, size: size, color: context.colors.textSecondary),
          ),
        ),
      ),
    );
  }
}

class AppNavIcon extends StatelessWidget {
  const AppNavIcon({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return _NavAction(icon: icon, onTap: onTap, semanticLabel: label);
  }
}

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    this.title,
    this.largeTitle,
    this.largeTitleContent,
    this.subtitle,
    this.backLabel,
    this.actions = const [],
    this.showBack = true,
    required this.body,
    this.bottomBar,
    this.banner,
  });

  final String? title;

  /// Título grande no topo do conteúdo, para as telas raiz das abas. Quando
  /// presente, a barra de navegação some: numa aba não há para onde voltar, e
  /// uma barra de 48 px só com título repetiria a informação.
  final String? largeTitle;

  /// Ocupa o lugar do título grande com um desenho em vez de texto. É o que
  /// deixa a home mostrar a marca onde repetiria o nome da aba.
  final Widget? largeTitleContent;

  /// Linha embaixo do título grande. Existe para a tela de detalhe poder dizer
  /// a data sem gastar uma linha do corpo.
  final String? subtitle;

  /// Nome de onde a tela volta — "Histórico", "Treinos". Preenchê-lo troca a
  /// barra de navegação por um link discreto acima do título grande.
  ///
  /// Era a barra de 48 px com hairline e título pequeno a única forma de
  /// Material que sobrou no app: as abas já resolvem o topo com título grande
  /// dentro do conteúdo, e a tela de detalhe repetia a informação numa moldura
  /// que nada mais usa. Além disso um link nomeado diz *para onde* volta, o que
  /// uma seta sozinha não faz.
  final String? backLabel;

  final List<Widget> actions;
  final bool showBack;
  final Widget body;

  /// Ação fixa no rodapé. Substitui o FloatingActionButton: numa tela usada de
  /// pé, o polegar alcança a base, e o botão nunca cobre conteúdo.
  final Widget? bottomBar;

  /// Faixa logo abaixo da barra (ex.: treino em andamento).
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            if (largeTitle != null || largeTitleContent != null) ...[
              if (backLabel != null)
                // A Column da casca centraliza por padrão; o voltar precisa
                // encostar na mesma margem esquerda do título.
                Align(
                  alignment: Alignment.centerLeft,
                  child: AppBackLink(label: backLabel!),
                ),
              Padding(
                padding: EdgeInsets.fromLTRB(
                  Space.xl,
                  // Com o voltar acima, o título já tem respiro: repetir os
                  // 20 px daria um vão grande demais no topo.
                  backLabel == null ? Space.xxl : Space.xs,
                  Space.sm,
                  Space.lg,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child:
                          largeTitleContent ??
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                largeTitle!,
                                style: AppText.largeTitle.copyWith(
                                  color: c.textPrimary,
                                ),
                              ),
                              if (subtitle != null) ...[
                                const SizedBox(height: 1),
                                Text(
                                  subtitle!,
                                  style: AppText.footnote.copyWith(
                                    color: c.textTertiary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                    ),
                    ...actions,
                  ],
                ),
              ),
            ] else
              AppNavBar(title: title, actions: actions, showBack: showBack),
            ?banner,
            Expanded(child: body),
            if (bottomBar != null)
              Container(
                decoration: BoxDecoration(
                  color: c.bg,
                  border: Border(
                    top: BorderSide(color: c.hairline, width: 0.5),
                  ),
                ),
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      Space.xl,
                      Space.md,
                      Space.xl,
                      Space.md,
                    ),
                    child: bottomBar,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// "‹ Histórico" — o voltar das telas de detalhe.
///
/// Fixo, acima do título grande e fora do conteúdo que rola: se ele subisse com
/// a lista, sobraria só o gesto do sistema para voltar.
///
/// Público porque a tela de imagem não usa AppScaffold — ela é um card em tela
/// cheia — e precisa do mesmo voltar para não virar a exceção da regra.
class AppBackLink extends StatelessWidget {
  const AppBackLink({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Semantics(
      button: true,
      label: 'Voltar para $label',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => Navigator.maybePop(context),
        child: Padding(
          // Alvo de 40 px de altura sem desenhar nada: o texto é pequeno, mas o
          // toque não pode ser.
          padding: const EdgeInsets.fromLTRB(Space.lg, Space.lg, Space.xl, 0),
          child: SizedBox(
            height: 28,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.chevronLeft, size: 16, color: c.accent),
                const SizedBox(width: 1),
                Text(label, style: AppText.footnote.copyWith(color: c.accent)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Rótulo de seção em maiúsculas, no estilo das listas agrupadas do iOS.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.xs,
        Space.xxl,
        Space.xs,
        Space.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text.toUpperCase(),
              style: AppText.overline.copyWith(color: c.textTertiary),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Cartão de bloco único: mesma superfície e mesmo hairline do [InsetGroup],
/// sem as linhas divisórias.
///
/// Existe porque a decoração vinha sendo copiada em cada tela que precisava de
/// um cartão que não fosse lista. Copiar seis linhas de `BoxDecoration` é como
/// uma superfície começa a divergir do resto.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final content = Padding(padding: padding, child: child);

    return Container(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.hairline, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? content
          : _Pressable(onTap: onTap!, child: content),
    );
  }
}

/// Agrupamento de lista: um cartão com hairlines entre as linhas. É a estrutura
/// que dá o ar de app de sistema em vez de pilha de Cards do Material.
class InsetGroup extends StatelessWidget {
  const InsetGroup({
    super.key,
    required this.children,
    this.separatorIndent = Space.xl,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;
  final double separatorIndent;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rows = <Widget>[];

    for (var i = 0; i < children.length; i++) {
      if (i > 0) {
        rows.add(
          Padding(
            padding: EdgeInsets.only(left: separatorIndent),
            child: Container(height: 0.5, color: c.hairline),
          ),
        );
      }
      rows.add(children[i]);
    }

    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(Radii.lg),
        border: Border.all(color: c.hairline, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      // mainAxisSize.min: dentro de uma lista a altura já é livre e isso não
      // muda nada, mas dentro de uma folha — onde a altura é limitada — um
      // Column padrão estica e a folha ocupa a tela inteira.
      child: Column(mainAxisSize: MainAxisSize.min, children: rows),
    );
  }
}

/// Linha de lista. Sem `ListTile`: a altura mínima dele é 56 e o padding é
/// generoso demais para a densidade que esta tela precisa.
class AppRow extends StatelessWidget {
  const AppRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.titleColor,
    this.minHeight = Heights.row,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool showChevron;
  final Color? titleColor;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xl,
        vertical: Space.md,
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: Space.lg)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: AppText.body.copyWith(
                    color: titleColor ?? c.textPrimary,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 1),
                  Text(
                    subtitle!,
                    style: AppText.footnote.copyWith(color: c.textTertiary),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: Space.md), trailing!],
          if (showChevron) ...[
            const SizedBox(width: Space.xs),
            Icon(LucideIcons.chevronRight, size: 18, color: c.textGhost),
          ],
        ],
      ),
    );

    if (onTap == null) {
      return ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: content,
      );
    }

    return _Pressable(
      onTap: onTap!,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight),
        child: content,
      ),
    );
  }
}

/// Realce de toque discreto, no lugar do splash do Material — que é o efeito
/// que mais entrega "app Android padrão".
class _Pressable extends StatefulWidget {
  const _Pressable({required this.child, required this.onTap});

  final Widget child;
  final VoidCallback onTap;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      child: AnimatedContainer(
        duration: AppDurations.fast,
        color: _down ? context.colors.hairline : Colors.transparent,
        child: widget.child,
      ),
    );
  }
}

/// Estado vazio: título, uma linha de explicação e, quando faz sentido, a ação.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.title,
    required this.message,
    this.icon,
  });

  final String title;
  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxxl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 30, color: c.textGhost),
              const SizedBox(height: Space.xl),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.title2.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: Space.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.callout.copyWith(
                color: c.textTertiary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
