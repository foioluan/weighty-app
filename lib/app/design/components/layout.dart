import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme.dart';
import 'glass.dart';

/// Altura da faixa fixa do topo: o círculo de vidro de 44 com folga.
const _topBarHeight = 52.0;

/// Ação do topo da tela, em círculo de vidro.
///
/// No iOS 26 os controles da barra deixaram de ser ícones soltos e viraram
/// botões de vidro flutuando sobre o conteúdo — que agora passa por baixo
/// deles ao rolar.
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
    return GlassCircleButton(icon: icon, onTap: onTap, label: label);
  }
}

class AppScaffold extends StatefulWidget {
  const AppScaffold({
    super.key,
    this.title,
    this.largeTitle,
    this.largeTitleContent,
    this.subtitle,
    this.backLabel,
    this.actions = const [],
    this.showBack = true,
    this.body,
    this.slivers,
    this.bottomBar,
    this.banner,
    this.scrollController,
  }) : assert(
         (body == null) != (slivers == null),
         'Passe body ou slivers, não os dois.',
       );

  /// Título pequeno, centralizado na faixa do topo. Com [largeTitle] ele só
  /// aparece depois que o título grande sai de vista.
  final String? title;

  /// Título grande no topo do conteúdo. Rola junto com a lista e, quando sai
  /// de vista, reaparece pequeno e centralizado no topo — o comportamento das
  /// telas do iOS. Exige [slivers].
  final String? largeTitle;

  /// Ocupa o lugar do título grande com um desenho em vez de texto. É o que
  /// deixa a home mostrar a marca onde repetiria o nome da aba.
  final Widget? largeTitleContent;

  /// Linha embaixo do título grande. Existe para a tela de detalhe poder dizer
  /// a data sem gastar uma linha do corpo.
  final String? subtitle;

  /// Nome de onde a tela volta — "Histórico", "Treinos". Não aparece escrito:
  /// o voltar é um círculo de vidro, como no iOS 26, e o nome vai para o
  /// leitor de tela ("Voltar para Histórico").
  final String? backLabel;

  /// Botões do topo, à direita. Use [AppNavIcon] ou [GlassTextButton].
  final List<Widget> actions;
  final bool showBack;

  /// Conteúdo que não rola junto com um título grande — a sessão de treino,
  /// que é um carrossel de exercícios.
  final Widget? body;

  /// Conteúdo das telas com título grande. O título vira o primeiro sliver,
  /// e por isso rola junto com a lista.
  final List<Widget>? slivers;

  /// Ação fixa no rodapé. Substitui o FloatingActionButton: numa tela usada de
  /// pé, o polegar alcança a base, e o botão nunca cobre conteúdo.
  final Widget? bottomBar;

  /// Faixa logo abaixo do topo (ex.: treino em andamento).
  final Widget? banner;

  /// Controlador da lista de [slivers]. Existe para a folha de escolha de
  /// exercício: ela precisa ligar a rolagem da lista ao arrasto de fechar.
  final ScrollController? scrollController;

