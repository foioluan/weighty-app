import 'dart:async';

import 'package:flutter/material.dart';

import 'design/design.dart';

/// Tela de abertura, por cima do app já montado.
///
/// Não é uma rota nem uma espera: o app é construído **embaixo** dela e já está
/// pronto quando ela sai. O único custo é o toque ficar retido por [_hold] — se
/// fosse uma tela de verdade, cada abertura pagaria o tempo de montar o app
/// depois do tempo da marca.
///
/// Ela vive no `builder` do MaterialApp, então herda o tema escolhido e troca
/// junto com ele.
class SplashGate extends StatefulWidget {
  const SplashGate({super.key, required this.child});

  final Widget child;

  /// Quanto a marca fica na tela. Curto de propósito: o app é aberto entre uma
  /// série e outra, e ninguém quer esperar para anotar uma carga.
  static const _hold = Duration(milliseconds: 750);

  @override
  State<SplashGate> createState() => _SplashGateState();
}

class _SplashGateState extends State<SplashGate> {
  var _visible = true;
  var _mounted = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(SplashGate._hold, () {
      if (mounted) setState(() => _visible = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_mounted)
          // Positioned.fill é obrigatório: filho não posicionado de um Stack
          // recebe restrição solta e é alinhado no canto, então a camada saía
          // com a largura do texto, encostada à esquerda, com o app aparecendo
          // atrás dela.
          Positioned.fill(
            child: IgnorePointer(
              ignoring: !_visible,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: AppDurations.slow,
                curve: Curves.easeOut,
                // Depois do fade a camada sai da árvore: deixá-la montada com
                // opacidade zero manteria um repaint por quadro para sempre.
                onEnd: () {
                  if (!_visible && mounted) setState(() => _mounted = false);
                },
                child: const _SplashContent(),
              ),
            ),
          ),
      ],
    );
  }
}

class _SplashContent extends StatelessWidget {
  const _SplashContent();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    // Material, não ColoredBox: sem um Material acima, o Flutter desenha o
    // texto com o sublinhado amarelo duplo de "faltou Material" — e aqui isso
    // apareceu no aparelho, em build release, porque a abertura é a única tela
    // que não passa pelo AppScaffold.
    return Material(
      color: c.bg,
      child: SafeArea(
        child: Column(
          children: [
            // A marca fica um pouco acima do centro óptico: centralizada de
            // verdade, com o crédito embaixo, ela parece baixa.
            const Spacer(flex: 5),
            WeightyLockup(style: AppText.largeTitle.copyWith(fontSize: 32)),
            const Spacer(flex: 4),
            const AppCredit(),
            const SizedBox(height: Space.xxxl),
          ],
        ),
      ),
    );
  }
}

/// Autoria e direitos, em duas linhas. Vive aqui porque aparece em dois lugares
/// — a abertura e os Ajustes — e as duas precisam dizer exatamente o mesmo.
class AppCredit extends StatelessWidget {
  const AppCredit({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Column(
      children: [
        Text(
          appCredit,
          textAlign: TextAlign.center,
          style: AppText.caption.copyWith(color: c.textTertiary),
        ),
        const SizedBox(height: 3),
        Text(
          appRights(),
          textAlign: TextAlign.center,
          style: AppText.caption.copyWith(color: c.textGhost),
        ),
      ],
    );
  }
}
