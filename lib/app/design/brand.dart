import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../theme.dart';

/// Nome do app num lugar só: barra, imagem exportada e launcher leem daqui.
const appName = 'Weighty';

/// Versão mostrada nos Ajustes. Um teste garante que ela não se descole do
/// `version:` do pubspec — duas fontes de verdade sem trava sempre divergem.
const appVersion = '1.2.0';

const appAuthor = 'Luan Veríssimo';

const appCredit = 'Desenvolvido por $appAuthor';

/// O ano sai do relógio, não de uma constante: linha de direitos com ano fixo
/// envelhece em silêncio, e ninguém revisa o rodapé de um app pessoal em
/// janeiro.
String appRights({DateTime? now}) =>
    '© ${(now ?? DateTime.now()).year} · Todos os direitos reservados';

/// Cores da marca. **Não** seguem o tema de propósito: o ícone do launcher e a
/// imagem que vai para a galeria existem fora do app, onde não há claro nem
/// escuro para consultar.
abstract final class Brand {
  static const bronze = Color(0xFFE0A64B);
  static const bronzeDeep = Color(0xFFB07A22);
  static const ink = Color(0xFF0A0C0F);
  static const inkRaised = Color(0xFF191D23);
  static const paper = Color(0xFFF2F3F5);
}

/// Proporções da marca, em fração do lado da caixa — é o que faz o desenho ser
/// o mesmo em 20 px e em 512.
///
/// A anilha vista de frente tem três partes, e é a proporção entre elas que
/// separa o desenho de um gráfico de rosca qualquer: **aro** largo e claro,
/// **corpo** apagado, e um **furo pequeno**. Anel fino com buraco grande lê
/// como rosca; disco cheio com furo pequeno lê como anilha.
abstract final class _Mark {
  static const bodyRadius = 0.400;

  /// O corpo é o mesmo bronze rebaixado — não uma segunda cor. Assim a marca
  /// funciona sobre claro e sobre escuro sem ter duas paletas.
  static const bodyAlpha = 0.42;

  /// Furo da anilha. Pequeno de propósito.
  static const boreRadius = 0.100;

  /// O aro é o arco de evolução: ocupa a faixa externa do disco.
  static const rimStroke = 0.100;

  /// A abertura do aro. Pequena e fora do eixo: no centro do topo ela viraria
  /// uma ferradura, e grande demais parece um pedaço faltando.
  static const gapDeg = 62.0;
  static const gapCenterDeg = 45.0;
}

/// Quanto do lado da caixa o desenho realmente ocupa: o raio do corpo mais
/// metade do traço do aro. Quem dimensiona a marca pelo diâmetro visível
/// precisa deste fator.
const markVisualRatio = (_Mark.bodyRadius + _Mark.rimStroke / 2) * 2;

double _rad(double deg) => deg * math.pi / 180;

/// Desenha a marca centrada na caixa. Função solta, não widget, porque o
/// gerador do ícone do launcher pinta direto num canvas — é o que garante que
/// o ícone e a marca dentro do app nunca divirjam.
///
/// [progress] encurta o aro (0 a 1), para animar a marca.
void paintWeightyMark(
  Canvas canvas,
  Size size, {
  required Color plate,
  required Color arc,
  double progress = 1.0,
}) {
  final side = math.min(size.width, size.height);
  final center = Offset(size.width / 2, size.height / 2);

  // O furo é vazado, não pintado na cor do fundo: a marca precisa poder ficar
  // sobre qualquer superfície, inclusive a foto de fundo do launcher.
  canvas.saveLayer(Offset.zero & size, Paint());
  canvas.drawCircle(
    center,
    _Mark.bodyRadius * side,
    Paint()..color = plate.withValues(alpha: plate.a * _Mark.bodyAlpha),
  );
  canvas.drawCircle(
    center,
    _Mark.boreRadius * side,
    Paint()..blendMode = BlendMode.clear,
  );
  canvas.restore();

  if (progress <= 0) return;

  canvas.drawArc(
    Rect.fromCircle(
      center: center,
      radius: (_Mark.bodyRadius - _Mark.rimStroke / 2) * side,
    ),
    _rad(_Mark.gapCenterDeg + _Mark.gapDeg / 2),
    _rad(360 - _Mark.gapDeg) * progress.clamp(0.0, 1.0),
    false,
    Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _Mark.rimStroke * side
      ..strokeCap = StrokeCap.round
      ..color = arc,
  );
}

