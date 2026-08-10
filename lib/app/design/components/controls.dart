import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme.dart';

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

    final height = widget.compact ? Heights.controlCompact : Heights.control;

    final child = Row(
      mainAxisSize: widget.expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          Icon(widget.icon, size: 17, color: disabled ? c.textGhost : fg),
          const SizedBox(width: Space.sm),
        ],
        Text(
          widget.label,
          style: (widget.compact ? AppText.callout : AppText.bodyStrong)
              .copyWith(
                color: disabled ? c.textGhost : fg,
                fontWeight: FontWeight.w500,
              ),
        ),
      ],
    );

    return Semantics(
      button: true,
      enabled: !disabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: disabled ? null : (_) => setState(() => _down = true),
        onTapUp: disabled ? null : (_) => setState(() => _down = false),
        onTapCancel: disabled ? null : () => setState(() => _down = false),
        child: AnimatedOpacity(
          duration: AppDurations.fast,
          opacity: _down && widget.style != AppButtonStyle.filled ? 0.6 : 1,
          child: Container(
            height: height,
            // O padding lateral acompanha a altura: numa pílula, folga fixa
            // faz o rótulo encostar na curva quando o botão é baixo.
            padding: EdgeInsets.symmetric(horizontal: height * 0.42),
            decoration: BoxDecoration(
              color: disabled ? c.surfaceInput : bg,
              borderRadius: BorderRadius.circular(height / 2),
              border: widget.style == AppButtonStyle.tinted && !disabled
                  ? Border.all(
                      color: c.accent.withValues(alpha: 0.35),
                      width: 0.5,
                    )
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
      decoration: BoxDecoration(
        color: c.surfaceInput,
        borderRadius: BorderRadius.circular(Radii.sm),
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
    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceInput,
        borderRadius: BorderRadius.circular(Radii.sm),
      ),
      child: Row(
        children: [
          for (final entry in segments.entries)
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onChanged(entry.key),
                child: AnimatedContainer(
                  duration: AppDurations.fast,
                  decoration: BoxDecoration(
                    color: entry.key == selected
                        ? c.surface
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(Radii.sm - 2),
                    border: entry.key == selected
                        ? Border.all(color: c.hairline, width: 0.5)
                        : null,
                  ),
                  child: Center(
                    child: Text(
                      entry.value,
                      style: AppText.footnote.copyWith(
                        color: entry.key == selected
                            ? c.textPrimary
                            : c.textTertiary,
                        fontWeight: entry.key == selected
                            ? FontWeight.w500
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Chip de filtro. Sem borda quando inativo — a paleta de grupos musculares já
/// carrega cor suficiente.
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

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppDurations.fast,
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        decoration: BoxDecoration(
          color: selected ? tone.withValues(alpha: 0.16) : c.surface,
          borderRadius: BorderRadius.circular(Radii.pill),
          border: Border.all(
            color: selected ? tone.withValues(alpha: 0.5) : c.hairline,
            width: 0.5,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppText.footnote.copyWith(
              color: selected ? tone : c.textSecondary,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
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
                        style: AppText.footnote.copyWith(color: c.textTertiary),
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
