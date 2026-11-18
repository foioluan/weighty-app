import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../theme.dart';

/// Desfoque do vidro. Um valor só para o app inteiro: os vidros de uma tela
/// estão dentro do mesmo [BackdropGroup] e dividem uma passada de desfoque, o
/// que só acontece quando o filtro é idêntico.
const _glassSigma = 16.0;

/// Saturação aplicada ao que fica atrás do vidro. É o que faz o conteúdo
/// colorido "acender" através da superfície em vez de virar cinza — sem ela o
/// desfoque lê como vidro fosco de banheiro, não como Liquid Glass.
const _glassSaturation = 1.8;

final ImageFilter _glassFilter = ImageFilter.compose(
  outer: ColorFilter.matrix(_saturation(_glassSaturation)),
  inner: ImageFilter.blur(
    sigmaX: _glassSigma,
    sigmaY: _glassSigma,
    tileMode: TileMode.mirror,
  ),
);

List<double> _saturation(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final i = 1 - s;
  return [
    i * r + s, i * g, i * b, 0, 0, //
    i * r, i * g + s, i * b, 0, 0, //
    i * r, i * g, i * b + s, 0, 0, //
    0, 0, 0, 1, 0, //
  ];
}

/// Superfície de vidro (Liquid Glass): desfoque saturado do que está atrás,
/// preenchimento translúcido, borda de 1 px que se apaga para baixo, reflexo
/// no topo e sombra suave.
///
/// O Flutter não tem refração de verdade — a lente que entorta o conteúdo na
/// borda do vidro do iOS 26. O que fica é a combinação acima, que é o que de
/// fato carrega a leitura de "vidro" em tamanho de celular.
///
/// [shape] define o recorte. Use [GlassSurface.capsule] para cápsulas e
/// círculos e o construtor padrão para cantos contínuos.
class GlassSurface extends StatelessWidget {
  GlassSurface({
    super.key,
    required this.child,
    double radius = Radii.lg,
    this.fill,
    this.shadow = true,
  }) : shape = AppShapes.superellipse(radius);

  const GlassSurface.capsule({
    super.key,
    required this.child,
    this.fill,
    this.shadow = true,
  }) : shape = const StadiumBorder();

  final Widget child;
  final OutlinedBorder shape;

  /// Troca o preenchimento padrão — folhas e diálogos usam um vidro mais
  /// opaco, porque carregam texto longo.
  final Color? fill;

  /// Vidro sobre vidro (o polegar sobre a cápsula) não leva sombra.
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final glass = ClipPath(
      clipper: ShapeBorderClipper(shape: shape),
      child: BackdropFilter.grouped(
        filter: _glassFilter,
        child: CustomPaint(
          painter: _GlassPainter(
            shape: shape,
            fill: fill ?? c.glassFill,
            edge: c.glassEdge,
            highlight: c.glassHighlight,
          ),
          child: child,
        ),
      ),
    );

    if (!shadow) return glass;

    return DecoratedBox(
      decoration: ShapeDecoration(
        shape: shape,
        shadows: [
          BoxShadow(
            color: c.glassShadow,
            blurRadius: 28,
            spreadRadius: -6,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: glass,
    );
  }
}

class _GlassPainter extends CustomPainter {
  const _GlassPainter({
    required this.shape,
    required this.fill,
    required this.edge,
    required this.highlight,
  });

  final OutlinedBorder shape;
  final Color fill;
  final Color edge;
  final Color highlight;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final path = shape.getOuterPath(rect);

    canvas.drawPath(path, Paint()..color = fill);

    // Reflexo: a luz bate de cima e se apaga antes do meio. É o que dá volume
    // à superfície — sem ele o vidro parece uma película chapada.
    canvas.drawPath(
      path,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.center,
          colors: [
            highlight.withValues(alpha: highlight.a * 0.22),
            highlight.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );

    // Borda de 1 px, forte em cima e quase sumida embaixo — o desenho da
    // aresta do vidro do iOS, que pega luz no topo e não na base.
    canvas.drawPath(
      shape.getInnerPath(rect.deflate(0.5)),
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            edge,
            edge.withValues(alpha: edge.a * 0.25),
          ],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_GlassPainter old) =>
      old.fill != fill ||
      old.edge != edge ||
      old.highlight != highlight ||
      old.shape != shape;
}

/// Encolhe levemente ao toque, com mola — o retorno tátil visual de todo
/// controle do iOS. Só a escala: o realce de cor, quando existe, é de quem usa.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.onLongPress,
    this.scale = 0.96,
    this.onPressedChanged,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final double scale;

  /// Para quem quer também trocar a cor enquanto está pressionado.
  final ValueChanged<bool>? onPressedChanged;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale>
    with SingleTickerProviderStateMixin {
  // Sem limites de 0 a 1: a mola de volta passa um pouco de 1 e assenta, que
  // é justamente o "quique" que diferencia mola de curva.
  late final _controller = AnimationController.unbounded(vsync: this, value: 1);

  static const _spring = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 26,
  );

  void _to(double target) {
    _controller.animateWith(
      SpringSimulation(_spring, _controller.value, target, 0),
    );
  }

  void _down(bool down) {
    widget.onPressedChanged?.call(down);
    _to(down ? widget.scale : 1);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null || widget.onLongPress != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      onTapDown: enabled ? (_) => _down(true) : null,
      onTapUp: enabled ? (_) => _down(false) : null,
      onTapCancel: enabled ? () => _down(false) : null,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) =>
            Transform.scale(scale: _controller.value, child: child),
        child: widget.child,
      ),
    );
  }
}

/// Botão redondo de vidro, 44 px — o voltar e as ações do topo das telas.
class GlassCircleButton extends StatefulWidget {
  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
    this.color,
    this.size = 44,
    this.iconSize = 20,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String label;

  /// Cor do ícone. Padrão: texto primário — no iOS 26 os controles do topo
  /// são neutros, e a cor fica para a ação que importa.
  final Color? color;
  final double size;
  final double iconSize;

  @override
  State<GlassCircleButton> createState() => _GlassCircleButtonState();
}

class _GlassCircleButtonState extends State<GlassCircleButton> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = widget.onTap != null;

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: PressScale(
        onTap: widget.onTap,
        scale: 0.9,
        onPressedChanged: (v) => setState(() => _pressed = v),
        child: SizedBox.square(
          dimension: widget.size,
          child: GlassSurface.capsule(
            // Ao toque o vidro clareia, como se a luz chegasse mais perto.
            fill: _pressed ? Color.alphaBlend(c.fill, c.glassFill) : null,
            child: Center(
              child: Icon(
                widget.icon,
                size: widget.iconSize,
                color: enabled ? (widget.color ?? c.textPrimary) : c.textGhost,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
