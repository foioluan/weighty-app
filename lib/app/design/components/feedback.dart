import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme.dart';

enum ToastKind { info, success, error }

/// Substitui o SnackBar. O padrão do Material entra branco, com cantos quase
/// retos e margem larga, e destoa de tudo no tema escuro.
///
/// Este entra pela base, na cor de superfície elevada do app, com hairline e o
/// ícone na cor semântica do aviso.
abstract final class AppToast {
  static OverlayEntry? _current;
  static Timer? _timer;

  static void show(
    BuildContext context,
    String message, {
    ToastKind kind = ToastKind.info,
    Duration duration = const Duration(seconds: 3),
  }) {
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    _dismiss();

    final colors = context.colors;
    final entry = OverlayEntry(
      builder: (_) => _ToastView(message: message, kind: kind, colors: colors),
    );

    _current = entry;
    overlay.insert(entry);
    _timer = Timer(duration, _dismiss);
  }

  /// Encerra o toast atual. Público porque a tela pode querer fechá-lo antes do
  /// tempo (ao navegar, por exemplo).
  static void dismiss() => _dismiss();

  static void _dismiss() {
    _timer?.cancel();
    _timer = null;

    final entry = _current;
    _current = null;
    // Se o Overlay já foi descartado (app fechando, tela desmontada), remover
    // uma entrada não montada lança. O toast não pode derrubar o app.
    if (entry != null && entry.mounted) entry.remove();
  }
}

class _ToastView extends StatefulWidget {
  const _ToastView({
    required this.message,
    required this.kind,
    required this.colors,
  });

  final String message;
  final ToastKind kind;
  final AppColors colors;

  @override
  State<_ToastView> createState() => _ToastViewState();
}

class _ToastViewState extends State<_ToastView>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: AppDurations.base,
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
    );

    return Positioned(
      left: Space.xl,
      right: Space.xl,
      bottom: MediaQuery.viewInsetsOf(context).bottom + 28,
      child: FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(curve),
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.xl,
              vertical: Space.lg,
            ),
            decoration: BoxDecoration(
              color: c.surfaceRaised,
              borderRadius: BorderRadius.circular(Radii.md),
              border: Border.all(color: c.hairlineStrong, width: 0.5),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: c.isDark ? 0.5 : 0.12),
                  blurRadius: 24,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Icon(icon, size: 17, color: tone),
                const SizedBox(width: Space.lg),
                Expanded(
                  child: Text(
                    widget.message,
                    style: AppText.callout.copyWith(color: c.textPrimary),
                  ),
                ),
              ],
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
