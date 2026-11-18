import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme.dart';
import 'glass.dart';

enum ToastKind { info, success, error }

/// Espaço a preservar na base da tela, informado por quem tem barra embaixo.
///
/// O toast vive no Overlay da raiz, acima de todas as telas, então não tem como
/// descobrir sozinho que existe uma barra de abas ocupando os 54 px de baixo —
/// e era por isso que ele aparecia atrás dela. Quem sabe é a casca; ela avisa
/// aqui, e as telas de detalhe (que cobrem as abas) simplesmente não avisam.
class ToastInset extends InheritedWidget {
  const ToastInset({super.key, required this.bottom, required super.child});

  /// Altura a reservar, já somada à área segura.
  final double bottom;

  /// Leitura sem criar dependência: o valor é consultado uma vez, no momento de
  /// mostrar o toast, e não faz sentido reconstruir a tela chamadora por isso.
  static double of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ToastInset>()?.bottom ?? 0;

  @override
  bool updateShouldNotify(ToastInset oldWidget) => oldWidget.bottom != bottom;
}

/// Substitui o SnackBar. O padrão do Material entra branco, com cantos quase
/// retos e margem larga, e destoa de tudo no tema escuro.
///
/// Este é uma pílula que abraça o texto, centrada na base, na superfície
/// elevada do app — a mesma linguagem do botão. Sai sozinho em 3 s, mas o toque
/// e o arrasto para baixo dispensam na hora.
abstract final class AppToast {
  static OverlayEntry? _current;
  static GlobalKey<_ToastViewState>? _key;

  static const _defaultDuration = Duration(seconds: 3);

  static void show(
    BuildContext context,
    String message, {
    ToastKind kind = ToastKind.info,
    Duration duration = _defaultDuration,
  }) {
    capture(context).show(message, kind: kind, duration: duration);
  }

  /// Guarda agora o que o toast vai precisar depois.
  ///
  /// Use quando o aviso vem no fim de uma operação capaz de desmontar quem
  /// pediu — apagar a linha de uma lista, por exemplo. A linha some assim que
  /// o banco emite a mudança, e o `context.mounted` do fim já é falso: o aviso
  /// simplesmente não aparecia. Nada do que o toast lê muda no meio do
  /// caminho, então ler antes é seguro.
  static ToastHandle capture(BuildContext context) => ToastHandle._(
    Overlay.maybeOf(context),
    context.colors,
    ToastInset.of(context),
  );

  /// Encerra o toast atual com a animação de saída. A tela pode querer fechá-lo
  /// antes do tempo — ao navegar, por exemplo.
  static void dismiss() {
    final state = _key?.currentState;
    if (state == null) {
      _removeNow();
      return;
    }
    state.hide();
  }

  static void _removeNow() {
    final entry = _current;
    _current = null;
    _key = null;
    // Se o Overlay já foi descartado (app fechando, tela desmontada), remover
    // uma entrada não montada lança. O toast não pode derrubar o app.
    if (entry != null && entry.mounted) entry.remove();
  }
}

/// Um toast já "carregado", pronto para disparar mesmo que a tela que o
/// preparou tenha saído do ar. Vem de [AppToast.capture].
class ToastHandle {
  const ToastHandle._(this._overlay, this._colors, this._inset);

  final OverlayState? _overlay;
  final AppColors _colors;
  final double _inset;