  @override
  State<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends State<AppScaffold> {
  /// Quanto a lista principal já rolou. Controla o degradê do topo e o
  /// aparecimento do título pequeno sem reconstruir a tela inteira.
  final _offset = ValueNotifier<double>(0);

  @override
  void dispose() {
    _offset.dispose();
    super.dispose();
  }

  bool _onScroll(ScrollNotification n) {
    // Só a lista da própria tela: um carrossel horizontal de chips lá dentro
    // também emite, e não pode mexer no topo.
    if (n.depth == 0 && n.metrics.axis == Axis.vertical) {
      _offset.value = n.metrics.pixels;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final w = widget;
    final canPop =
        w.showBack && (w.backLabel != null || Navigator.canPop(context));

    final topBar = _TopBar(
      back: canPop
          ? GlassCircleButton(
              icon: LucideIcons.chevronLeft,
              iconSize: 24,
              label: w.backLabel == null
                  ? 'Voltar'
                  : 'Voltar para ${w.backLabel}',
              onTap: () => Navigator.maybePop(context),
            )
          : null,
      title: w.title ?? w.largeTitle,
      // Sem título grande, o subtítulo vai para baixo do título pequeno — é
      // onde a sessão mostra o cronômetro.
      subtitle: w.largeTitle == null ? w.subtitle : null,
      // Sem título grande, o pequeno é o título da tela e fica sempre visível.
      titleVisibility: w.slivers != null && w.title == null ? _offset : null,
      actions: w.actions,
    );

    final Widget content;
    if (w.slivers != null) {
      content = _SliverLayout(
        offset: _offset,
        onScroll: _onScroll,
        topBar: topBar,
        header: _largeTitle(context),
        banner: w.banner,
        slivers: w.slivers!,
        bottomBar: w.bottomBar,
        controller: w.scrollController,
      );
    } else {
      content = SafeArea(
        bottom: false,
        child: Column(
          children: [
            topBar,
            ?w.banner,
            Expanded(child: w.body!),
            if (w.bottomBar != null) _BottomBar(child: w.bottomBar!),
          ],
        ),
      );
    }

    return Scaffold(backgroundColor: c.bg, body: content);
  }

  Widget? _largeTitle(BuildContext context) {
    final w = widget;
    if (w.largeTitle == null && w.largeTitleContent == null) return null;
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.page,
        Space.xs,
        Space.page,
        Space.lg,
      ),
      child:
          w.largeTitleContent ??
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                w.largeTitle!,
                style: AppText.largeTitle.copyWith(color: c.textPrimary),
              ),
              if (w.subtitle != null) ...[
                const SizedBox(height: 2),
                Text(
                  w.subtitle!,
                  style: AppText.subheadline.copyWith(color: c.textSecondary),
                ),
              ],
            ],
          ),
    );
  }
}

/// Tela com título grande: a lista ocupa tudo e passa por baixo do topo e da
/// barra de abas; o topo é uma faixa fixa por cima, com os botões de vidro.
class _SliverLayout extends StatelessWidget {
  const _SliverLayout({
    required this.offset,
    required this.onScroll,
    required this.topBar,
    required this.header,
    required this.banner,
    required this.slivers,
    required this.bottomBar,
    required this.controller,
  });

  final ValueListenable<double> offset;
  final NotificationListenerCallback<ScrollNotification> onScroll;
  final Widget topBar;
  final Widget? header;
  final Widget? banner;
  final List<Widget> slivers;
  final Widget? bottomBar;
  final ScrollController? controller;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final padding = MediaQuery.paddingOf(context);
    final top = padding.top + _topBarHeight;

    return Stack(
      children: [
        NotificationListener<ScrollNotification>(
          onNotification: onScroll,
          child: CustomScrollView(
            controller: controller,
            slivers: [
              SliverToBoxAdapter(child: SizedBox(height: top)),
              if (header != null) SliverToBoxAdapter(child: header),
              if (banner != null) SliverToBoxAdapter(child: banner),
              ...slivers,
              // A barra de abas flutua por cima do fim da lista; sem esta
              // folga o último item ficaria preso atrás dela.
              SliverToBoxAdapter(
                child: SizedBox(
                  height:
                      padding.bottom +
                      Space.xxl +
                      (bottomBar == null ? 0 : Heights.control + Space.xxl),
                ),
              ),
            ],
          ),
        ),
        // Degradê de borda: o conteúdo se dissolve ao passar sob o topo, em
        // vez de cortar seco numa barra opaca. Aparece só depois que algo
        // passou por ali.
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: top + Space.xxxl,
          child: IgnorePointer(
            child: ValueListenableBuilder<double>(
              valueListenable: offset,
              builder: (context, value, child) =>
                  Opacity(opacity: (value / 16).clamp(0.0, 1.0), child: child),
              child: _EdgeFade(color: c.bg, fromTop: true),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: SafeArea(bottom: false, child: topBar),
        ),
        if (bottomBar != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomBar(floating: true, child: bottomBar!),
          ),
      ],
    );
  }
}

