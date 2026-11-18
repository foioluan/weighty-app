import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../formatting.dart';
import '../../theme.dart';
import '../haptics.dart';
import 'controls.dart';
import 'feedback.dart';
import 'glass.dart';

/// Teclado numérico do app, em folha.
///
/// Substitui o teclado do sistema na sessão e no editor. O do Android sobe
/// cobrindo meia tela, muda de layout conforme o aparelho, tem teclas de 40 px
/// e esconde o próprio campo que se está editando. Este tem teclas de 56 px, o
/// valor grande no topo e o atalho "usar última vez" — o caso mais comum entre
/// séries.
///
/// Devolve o valor confirmado, ou `null` se a folha foi fechada sem "OK". Zero
/// conta como vazio, como nas células.
Future<double?> showNumberPad(
  BuildContext context, {
  required String title,
  double initial = 0,
  bool decimal = false,
  double? lastValue,
  String? unit,
}) async {
  final result = await showAppSheet<List<double>>(
    context,
    builder: (_) => _NumberPad(
      title: title,
      fields: [_PadField(label: unit, initial: initial, decimal: decimal)],
      lastValue: lastValue,
    ),
  );
  return result?.first;
}

/// O mesmo teclado com dois valores — a faixa de repetições "de" e "até".
///
/// Devolve `(de, até)` com `null` onde o campo ficou vazio, ou `null` se a
/// folha foi fechada sem confirmar.
Future<(int?, int?)?> showRangePad(
  BuildContext context, {
  required String title,
  int? from,
  int? to,
}) async {
  final result = await showAppSheet<List<double>>(
    context,
    builder: (_) => _NumberPad(
      title: title,
      fields: [
        _PadField(label: 'de', initial: (from ?? 0).toDouble()),
        _PadField(label: 'até', initial: (to ?? 0).toDouble()),
      ],
    ),
  );
  if (result == null) return null;
  int? asInt(double v) => v == 0 ? null : v.round();
  return (asInt(result[0]), asInt(result[1]));
}

class _PadField {
  const _PadField({this.label, this.initial = 0, this.decimal = false});

  final String? label;
  final double initial;
  final bool decimal;
}

class _NumberPad extends StatefulWidget {
  const _NumberPad({required this.title, required this.fields, this.lastValue});

  final String title;
  final List<_PadField> fields;
  final double? lastValue;

  @override
  State<_NumberPad> createState() => _NumberPadState();
}

class _NumberPadState extends State<_NumberPad> {
  late final List<String> _buffers = [
    for (final f in widget.fields) f.initial > 0 ? formatWeight(f.initial) : '',
  ];

  /// O primeiro toque substitui o valor que veio pronto, em vez de digitar
  /// depois dele — como no iOS. Sem isso, trocar 75 por 80 exigia apagar
  /// antes.
  late final List<bool> _fresh = [for (final _ in widget.fields) true];

  var _active = 0;

  _PadField get _field => widget.fields[_active];

  void _type(String key) {
    Haptics.tick();
    setState(() {
      var text = _fresh[_active] ? '' : _buffers[_active];
      _fresh[_active] = false;

      if (key == ',') {
        if (!_field.decimal || text.contains(',')) return;
        text = text.isEmpty ? '0,' : '$text,';
      } else {
        final parts = text.split(',');
        // Até 999 inteiros e duas casas: anilha de 1,25 é a menor fração que
        // existe numa academia.
        if (parts.length == 2 && parts[1].length >= 2) return;
        if (parts.length == 1 && parts[0].length >= 3) return;
        text = text == '0' ? key : '$text$key';
      }
      _buffers[_active] = text;
    });
  }

  void _backspace() {
    Haptics.tick();
    setState(() {
      final text = _buffers[_active];
      _buffers[_active] = _fresh[_active] || text.isEmpty
          ? ''
          : text.substring(0, text.length - 1);
      _fresh[_active] = false;
    });
  }

  void _useLast() {
    Haptics.tick();
    setState(() {
      _buffers[_active] = formatWeight(widget.lastValue!);
      _fresh[_active] = true;
    });
  }

  double _parse(String text) => double.tryParse(text.replaceAll(',', '.')) ?? 0;

