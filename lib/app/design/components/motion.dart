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
    this.step = const Duration(milliseconds: 45),
    this.maxDelay = const Duration(milliseconds: 270),
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
      duration: AppDurations.slow + (delay > maxDelay ? maxDelay : delay),
      curve: Interval(
        // A fração inicial parada é o que cria o escalonamento.
        (delay > maxDelay ? maxDelay : delay).inMilliseconds /
            (AppDurations.slow.inMilliseconds +
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

/// Transição de tela do iOS: a nova entra deslizando da direita inteira, a de
/// baixo recua um terço com paralaxe e escurece de leve — e o arrasto a partir
/// da borda esquerda volta acompanhando o dedo.
///
/// A versão anterior era um deslize de 6% com fade, sem gesto: bonito, mas
/// voltar dependia do botão ou do gesto do sistema. O arrasto interativo é o
/// que mais faz navegação parecer iPhone, e a rota Cupertino já o traz pronto.
class SpringPage<T> extends CupertinoPage<T> {
  const SpringPage({required super.child, super.key});
}

/// A mesma transição para quem empurra a tela pelo Navigator em vez do
/// go_router — o caso das telas que devolvem valor, como o catálogo em modo de
/// escolha.
Route<T> springRoute<T>(WidgetBuilder builder) =>
    CupertinoPageRoute<T>(builder: builder);