  void show(
    String message, {
    ToastKind kind = ToastKind.info,
    Duration duration = AppToast._defaultDuration,
  }) {
    final overlay = _overlay;
    if (overlay == null || !overlay.mounted) return;

    // Um toast novo troca o anterior sem animar a saída: animar os dois ao
    // mesmo tempo só produziria um cruzamento confuso.
    AppToast._removeNow();

    final key = GlobalKey<_ToastViewState>();
    final entry = OverlayEntry(
      builder: (_) => _ToastView(
        key: key,
        message: message,
        kind: kind,
        colors: _colors,
        bottomInset: _inset,
        duration: duration,
        onFinished: AppToast._removeNow,
      ),
    );

    AppToast._current = entry;
    AppToast._key = key;
    overlay.insert(entry);
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    super.key,
    required this.message,
    required this.kind,
    required this.colors,
    required this.bottomInset,
    required this.duration,
    required this.onFinished,
  });

  final String message;
  final ToastKind kind;
  final AppColors colors;
  final double bottomInset;
  final Duration duration;
  final VoidCallback onFinished;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  /// Distância do arrasto para baixo em que o toast é considerado dispensado.
  ///
  /// Folgada de propósito: abaixo do limiar de arrasto do sistema o gesto é
  /// resolvido como toque — que também dispensa —, então o que precisa de
  /// margem é o caminho oposto, o de voltar ao lugar sem querer.
  static const _dismissDistance = 40.0;
  static const _dismissVelocity = 220.0;

  late final _controller = AnimationController(
    vsync: this,
    duration: AppDurations.base,
    reverseDuration: AppDurations.fast,
  );

  Timer? _timer;

  /// Deslocamento vertical do dedo, para a pílula acompanhar o arrasto.
  var _drag = 0.0;
  var _hiding = false;

  @override
  void initState() {
    super.initState();
    _controller.forward();
    // No initState, e não num `late final`: campo tardio só é criado quando
    // alguém o lê, e ninguém lia — o toast ficava na tela para sempre.
    _timer = Timer(widget.duration, hide);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// Reverte a animação e só então remove a entrada do Overlay. Antes o toast
  /// entrava animado e sumia num quadro só.
  Future<void> hide() async {
    if (_hiding) return;
    _hiding = true;
    _timer?.cancel();
    await _controller.reverse();
    if (mounted) widget.onFinished();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    // Só para baixo: puxar para cima descolaria a pílula da borda sem motivo.
    setState(() => _drag = math.max(0, _drag + details.delta.dy));
  }

  void _onDragEnd(DragEndDetails details) {
    final flicked = details.velocity.pixelsPerSecond.dy > _dismissVelocity;
    if (_drag > _dismissDistance || flicked) {
      hide();
    } else {
      setState(() => _drag = 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.colors;
    final (icon, tone) = switch (widget.kind) {
      ToastKind.success => (LucideIcons.circleCheck, c.up),
      ToastKind.error => (LucideIcons.circleAlert, c.down),
      ToastKind.info => (LucideIcons.info, c.accent),
    };

    final curve = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );

    // Com o teclado aberto ele manda; sem teclado, o que vale é a maior entre a
    // barra de abas (quando a tela tem uma) e a área segura do sistema.
    final media = MediaQuery.of(context);
    final keyboard = media.viewInsets.bottom;
    final base = keyboard > 0
        ? keyboard
        : math.max(widget.bottomInset, media.padding.bottom);

    return Positioned(
      left: Space.xl,
      right: Space.xl,
      bottom: base + Space.xxl,
      // Center deixa a restrição frouxa, então a pílula abraça o texto em vez
      // de esticar de margem a margem.
      child: Center(
        child: FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.4),
              end: Offset.zero,
            ).animate(curve),
            child: Transform.translate(
              offset: Offset(0, _drag),
              child: Material(
                // Sem um Material acima, o Flutter desenha o texto com o
                // sublinhado amarelo duplo de "faltou Material" — o mesmo que
                // já apareceu na tela de abertura, em build release.
                color: Colors.transparent,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: hide,
                  onVerticalDragUpdate: _onDragUpdate,
                  onVerticalDragEnd: _onDragEnd,
                  // Cápsula de vidro, a mesma linguagem da barra de abas logo
                  // abaixo dela. O vidro do toast é mais denso: ele carrega
                  // texto, e o conteúdo desfocado atrás não pode competir.
                  child: Theme(
                    data: Theme.of(context).copyWith(extensions: [c]),
                    child: GlassSurface.capsule(
                      fill: c.surfaceRaised.withValues(alpha: 0.82),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Space.xl,
                          vertical: Space.lg,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(icon, size: 18, color: tone),
                            const SizedBox(width: Space.md),
                            Flexible(
                              child: Text(
                                widget.message,
                                style: AppText.subheadline.copyWith(
                                  color: c.textPrimary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ação de um diálogo.
class AppDialogAction {
  const AppDialogAction({
    required this.label,
    this.value,
    this.isPreferred = false,
    this.isDestructive = false,
  });

  final String label;
  final Object? value;

  /// Aparece em peso médio, como o botão padrão do alerta.
  final bool isPreferred;
  final bool isDestructive;
}

/// Alerta no formato do iOS: título, mensagem e botões separados por hairlines,
/// empilhados quando são mais de dois. Nada do `AlertDialog` do Material.
Future<T?> showAppDialog<T>(
  BuildContext context, {
  required String title,
  String? message,
  required List<AppDialogAction> actions,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar',
    // O escurecimento é pintado junto com o desfoque, então o barrier padrão
    // fica transparente.
    barrierColor: Colors.transparent,
    transitionDuration: AppDurations.base,
    pageBuilder: (context, _, _) =>
        _AppDialog<T>(title: title, message: message, actions: actions),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return BlurBarrier(
        progress: curved,
        child: FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween(begin: 0.94, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Fundo desfocado atrás de diálogos e folhas.
///
/// O desfoque entra junto com a animação: aplicar de uma vez fica abrupto, e
/// `BackdropFilter` com sigma zero é praticamente de graça, então dá para
/// interpolar sem custo relevante.
class BlurBarrier extends StatelessWidget {
  const BlurBarrier({
    super.key,
    required this.progress,
    required this.child,
    this.sigma = 14,
  });

  final Animation<double> progress;
  final Widget child;
  final double sigma;

  @override
  Widget build(BuildContext context) {
    final isDark = context.colors.isDark;

    return AnimatedBuilder(
      animation: progress,
      builder: (context, _) {
        final t = progress.value.clamp(0.0, 1.0);
        return Stack(
          children: [
            // IgnorePointer: o ColoredBox abaixo é opaco ao toque e engolia o
            // toque fora da folha, que nunca chegava à barreira do diálogo —
            // tocar fora não fechava nada, apesar do barrierDismissible.
            Positioned.fill(
              child: IgnorePointer(
                child: BackdropFilter(
                  filter: ImageFilter.blur(
                    sigmaX: sigma * t,
                    sigmaY: sigma * t,
                  ),
                  child: ColoredBox(
                    color: Colors.black.withValues(
                      alpha: (isDark ? 0.45 : 0.25) * t,
                    ),
                  ),
                ),
              ),
            ),
            child,
          ],
        );
      },
    );
  }
}

class _AppDialog<T> extends StatelessWidget {
  const _AppDialog({
    required this.title,
    required this.message,
    required this.actions,
  });

  final String title;
  final String? message;
  final List<AppDialogAction> actions;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Dois botões cabem lado a lado; três ou mais empilham, senão o texto
    // quebra e o alerta fica desalinhado.
    final horizontal = actions.length == 2;

    final buttons = [
      for (final action in actions) _DialogButton<T>(action: action),
    ];

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxxl),
        child: Material(
          color: Colors.transparent,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 320),
            // Alerta do iOS 26: vidro denso de canto grande e botões em
            // cápsula, no lugar da caixa com botões separados por linhas.
            child: GlassSurface(
              radius: Radii.xl,
              fill: c.surfaceRaised.withValues(alpha: 0.86),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  Space.xxl,
                  Space.xxl + 2,
                  Space.xxl,
                  Space.xl,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: AppText.headline.copyWith(color: c.textPrimary),
                    ),
                    if (message != null) ...[
                      const SizedBox(height: Space.sm),
                      Text(
                        message!,
                        textAlign: TextAlign.center,
                        style: AppText.subheadline.copyWith(
                          color: c.textSecondary,
                          height: 1.4,
                        ),
                      ),
                    ],
                    const SizedBox(height: Space.xxl),
                    if (horizontal)
                      Row(
                        children: [
                          Expanded(child: buttons[0]),
                          const SizedBox(width: Space.md + 2),
                          Expanded(child: buttons[1]),
                        ],
                      )
                    else
                      Column(
                        children: [
                          for (var i = 0; i < buttons.length; i++) ...[
                            if (i > 0) const SizedBox(height: Space.md),
                            buttons[i],
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialogButton<T> extends StatelessWidget {
  const _DialogButton({required this.action});

  final AppDialogAction action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // A preferida é cheia; a destrutiva, vermelha sobre o tom dela; as demais,
    // neutras. Vermelho cheio fica de fora: no app, vermelho forte é
    // "regrediu", e um botão não deve gritar isso.
    final (bg, fg) = switch ((action.isPreferred, action.isDestructive)) {
      (_, true) => (c.downSubtle, c.down),
      (true, false) => (c.accent, c.onAccent),
      (false, false) => (c.fill, c.textPrimary),
    };

    return Semantics(
      button: true,
      label: action.label,
      excludeSemantics: true,
      child: PressScale(
        onTap: () => Navigator.pop(context, action.value as T?),
        scale: 0.96,
        child: Container(
          height: 48,
          padding: const EdgeInsets.symmetric(horizontal: Space.lg),
          decoration: ShapeDecoration(color: bg, shape: const StadiumBorder()),
          child: Center(
            child: Text(
              action.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AppText.headline.copyWith(
                color: fg,
                fontWeight: action.isPreferred
                    ? FontWeight.w600
                    : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Folha inferior com puxador, na superfície elevada do app.
///
/// Feita com `showGeneralDialog` em vez de `showModalBottomSheet`: aquele
/// posiciona o conteúdo no rodapé e não deixa nada cobrir a tela inteira, então
/// não haveria onde aplicar o desfoque do fundo.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required WidgetBuilder builder,
  String? title,
}) {
  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Fechar',
    barrierColor: Colors.transparent,
    transitionDuration: AppDurations.base,
    pageBuilder: (context, _, _) => Align(
      alignment: Alignment.bottomCenter,
      child: _SheetBody(title: title, builder: builder),
    ),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      return BlurBarrier(
        progress: curved,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({required this.title, required this.builder});

  final String? title;
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Material(
      color: Colors.transparent,
      child: Padding(
        // Folha flutuante, solta das bordas, como as folhas de altura parcial
        // do iOS 26. O canto de baixo acompanha o do aparelho.
        padding: EdgeInsets.fromLTRB(
          Space.md,
          0,
          Space.md,
          Space.md + (bottom > 0 ? 0 : Space.xs),
        ),
        child: SafeArea(
          top: false,
          child: GlassSurface(
            radius: Radii.xl,
            fill: c.surfaceRaised.withValues(alpha: 0.9),
            child: MediaQuery.removePadding(
              // A margem e a área segura já foram aplicadas por fora; quem
              // monta o conteúdo da folha não precisa somá-las de novo.
              context: context,
              removeBottom: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(
                      top: Space.md,
                      bottom: Space.xs,
                    ),
                    child: Container(
                      width: 36,
                      height: 5,
                      decoration: ShapeDecoration(
                        color: c.hairlineStrong,
                        shape: const StadiumBorder(),
                      ),
                    ),
                  ),
                  if (title != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        Space.xxl,
                        Space.sm,
                        Space.xxl,
                        Space.xs,
                      ),
                      child: Text(
                        title!,
                        textAlign: TextAlign.center,
                        style: AppText.headline.copyWith(color: c.textPrimary),
                      ),
                    ),
                  Flexible(child: builder(context)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Item de [showAppMenu].
class AppMenuItem<T> {
  const AppMenuItem({
    required this.label,
    required this.value,
    this.icon,
    this.isDestructive = false,
  });

  final String label;
  final T value;
  final IconData? icon;
  final bool isDestructive;
}

/// Menu suspenso de vidro, nascendo do botão que o abriu — o menu do `⋯` no
/// iOS.
///
/// Substitui a folha que subia da base com as ações de um item: a folha
/// levava o olho para longe do que foi tocado e cobria a tela inteira por
/// três opções. O menu abre ao lado do botão, cresce a partir dele e some
/// com qualquer toque fora.
Future<T?> showAppMenu<T>(
  BuildContext anchorContext, {
  required List<AppMenuItem<T>> items,
}) {
  final box = anchorContext.findRenderObject()! as RenderBox;
  final overlay =
      Navigator.of(anchorContext).overlay!.context.findRenderObject()!
          as RenderBox;
  final anchor = Rect.fromPoints(
    box.localToGlobal(Offset.zero, ancestor: overlay),
    box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
  );

  return showGeneralDialog<T>(
    context: anchorContext,
    barrierDismissible: true,
    barrierLabel: 'Fechar menu',
    barrierColor: Colors.black.withValues(
      alpha: anchorContext.colors.isDark ? 0.3 : 0.12,
    ),
    transitionDuration: const Duration(milliseconds: 340),
    pageBuilder: (context, _, _) =>
        _MenuLayout<T>(anchor: anchor, items: items),
    // A animação mora no próprio menu, que sabe de onde ele cresce.
    transitionBuilder: (_, _, _, child) => child,
  );
}

class _MenuLayout<T> extends StatelessWidget {
  const _MenuLayout({required this.anchor, required this.items});

  final Rect anchor;
  final List<AppMenuItem<T>> items;

  static const _width = 250.0;
  static const _rowHeight = 48.0;
  static const _gap = Space.sm;

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final padding = MediaQuery.paddingOf(context);
    final height = items.length * _rowHeight;

    // Abre para baixo quando cabe; senão, para cima. Alinha pela borda do
    // botão que estiver do lado de dentro da tela.
    final below =
        anchor.bottom + _gap + height < size.height - padding.bottom - Space.xl;
    final alignRight = anchor.center.dx > size.width / 2;

    final left = (alignRight ? anchor.right - _width : anchor.left).clamp(
      Space.md,
      size.width - _width - Space.md,
    );
    final top = below ? anchor.bottom + _gap : anchor.top - _gap - height;

    final animation = ModalRoute.of(context)!.animation!;
    final curved = CurvedAnimation(
      parent: animation,
      // Passa um pouco do tamanho e volta: o menu "salta" do botão.
      curve: const Cubic(0.3, 1.3, 0.5, 1),
      reverseCurve: Curves.easeInCubic,
    );

    return Stack(
      children: [
        Positioned(
          left: left,
          top: top,
          width: _width,
          child: FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: const Interval(0, 0.5),
            ),
            child: ScaleTransition(
              scale: Tween(begin: 0.4, end: 1.0).animate(curved),
              alignment: Alignment(alignRight ? 1 : -1, below ? -1 : 1),
              child: _Menu<T>(items: items, rowHeight: _rowHeight),
            ),
          ),
        ),
      ],
    );
  }
}

class _Menu<T> extends StatelessWidget {
  const _Menu({required this.items, required this.rowHeight});

  final List<AppMenuItem<T>> items;
  final double rowHeight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Material(
      color: Colors.transparent,
      child: GlassSurface(
        radius: Radii.lg,
        fill: c.surfaceRaised.withValues(alpha: 0.84),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < items.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: Space.xl),
                  child: Container(height: 0.5, color: c.hairline),
                ),
              _MenuRow<T>(item: items[i], height: rowHeight),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuRow<T> extends StatefulWidget {
  const _MenuRow({required this.item, required this.height});

  final AppMenuItem<T> item;
  final double height;

  @override
  State<_MenuRow<T>> createState() => _MenuRowState<T>();
}

class _MenuRowState<T> extends State<_MenuRow<T>> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = widget.item.isDestructive ? c.down : c.textPrimary;

    return Semantics(
      button: true,
      label: widget.item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTap: () => Navigator.pop(context, widget.item.value),
        child: AnimatedContainer(
          duration: AppDurations.fast,
          height: widget.height,
          color: _down ? c.fill : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: Space.xl),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  widget.item.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.body.copyWith(color: tone),
                ),
              ),
              if (widget.item.icon != null) ...[
                const SizedBox(width: Space.md),
                Icon(widget.item.icon, size: 19, color: tone),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