/// Faixa fixa do topo: voltar à esquerda, título pequeno no centro, ações à
/// direita — tudo em vidro, sem fundo e sem linha.
class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.back,
    required this.title,
    required this.subtitle,
    required this.titleVisibility,
    required this.actions,
  });

  final Widget? back;
  final String? title;
  final String? subtitle;

  /// Quando presente, o título só aparece depois que a lista rolou o título
  /// grande para fora de vista.
  final ValueListenable<double>? titleVisibility;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget? label;
    if (title != null) {
      label = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            title!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppText.headline.copyWith(color: c.textPrimary),
          ),
          if (subtitle != null)
            Text(
              subtitle!,
              maxLines: 1,
              style: AppText.caption.copyWith(
                color: c.textSecondary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
        ],
      );
      final visibility = titleVisibility;
      if (visibility != null) {
        label = ValueListenableBuilder<double>(
          valueListenable: visibility,
          builder: (context, value, child) => AnimatedOpacity(
            duration: AppDurations.fast,
            // O título grande tem ~40 px; depois disso ele já saiu de baixo
            // do topo e o pequeno assume.
            opacity: value > 40 ? 1 : 0,
            child: child,
          ),
          child: label,
        );
      }
    }

    // NavigationToolbar centraliza o título quando cabe e o desloca quando
    // os botões de um lado são mais largos — a sessão tem voltar à esquerda e
    // lista + "Finalizar" à direita, e um título centrado com folga fixa
    // passava por baixo deles.
    return SizedBox(
      height: _topBarHeight,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.xl),
        child: NavigationToolbar(
          leading: back,
          middle: label,
          trailing: actions.isEmpty
              ? null
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(width: Space.md),
                      actions[i],
                    ],
                  ],
                ),
          middleSpacing: Space.md,
        ),
      ),
    );
  }
}

/// Rodapé de ação, sem fundo opaco nem linha: o botão flutua sobre um
/// degradê que apaga o conteúdo embaixo dele.
class _BottomBar extends StatelessWidget {
  const _BottomBar({required this.child, this.floating = false});

  final Widget child;

  /// Por cima de uma lista que rola por baixo — precisa do degradê. Fora
  /// disso a faixa só ocupa o seu espaço.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bar = SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          Space.page,
          Space.md,
          Space.page,
          Space.md,
        ),
        child: child,
      ),
    );
    if (!floating) return bar;

    return Stack(
      children: [
        Positioned.fill(
          top: -Space.xxl,
          child: IgnorePointer(child: _EdgeFade(color: c.bg, fromTop: false)),
        ),
        bar,
      ],
    );
  }
}

/// Degradê da cor do fundo para transparente — a "borda de rolagem" do iOS 26,
/// que substitui a barra translúcida com linha.
class _EdgeFade extends StatelessWidget {
  const _EdgeFade({required this.color, required this.fromTop});

  final Color color;
  final bool fromTop;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: fromTop ? Alignment.topCenter : Alignment.bottomCenter,
          end: fromTop ? Alignment.bottomCenter : Alignment.topCenter,
          colors: [
            color,
            color.withValues(alpha: 0.94),
            color.withValues(alpha: 0.7),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.6, 0.8, 1],
        ),
      ),
    );
  }
}

/// O voltar das telas que não usam [AppScaffold] — a de imagem, que é um card
/// em tela cheia. Mesmo círculo de vidro do topo das outras telas, para ela
/// não virar a exceção da regra.
class AppBackLink extends StatelessWidget {
  const AppBackLink({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(Space.xl, Space.xs, Space.xl, 0),
      child: GlassCircleButton(
        icon: LucideIcons.chevronLeft,
        iconSize: 24,
        label: 'Voltar para $label',
        onTap: () => Navigator.maybePop(context),
      ),
    );
  }
}

