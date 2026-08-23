import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme.dart';

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
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.xl,
                      vertical: Space.lg,
                    ),
                    decoration: BoxDecoration(
                      color: c.surfaceRaised,
                      borderRadius: BorderRadius.circular(Radii.pill),
                      border: Border.all(color: c.hairlineStrong, width: 0.5),
                      // O toast é o único elemento que flutua sem BlurBarrier
                      // atrás, então precisa de sombra para se separar do
                      // conteúdo — mas bem mais leve que a anterior.
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(
                            alpha: c.isDark ? 0.34 : 0.10,
                          ),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(icon, size: 16, color: tone),
                        const SizedBox(width: Space.md),
                        Flexible(
                          child: Text(
                            widget.message,
                            style: AppText.callout.copyWith(
                              color: c.textPrimary,
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
            Positioned.fill(
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: sigma * t, sigmaY: sigma * t),
                child: ColoredBox(
                  color: Colors.black.withValues(
                    alpha: (isDark ? 0.45 : 0.25) * t,
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

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Space.xxxl),
        child: Material(
          color: Colors.transparent,
          child: Container(
            constraints: const BoxConstraints(maxWidth: 300),
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: BorderRadius.circular(Radii.xl),
              border: Border.all(color: c.hairline, width: 0.5),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.xxl,
                    Space.xxl,
                    Space.xxl,
                    Space.xxl,
                  ),
                  child: Column(
                    children: [
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppText.title2.copyWith(color: c.textPrimary),
                      ),
                      if (message != null) ...[
                        const SizedBox(height: Space.md),
                        Text(
                          message!,
                          textAlign: TextAlign.center,
                          style: AppText.callout.copyWith(
                            color: c.textSecondary,
                            height: 1.45,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Container(height: 0.5, color: c.hairline),
                if (horizontal)
                  Row(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0)
                          Container(width: 0.5, height: 46, color: c.hairline),
                        Expanded(child: _DialogButton<T>(action: actions[i])),
                      ],
                    ],
                  )
                else
                  Column(
                    children: [
                      for (var i = 0; i < actions.length; i++) ...[
                        if (i > 0) Container(height: 0.5, color: c.hairline),
                        _DialogButton<T>(action: actions[i]),
                      ],
                    ],
                  ),
              ],
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
    final color = action.isDestructive ? c.down : c.accent;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.pop(context, action.value as T?),
      child: SizedBox(
        height: 46,
        child: Center(
          child: Text(
            action.label,
            style: AppText.body.copyWith(
              color: color,
              fontWeight: action.isPreferred
                  ? FontWeight.w600
                  : FontWeight.w400,
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
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          color: c.surfaceRaised,
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(Radii.xl),
          ),
          border: Border(top: BorderSide(color: c.hairline, width: 0.5)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: Space.md, bottom: Space.xs),
                child: Container(
                  width: 34,
                  height: 4,
                  decoration: BoxDecoration(
                    color: c.hairlineStrong,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              if (title != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.xxl,
                    Space.md,
                    Space.xxl,
                    Space.xs,
                  ),
                  child: Text(
                    title!,
                    style: AppText.title2.copyWith(color: c.textPrimary),
                  ),
                ),
              Flexible(child: builder(context)),
            ],
          ),
        ),
      ),
    );
  }
}
