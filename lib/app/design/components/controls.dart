import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme.dart';
import 'glass.dart';

enum AppButtonStyle {
  /// Ação principal: bronze cheio.
  filled,

  /// Ação secundária: bronze sobre fundo tingido.
  tinted,

  /// Ação terciária: só texto.
  plain,

  /// Ação destrutiva.
  danger,
}

/// Botão em pílula.
///
/// O raio é metade da altura, e não um valor fixo: retângulo de canto suave e
/// largura total é a silhueta do botão do Material, e era o que mais entregava
/// a plataforma no app inteiro.
///
/// [expand] é decisão consciente de cada tela, não o padrão. Só uma ação em
/// todo o app merece ocupar a largura inteira — "Concluir série", que é tocada
/// com a mão suada, entre séries, sem olhar. Dar essa mesma força a "Salvar" e
/// "Criar treino" é o que fazia tudo parecer igualmente urgente.
class AppButton extends StatefulWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AppButtonStyle.filled,
    this.icon,
    this.compact = false,
    this.expand = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final AppButtonStyle style;
  final IconData? icon;
  final bool compact;

  /// Ocupa toda a largura disponível. Reservado à ação que precisa de alvo
  /// grande de verdade.
  final bool expand;

  @override
  State<AppButton> createState() => _AppButtonState();
}

class _AppButtonState extends State<AppButton> {
  var _down = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final disabled = widget.onPressed == null;

    final (bg, fg) = switch (widget.style) {
      AppButtonStyle.filled => (_down ? c.accentPressed : c.accent, c.onAccent),
      AppButtonStyle.tinted => (c.accentSubtle, c.accent),
      AppButtonStyle.plain => (Colors.transparent, c.accent),
      AppButtonStyle.danger => (c.downSubtle, c.down),
    };
    final tone = disabled ? c.textTertiary : fg;

    final height = widget.compact ? Heights.controlCompact : Heights.control;
    final filled = widget.style == AppButtonStyle.filled && !disabled;