/// O símbolo, sozinho. Usa a cor de destaque do tema quando nada é passado,
/// então funciona no claro e no escuro sem configuração.
class WeightyMark extends StatelessWidget {
  const WeightyMark({
    super.key,
    this.size = 26,
    this.color,
    this.arcColor,
    this.progress = 1.0,
  });

  final double size;
  final Color? color;
  final Color? arcColor;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final tone = color ?? context.colors.accent;
    return CustomPaint(
      size: Size.square(size),
      painter: _MarkPainter(
        plate: tone,
        arc: arcColor ?? tone,
        progress: progress,
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  const _MarkPainter({
    required this.plate,
    required this.arc,
    required this.progress,
  });

  final Color plate;
  final Color arc;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) => paintWeightyMark(
    canvas,
    size,
    plate: plate,
    arc: arc,
    progress: progress,
  );

  @override
  bool shouldRepaint(_MarkPainter old) =>
      old.plate != plate || old.arc != arc || old.progress != progress;
}

/// Altura de maiúscula da Inter, em em (capHeight 1490 de 2048 unidades).
const _interCapHeight = 0.727;

/// Símbolo + nome, dimensionados um pelo outro.
///
/// A marca é medida pela **altura de maiúscula** do texto, não pelo corpo da
/// fonte. Era daí que vinha o desalinhamento: 26 px de diâmetro ao lado de um
/// texto de 28 px deixava o símbolo 19% mais alto que o "W", com a barriga
/// passando da linha de base — e o olho, que se apoia na linha de base, lê isso
/// como marca torta e grande demais.
///
/// Centralizar pela caixa de linha já estava certo e não precisa de conserto:
/// na Inter a altura de maiúscula (0,727 em) coincide com `ascender − descender`
/// (0,728 em), então o centro da caixa de linha e o centro da faixa de
/// maiúsculas caem no mesmo ponto — para qualquer `height` de estilo.
class WeightyLockup extends StatelessWidget {
  const WeightyLockup({
    super.key,
    this.style,
    this.markSize,
    this.color,
    this.markColor,
  });

  final TextStyle? style;

  /// Diâmetro visual da marca. Por padrão sai da altura de maiúscula do texto,
  /// que é o que mantém as duas partes proporcionais em qualquer tamanho.
  final double? markSize;

  final Color? color;
  final Color? markColor;

  /// Um círculo do tamanho exato da maiúscula parece um fio menor que ela; 4%
  /// compensa sem a barriga passar da linha de base.
  static const _markToCapHeight = 1.04;

  @override
  Widget build(BuildContext context) {
    // O tema só é consultado para o que não foi passado. Com as duas cores
    // dadas, o lockup desenha fora de qualquer tema — é o que deixa a imagem
    // exportada ter uma paleta própria em vez de herdar claro/escuro.
    final c = (color == null || markColor == null) ? context.colors : null;

    final text = style ?? AppText.title2;
    final capHeight = (text.fontSize ?? 16) * _interCapHeight;
    final diameter = markSize ?? capHeight * _markToCapHeight;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // A caixa do painter é maior que o desenho: o símbolo ocupa
        // [markVisualRatio] do lado. Sem descontar isso, "diâmetro" seria uma
        // medida que não corresponde a nada visível na tela.
        WeightyMark(
          size: diameter / markVisualRatio,
          color: markColor ?? c!.accent,
        ),
        SizedBox(width: capHeight * 0.42),
        Text(
          appName,
          style: text.copyWith(
            color: color ?? c!.textPrimary,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}