  void _confirm() {
    Haptics.confirm();
    Navigator.pop(context, [for (final b in _buffers) _parse(b)]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        Space.xxl,
        Space.xs,
        Space.xxl,
        Space.xl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  widget.title,
                  style: AppText.headline.copyWith(color: c.textPrimary),
                ),
              ),
              // "OK" no alto, como o "Concluído" das folhas do iOS: a ação
              // cheia de largura total do app continua sendo só "Concluir
              // série".
              AppButton(label: 'OK', compact: true, onPressed: _confirm),
            ],
          ),
          const SizedBox(height: Space.xl),
          Row(
            children: [
              for (var i = 0; i < widget.fields.length; i++) ...[
                if (i > 0) const SizedBox(width: Space.md),
                Expanded(child: _display(context, i)),
              ],
            ],
          ),
          if (widget.lastValue != null && widget.lastValue! > 0) ...[
            const SizedBox(height: Space.md),
            Center(
              child: AppButton(
                label: 'Usar última vez · ${formatWeight(widget.lastValue!)}',
                icon: LucideIcons.history,
                style: AppButtonStyle.tinted,
                compact: true,
                onPressed: _useLast,
              ),
            ),
          ],
          const SizedBox(height: Space.xl),
          _keys(context),
        ],
      ),
    );
  }

  Widget _display(BuildContext context, int index) {
    final c = context.colors;
    final field = widget.fields[index];
    final text = _buffers[index];
    final active = index == _active;
    final many = widget.fields.length > 1;

    final value = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        if (many && field.label != null) ...[
          Text(
            field.label!,
            style: AppText.subheadline.copyWith(color: c.textSecondary),
          ),
          const SizedBox(width: Space.sm),
        ],
        Text(
          text.isEmpty ? '0' : text,
          style: AppText.numberLarge.copyWith(
            fontSize: 44,
            color: text.isEmpty
                ? c.textGhost
                // O valor que veio pronto fica um tom abaixo até o primeiro
                // toque: é o aviso de que digitar vai substituí-lo.
                : (_fresh[index] && active ? c.textSecondary : c.textPrimary),
          ),
        ),
        if (!many && field.label != null) ...[
          const SizedBox(width: Space.xs),
          Text(
            field.label!,
            style: AppText.headline.copyWith(color: c.textSecondary),
          ),
        ],
      ],
    );

    return Semantics(
      button: many,
      selected: active,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: many ? () => setState(() => _active = index) : null,
        child: AnimatedContainer(
          duration: AppDurations.fast,
          height: 76,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: c.surfaceInput,
            shape: AppShapes.superellipse(
              Radii.md + 6,
              side: many && active
                  ? BorderSide(color: c.accent, width: 1.5)
                  : BorderSide.none,
            ),
          ),
          child: FittedBox(fit: BoxFit.scaleDown, child: value),
        ),
      ),
    );
  }

  Widget _keys(BuildContext context) {
    final rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
      [_field.decimal ? ',' : '', '0', '⌫'],
    ];

    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0) const SizedBox(height: Space.md),
          Row(
            children: [
              for (var k = 0; k < 3; k++) ...[
                if (k > 0) const SizedBox(width: Space.md),
                Expanded(child: _key(context, rows[r][k])),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _key(BuildContext context, String key) {
    final c = context.colors;
    if (key.isEmpty) return const SizedBox(height: 56);

    final backspace = key == '⌫';
    return Semantics(
      button: true,
      label: backspace ? 'Apagar' : (key == ',' ? 'Vírgula' : key),
      excludeSemantics: true,
      child: PressScale(
        onTap: backspace ? _backspace : () => _type(key),
        scale: 0.92,
        child: Container(
          height: 56,
          alignment: Alignment.center,
          decoration: ShapeDecoration(
            color: backspace ? Colors.transparent : c.fill,
            shape: AppShapes.superellipse(Radii.md + 4),
          ),
          child: backspace
              ? Icon(LucideIcons.delete, size: 24, color: c.textPrimary)
              : Text(
                  key,
                  style: AppText.title2.copyWith(
                    color: c.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
        ),
      ),
    );
  }
}