    final child = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: widget.compact ? 16 : 19, color: tone),
          const SizedBox(width: Space.sm),
        ],
        Text(
          widget.label,
          style: (widget.compact ? AppText.subheadline : AppText.headline)
              .copyWith(color: tone, fontWeight: FontWeight.w600),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.label,
      excludeSemantics: true,
      child: PressScale(
        onTap: widget.onPressed,
        scale: widget.expand ? 0.98 : 0.95,
        onPressedChanged: (v) => setState(() => _down = v),
        child: AnimatedOpacity(
          duration: AppDurations.fast,
          opacity: _down && !filled ? 0.6 : 1,
          child: Container(
            height: height,
            // O padding lateral acompanha a altura: numa pílula, folga fixa
            // faz o rótulo encostar na curva quando o botão é baixo.
            padding: EdgeInsets.symmetric(horizontal: height * 0.44),
            decoration: ShapeDecoration(
              shape: const StadiumBorder(),
              color: filled ? null : (disabled ? c.fill : bg),
              // A ação cheia tem volume: um degradê leve de cima para baixo e
              // uma sombra na própria cor, como os botões do iOS 26. Chapada,
              // ela lia como um adesivo colado na tela.
              gradient: filled
                  ? LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color.lerp(bg, Colors.white, 0.14)!, bg],
                    )
                  : null,
              shadows: filled
                  ? [
                      BoxShadow(
                        color: c.accent.withValues(
                          alpha: c.isDark ? 0.32 : 0.28,
                        ),
                        blurRadius: 18,
                        spreadRadius: -6,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : null,
            ),
            // Sem Center aqui: um Align sem widthFactor cresce até a largura
            // máxima permitida, então ele anulava o `expand: false` e todo botão
            // saía atravessando a tela. O alinhamento horizontal já vem do
            // mainAxisAlignment da Row.
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Botão de ícone com alvo de 44 px e desenho leve.
class AppIconButton extends StatelessWidget {
  const AppIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    required this.label,
    this.color,
    this.size = 20,
    this.tapSize = 44,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String label;
  final Color? color;
  final double size;
  final double tapSize;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: SizedBox(
          width: tapSize,
          height: tapSize,
          child: Center(
            child: Icon(
              icon,
              size: size,
              color: onPressed == null
                  ? c.textGhost
                  : (color ?? c.textSecondary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Passo de carga: dois quadrados de 34 px, encostados, como um controle único.
class AppStepper extends StatelessWidget {
  const AppStepper({
    super.key,
    required this.onDecrement,
    required this.onIncrement,
    required this.stepLabel,
  });

  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;
  final String stepLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      decoration: ShapeDecoration(
        color: c.surfaceInput,
        shape: AppShapes.superellipse(Radii.md),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _StepperHalf(
            icon: LucideIcons.minus,
            onTap: onDecrement,
            label: 'Diminuir $stepLabel',
          ),
          Container(width: 0.5, height: 20, color: c.hairlineStrong),
          _StepperHalf(
            icon: LucideIcons.plus,
            onTap: onIncrement,
            label: 'Aumentar $stepLabel',
          ),
        ],
      ),
    );
  }
}

class _StepperHalf extends StatelessWidget {
  const _StepperHalf({
    required this.icon,
    required this.onTap,
    required this.label,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          width: 38,
          height: 34,
          child: Center(child: Icon(icon, size: 17, color: c.textSecondary)),
        ),
      ),
    );
  }
}

/// Seletor segmentado. O `SegmentedButton` do Material tem 40 px de altura,
/// bordas grossas e ícone de "selecionado" — pesado demais para trocar métrica
/// num gráfico.
///
/// O polegar desliza de um segmento para o outro com mola, como o
/// `UISegmentedControl`, em vez de o realce trocar de lugar num corte.
class AppSegmented<T> extends StatelessWidget {
  const AppSegmented({
    super.key,
    required this.segments,
    required this.selected,
    required this.onChanged,
  });

  final Map<T, String> segments;
  final T selected;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final keys = segments.keys.toList();
    final n = keys.length;
    final index = keys.indexOf(selected);

    return Container(
      height: 36,
      padding: const EdgeInsets.all(2),
      decoration: ShapeDecoration(
        color: c.fill,
        shape: AppShapes.superellipse(Radii.sm),
      ),
      child: Stack(
        children: [
          if (index >= 0)
            AnimatedAlign(
              duration: const Duration(milliseconds: 160),
              curve: const Cubic(0.3, 1.25, 0.45, 1),
              alignment: Alignment(n == 1 ? 0 : -1 + 2 * index / (n - 1), 0),
              child: FractionallySizedBox(
                widthFactor: 1 / n,
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: ShapeDecoration(
                    color: c.isDark ? c.surfaceInput : c.surface,
                    shape: AppShapes.superellipse(Radii.sm - 2),
                    shadows: [
                      BoxShadow(
                        color: Colors.black.withValues(
                          alpha: c.isDark ? 0.3 : 0.12,
                        ),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          Row(
            children: [
              for (final entry in segments.entries)
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(entry.key),
                    child: Center(
                      child: AnimatedDefaultTextStyle(
                        duration: AppDurations.fast,
                        style: AppText.footnote.copyWith(
                          color: c.textPrimary,
                          fontWeight: entry.key == selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        child: Text(entry.value),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Chip de filtro, em cápsula sem borda: inativo sobre a superfície do
/// cartão, ativo tingido na cor do grupo muscular.
class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Quando presente, é a cor do grupo muscular do chip.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = accent ?? c.accent;

    return PressScale(
      onTap: onTap,
      scale: 0.94,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: Space.lg + 2),
        decoration: ShapeDecoration(
          color: selected
              ? tone.withValues(alpha: c.isDark ? 0.24 : 0.16)
              : c.surface,
          shape: const StadiumBorder(),
        ),
        child: Center(
          widthFactor: 1,
          child: Text(
            label,
            style: AppText.subheadline.copyWith(
              color: selected ? tone : c.textPrimary,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

/// Linha de escolha única, no lugar do `RadioListTile`. O indicador é um
/// check discreto à direita, como nas listas do iOS.
class AppChoiceRow<T> extends StatelessWidget {
  const AppChoiceRow({
    super.key,
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    this.subtitle,
  });

  final T value;
  final T groupValue;
  final ValueChanged<T> onChanged;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isSelected = value == groupValue;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => onChanged(value),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: Heights.row),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.xl,
            vertical: Space.md,
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: AppText.body.copyWith(color: c.textPrimary),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 1),
                      Text(
                        subtitle!,
                        style: AppText.subheadline.copyWith(
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: Space.md),
              if (isSelected)
                Icon(LucideIcons.check, size: 19, color: c.accent)
              else
                const SizedBox(width: 19),
            ],
          ),
        ),
      ),
    );
  }
}