/// Lista de filhos como sliver, com a margem lateral das telas.
class AppSliverList extends StatelessWidget {
  const AppSliverList({
    super.key,
    required this.children,
    this.padding = const EdgeInsets.symmetric(horizontal: Space.page),
  });

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: padding,
      sliver: SliverList.list(children: children),
    );
  }
}

/// Conteúdo que ocupa o resto da tela — o estado vazio e o de erro.
class AppSliverFill extends StatelessWidget {
  const AppSliverFill({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SliverFillRemaining(hasScrollBody: false, child: child);
  }
}

/// Título de seção, em caixa normal e negrito — como "Treinos" e "Esta
/// semana" no Fitness e no Saúde.
///
/// Era a maiúscula pequena com tracking das listas agrupadas antigas do iOS.
/// No iOS atual a seção tem título de verdade, e a maiúscula pequena ficou só
/// onde rotula dados (cabeçalho de coluna).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // "novembro de 2026" vem do DateFormat em minúscula; título de seção
    // começa em maiúscula.
    final label = text.isEmpty
        ? text
        : text[0].toUpperCase() + text.substring(1);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.xs,
        Space.xxxl,
        Space.xs,
        Space.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Text(
              label,
              style: AppText.title2.copyWith(color: c.textPrimary),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

/// Cartão de bloco único: a mesma superfície do [InsetGroup], sem as linhas
/// divisórias.
///
/// Sem borda: contra o fundo preto (ou o cinza #F2F2F7 no claro) o cartão já
/// se separa pela cor, e a linha fina em volta era o que o deixava com cara de
/// Card do Material. O canto é contínuo (superelipse).
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// Troca a superfície — o cartão de destaque da sessão usa um tom acima.
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final card = ClipRSuperellipse(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: ColoredBox(
        color: color ?? c.surface,
        child: Padding(padding: padding, child: child),
      ),
    );

    if (onTap == null) return card;
    // Cartão inteiro tocável encolhe de leve, como os cartões do Fitness.
    return PressScale(onTap: onTap, scale: 0.98, child: card);
  }
}

/// Agrupamento de lista: um cartão com linhas divisórias entre as linhas. É a
/// estrutura que dá o ar de app de sistema em vez de pilha de Cards.
class InsetGroup extends StatelessWidget {
  const InsetGroup({
    super.key,
    required this.children,
    this.separatorIndent = Space.xl,
    this.padding = EdgeInsets.zero,
  });

  final List<Widget> children;

  /// Recuo da linha divisória à esquerda. No iOS a linha começa onde começa o
  /// texto, não na borda do cartão: com selo à esquerda, use
  /// [AppRow.textInset].
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

    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(Radii.lg),
      child: ColoredBox(
        color: c.surface,
        child: Padding(
          padding: padding,
          // mainAxisSize.min: dentro de uma lista a altura já é livre e isso
          // não muda nada, mas dentro de uma folha — onde a altura é limitada —
          // um Column padrão estica e a folha ocupa a tela inteira.
          child: Column(mainAxisSize: MainAxisSize.min, children: rows),
        ),
      ),
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

  /// Recuo do texto de uma linha com selo de [leadingSize] px — o ponto onde a
  /// linha divisória do [InsetGroup] deve começar.
  static double textInset([double leadingSize = 36]) =>
      Space.xl + leadingSize + Space.lg;

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
                    style: AppText.subheadline.copyWith(color: c.textSecondary),
                  ),
                ],
              ],
            ),
          ),
          if (trailing != null) ...[const SizedBox(width: Space.md), trailing!],
          if (showChevron) ...[
            const SizedBox(width: Space.xs),
            Icon(LucideIcons.chevronRight, size: 18, color: c.textTertiary),
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
        color: _down ? context.colors.fill : Colors.transparent,
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
              Icon(icon, size: 40, color: c.textTertiary),
              const SizedBox(height: Space.xl),
            ],
            Text(
              title,
              textAlign: TextAlign.center,
              style: AppText.title3.copyWith(color: c.textPrimary),
            ),
            const SizedBox(height: Space.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppText.subheadline.copyWith(
                color: c.textSecondary,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
