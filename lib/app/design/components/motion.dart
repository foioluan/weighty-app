import 'package:flutter/cupertino.dart';

import '../../theme.dart';

/// Número que anima entre valores em vez de trocar seco.
///
/// Usado na carga em destaque: ver 67,5 correr até 70 comunica a mudança de um
/// jeito que o corte não comunica.
class AnimatedNumber extends StatelessWidget {
  const AnimatedNumber({
    super.key,
    required this.value,
    required this.format,
    required this.style,
    this.duration = AppDurations.base,
  });

  final double value;
  final String Function(double) format;
  final TextStyle style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: value, end: value),
      duration: duration,
      curve: Curves.easeOutCubic,
      builder: (context, animated, _) => Text(format(animated), style: style),
    );
  }
}

/// Duração da entrada de cada item, sem contar o atraso.
const _entry = Duration(milliseconds: 240);

/// Entrada escalonada dos itens de uma lista: cada um sobe e aparece um pouco
/// depois do anterior.
///
/// O atraso é limitado porque, com listas longas, esperar o item 20 aparecer
/// deixa de ser refinamento e vira lentidão.
class StaggeredEntry extends StatelessWidget {
  const StaggeredEntry({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 30),
    this.maxDelay = const Duration(milliseconds: 120),
  });

  final int index;
  final Widget child;
  final Duration step;
  final Duration maxDelay;

  @override
  Widget build(BuildContext context) {
    final delay = step * index;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _entry + (delay > maxDelay ? maxDelay : delay),
      curve: Interval(
        // A fração inicial parada é o que cria o escalonamento.
        (delay > maxDelay ? maxDelay : delay).inMilliseconds /
            (_entry.inMilliseconds +
                (delay > maxDelay ? maxDelay : delay).inMilliseconds +
                1),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 10 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Duração da troca de tela. A rota Cupertino do Flutter usa 500 ms, que no
/// Android deixava cada navegação com cara de lenta: o toque respondia na
/// hora, mas a tela demorava a assentar. 300 ms mantém o deslize com
/// paralaxe legível e some do caminho.
const pageTransitionIn = Duration(milliseconds: 300);
const pageTransitionOut = Duration(milliseconds: 250);

/// Transição de tela do iOS: a nova entra deslizando da direita inteira, a de
/// baixo recua um terço com paralaxe e escurece de leve — e o arrasto a partir
/// da borda esquerda volta acompanhando o dedo.
///
/// Não é `CupertinoPage` direto só por causa da duração: a rota dela tem os
/// 500 ms fixos. Esta usa o mesmo `CupertinoRouteTransitionMixin` — mesma
/// curva, mesma paralaxe, mesmo gesto — com o tempo de [pageTransitionIn].
class SpringPage<T> extends Page<T> {
  const SpringPage({required this.child, super.key});

  final Widget child;

  @override
  Route<T> createRoute(BuildContext context) => _FastCupertinoRoute<T>(this);
}

class _FastCupertinoRoute<T> extends PageRoute<T>
    with CupertinoRouteTransitionMixin<T> {
  _FastCupertinoRoute(SpringPage<T> page) : super(settings: page);

  SpringPage<T> get _page => settings as SpringPage<T>;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  String? get title => null;

  @override
  bool get maintainState => true;

  @override
  DelegatedTransitionBuilder? get delegatedTransition =>
      CupertinoPageTransition.delegatedTransition;

  @override
  Duration get transitionDuration => pageTransitionIn;

  @override
  Duration get reverseTransitionDuration => pageTransitionOut;
}

/// A folha do iOS (a de escolher exercício), com o mesmo encurtamento: a do
/// Flutter também leva 500 ms para subir.
class FastSheetRoute<T> extends CupertinoSheetRoute<T> {
  FastSheetRoute({required super.scrollableBuilder});

  @override
  Duration get transitionDuration => const Duration(milliseconds: 320);

  @override
  Duration get reverseTransitionDuration => pageTransitionOut;
}
