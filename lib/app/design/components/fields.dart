import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../theme.dart';

/// Célula numérica de carga ou repetição.
///
/// Duas decisões de alinhamento importam aqui: o número é alinhado à direita
/// (dígitos comparáveis entre linhas) e a célula **não tem rótulo interno**. O
/// desalinhamento anterior vinha de um rótulo "alvo 10" embaixo do campo de
/// reps: dentro de uma Row centralizada, a coluna mais alta empurrava o input
/// para cima. Os rótulos agora vivem no cabeçalho da tabela.
class NumberCell extends StatefulWidget {
  const NumberCell({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.decimal = false,
    this.enabled = true,
    this.emphasized = false,
  });

  /// Valor atual. Zero conta como vazio.
  final double value;

  /// O que foi feito na última vez, mostrado apagado dentro da célula vazia.
  final String? hint;

  final ValueChanged<double> onChanged;
  final bool decimal;
  final bool enabled;

  /// A célula de carga recebe um pouco mais de presença que a de repetições.
  final bool emphasized;

  @override
  State<NumberCell> createState() => _NumberCellState();
}

class _NumberCellState extends State<NumberCell> {
  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
    _focus.addListener(() {
      if (!_focus.hasFocus) _syncFromValue();
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(NumberCell old) {
    super.didUpdateWidget(old);
    // Só reescreve de fora quando o campo não está em foco, senão o valor que
    // volta do banco atropela o que está sendo digitado.
    if (old.value != widget.value && !_focus.hasFocus) _syncFromValue();
  }

  void _syncFromValue() {
    final text = _format(widget.value);
    if (_controller.text != text) _controller.text = text;
  }

  String _format(double value) {
    if (value == 0) return '';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString().replaceAll('.', ',');
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final focused = _focus.hasFocus;

    return SizedBox(
      height: Heights.cell,
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        enabled: widget.enabled,
        textAlign: TextAlign.right,
        keyboardType: TextInputType.numberWithOptions(decimal: widget.decimal),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
            widget.decimal ? RegExp(r'[0-9,.]') : RegExp(r'[0-9]'),
          ),
          // Sem limite, um toque errado grava "6305 kg" no histórico.
          LengthLimitingTextInputFormatter(widget.decimal ? 6 : 3),
        ],
        // A carga ganha um pouco mais de peso que as repetições: é o número que
        // realmente se compara entre semanas.
        style: AppText.numberCell.copyWith(
          color: c.textPrimary,
          fontWeight: widget.emphasized ? FontWeight.w600 : FontWeight.w500,
        ),
        cursorWidth: 1.5,
        cursorRadius: const Radius.circular(1),
        decoration: InputDecoration(
          hintText: widget.hint,
          hintStyle: AppText.numberCell.copyWith(color: c.textGhost),
          isDense: true,
          filled: true,
          fillColor: focused ? c.accentSubtle : c.surfaceInput,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: Space.lg,
            vertical: Space.md,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(Radii.sm),
            borderSide: BorderSide(color: c.accent, width: 1),
          ),
        ),
        onChanged: (text) {
          final parsed = double.tryParse(text.replaceAll(',', '.'));
          widget.onChanged(parsed ?? 0);
        },
      ),
    );
  }
}

/// Carga da série em foco: editável, mas com corpo de número em destaque.
///
/// É um campo de texto de verdade, não um rótulo que abre um editor — tocar e
/// digitar tem que funcionar de primeira quando o passo de 2,5 kg não serve.
class BigNumberField extends StatefulWidget {
  const BigNumberField({
    super.key,
    required this.value,
    required this.onChanged,
    this.hint,
    this.unit = 'kg',
  });

  final double value;
  final String? hint;
  final String unit;
  final ValueChanged<double> onChanged;

  @override
  State<BigNumberField> createState() => _BigNumberFieldState();
}

class _BigNumberFieldState extends State<BigNumberField> {
  late final TextEditingController _controller;
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _format(widget.value));
    _focus.addListener(() {
      if (!_focus.hasFocus) _sync();
      setState(() {});
    });
  }

  @override
  void didUpdateWidget(BigNumberField old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value && !_focus.hasFocus) _sync();
  }

  void _sync() {
    final text = _format(widget.value);
    if (_controller.text != text) _controller.text = text;
  }

  String _format(double value) {
    if (value == 0) return '';
    if (value == value.roundToDouble()) return value.toStringAsFixed(0);
    return value.toString().replaceAll('.', ',');
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        IntrinsicWidth(
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 56),
            child: TextField(
              controller: _controller,
              focusNode: _focus,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
                LengthLimitingTextInputFormatter(6),
              ],
              style: AppText.numberLarge.copyWith(
                color: c.textPrimary,
                fontSize: 32,
              ),
              cursorColor: c.accent,
              cursorWidth: 2,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintStyle: AppText.numberLarge.copyWith(
                  color: c.textGhost,
                  fontSize: 32,
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
              ),
              onChanged: (text) => widget.onChanged(
                double.tryParse(text.replaceAll(',', '.')) ?? 0,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.only(left: 3),
          child: Text(
            widget.unit,
            style: AppText.footnote.copyWith(color: c.textTertiary),
          ),
        ),
      ],
    );
  }
}

/// Campo de texto do app (nome de treino, busca).
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.hint,
    this.autofocus = false,
    this.prefixIcon,
    this.onChanged,
    this.onSubmitted,
    this.onClear,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController? controller;
  final String? hint;
  final bool autofocus;
  final IconData? prefixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Quando presente, mostra o botão de limpar à direita. Deixa visível que há
  /// um filtro ativo — a busca antes ficava aplicada sem nada indicando.
  final VoidCallback? onClear;

  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return TextField(
      controller: controller,
      autofocus: autofocus,
      textCapitalization: textCapitalization,
      style: AppText.body.copyWith(color: c.textPrimary),
      cursorColor: c.accent,
      cursorWidth: 1.5,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppText.body.copyWith(color: c.textGhost),
        prefixIcon: prefixIcon == null
            ? null
            : Icon(prefixIcon, size: 18, color: c.textTertiary),
        prefixIconConstraints: const BoxConstraints(minWidth: 38),
        suffixIcon: onClear == null
            ? null
            : GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClear,
                child: Icon(
                  LucideIcons.circleX,
                  size: 17,
                  color: c.textTertiary,
                ),
              ),
        suffixIconConstraints: const BoxConstraints(minWidth: 40),
        isDense: true,
        filled: true,
        fillColor: c.surfaceInput,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: Space.lg,
          vertical: Space.lg,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(Radii.md),
          borderSide: BorderSide(color: c.accent, width: 1),
        ),
      ),
    );
  }
}
