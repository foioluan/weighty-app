import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../domain/metrics/progress_metrics.dart';
import '../../../domain/models/enums.dart';
import '../../theme.dart';

/// Selo do exercício: quadrado arredondado com as iniciais, tingido na cor do
/// grupo muscular. Substitui o ponto de 7 px — dá peso visual à linha e deixa
/// a lista reconhecível de relance, que é o papel que a miniatura cumpre nos
/// apps de treino (aqui sem depender de banco de imagens).
class ExerciseAvatar extends StatelessWidget {
  const ExerciseAvatar({
    super.key,
    required this.name,
    required this.group,
    this.size = 36,
  });

  final String name;
  final MuscleGroup group;
  final double size;

  /// Iniciais das duas primeiras palavras relevantes: "Supino reto barra" → SR.
  static String initialsOf(String name) {
    const skip = {'de', 'da', 'do', 'na', 'no', 'em', 'com', 'a', 'o'};
    final words = name
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !skip.contains(w.toLowerCase()))
        .toList();

    if (words.isEmpty) return '?';
    if (words.length == 1) {
      final word = words.first;
      return (word.length == 1 ? word : word.substring(0, 2)).toUpperCase();
    }
    return (words[0][0] + words[1][0]).toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final tone = c.forMuscleGroup(group);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      // Sem contorno, como os ícones de Ajustes do iOS: o tom de fundo já
      // basta, e a linha em volta só engrossava o desenho.
      decoration: ShapeDecoration(
        color: tone.withValues(alpha: c.isDark ? 0.2 : 0.14),
        shape: AppShapes.superellipse(size * 0.28),
      ),
      child: Text(
        initialsOf(name),
        style: AppText.caption.copyWith(
          color: tone,
          fontSize: size * 0.36,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
    );
  }
}

/// Ponto na cor do grupo muscular, para onde o selo é grande demais.
class MuscleDot extends StatelessWidget {
  const MuscleDot(this.group, {super.key, this.size = 7});

  final MuscleGroup group;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: context.colors.forMuscleGroup(group),
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Barra vertical na cor do grupo, para a borda esquerda de um card.
class MuscleBar extends StatelessWidget {
  const MuscleBar(this.group, {super.key});

  final MuscleGroup group;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 3,
      decoration: BoxDecoration(
        color: context.colors.forMuscleGroup(group),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }
}

/// Cartão de métrica: rótulo pequeno em cima, número grande, delta embaixo.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    this.footnote,
    this.footnoteColor,
  });

  final String label;
  final String value;
  final String? unit;
  final String? footnote;
  final Color? footnoteColor;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ClipRSuperellipse(
      borderRadius: BorderRadius.circular(Radii.lg - 6),
      child: ColoredBox(
        color: c.surface,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.lg + 2,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Shrink(
                Text(
                  label.isEmpty
                      ? label
                      : label[0].toUpperCase() + label.substring(1),
                  style: AppText.footnote.copyWith(
                    color: c.textSecondary,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                ),
              ),
              const SizedBox(height: Space.xs),
              // Encolhe em vez de cortar: "10.1…" escondia justamente o número,
              // que é a única coisa que o cartão existe para mostrar.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      value,
                      style: AppText.numberMedium.copyWith(
                        color: c.textPrimary,
                      ),
                      maxLines: 1,
                    ),
                    if (unit != null)
                      Padding(
                        padding: const EdgeInsets.only(left: 2),
                        child: Text(
                          unit!,
                          style: AppText.footnote.copyWith(
                            color: c.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (footnote != null) ...[
                const SizedBox(height: Space.xs),
                _Shrink(
                  Text(
                    footnote!,
                    style: AppText.caption.copyWith(
                      color: footnoteColor ?? c.textTertiary,
                    ),
                    maxLines: 1,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Texto de uma linha que encolhe em vez de cortar, nos cartões estreitos.
class _Shrink extends StatelessWidget {
  const _Shrink(this.child);

  final Widget child;

  @override
  Widget build(BuildContext context) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: Alignment.centerLeft,
    child: child,
  );
}

/// Etiqueta de veredito. Sem preenchimento sólido: só o texto na cor, com uma
/// seta. Uma pílula colorida por exercício sujaria a lista.
class VerdictBadge extends StatelessWidget {
  const VerdictBadge({super.key, required this.verdict, this.detail});

  final Verdict verdict;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final (label, tone, icon) = switch (verdict) {
      Verdict.evoluiu => ('Evoluiu', c.up, LucideIcons.arrowUp),
      Verdict.reduziu => ('Reduziu', c.down, LucideIcons.arrowDown),
      Verdict.manteve => ('Manteve', c.flat, LucideIcons.minus),
      Verdict.semReferencia => ('Primeira vez', c.textTertiary, null),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 13, color: tone),
          const SizedBox(width: 2),
        ],
        Text(
          detail == null ? label : detail!,
          style: AppText.footnote.copyWith(
            color: tone,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Cabeçalho de colunas de uma tabela de séries. Existe para os rótulos não
/// morarem dentro das células — é o que mantém os números alinhados.
class ColumnHeader extends StatelessWidget {
  const ColumnHeader({
    super.key,
    required this.columns,
    this.leadingWidth = 20,
    // 4 do espaçador + 34 do botão de concluir: o cabeçalho tem que reservar
    // exatamente a mesma largura da linha, senão as colunas saem tortas.
    this.trailingWidth = 38,
  });

  /// Rótulos, da esquerda para a direita, cada um sobre uma coluna flexível.
  final List<String> columns;
  final double leadingWidth;
  final double trailingWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.md,
        Space.lg,
        Space.sm,
      ),
      child: Row(
        children: [
          SizedBox(width: leadingWidth),
          for (final label in columns) ...[
            const SizedBox(width: Space.md),
            Expanded(
              child: Text(
                label.toUpperCase(),
                textAlign: TextAlign.right,
                style: AppText.overline.copyWith(color: c.textTertiary),
              ),
            ),
          ],
          SizedBox(width: trailingWidth),
        ],
      ),
    );
  }
}
