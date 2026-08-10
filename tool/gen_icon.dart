// Gera os PNGs do ícone do launcher a partir do mesmo painter usado dentro do
// app, em lib/app/design/brand.dart.
//
//   flutter test tool/gen_icon.dart
//   PREVIEW_OUT=/tmp/marca.png flutter test tool/gen_icon.dart
//
// Roda pelo flutter test porque precisa do engine para rasterizar (o mesmo
// caminho que os testes de golden usam); `dart run` não tem rasterizador.
//
// Fica em tool/, fora do glob de test/, então não entra na suíte nem no APK.
// Rodar de novo é seguro: sobrescreve os arquivos com o desenho atual.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treino/app/design/brand.dart';

/// Densidades do Android. O ícone antigo é 48 dp, o adaptativo é 108 dp — a
/// diferença é a área que o sistema recorta com a máscara dele.
const _densities = {
  'mdpi': 1.0,
  'hdpi': 1.5,
  'xhdpi': 2.0,
  'xxhdpi': 3.0,
  'xxxhdpi': 4.0,
};

const _resDir = 'android/app/src/main/res';

/// Quanto da caixa o símbolo ocupa.
///
/// No adaptativo é bem menor: só os 72 dp centrais dos 108 são garantidos, e a
/// máscara do sistema come o resto. Em 0,52 o desenho fica em ~62% do diâmetro
/// visível, que é a proporção que os ícones do sistema usam — com 0,60 ele
/// encostava na borda e o ícone parecia apertado ao lado dos outros.
const _legacyMarkFraction = 0.62;
const _adaptiveMarkFraction = 0.52;

void main() {
  test(
    'gera os ícones do launcher',
    _generate,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _generate() async {
  for (final entry in _densities.entries) {
    final dir = Directory('$_resDir/mipmap-${entry.key}');
    dir.createSync(recursive: true);

    final legacy = (48 * entry.value).round();
    final adaptive = (108 * entry.value).round();

    await _write('${dir.path}/ic_launcher.png', legacy, _paintLegacy);
    await _write('${dir.path}/ic_launcher_background.png', adaptive, _paintTile);
    await _write(
      '${dir.path}/ic_launcher_foreground.png',
      adaptive,
      (canvas, size) => _paintMark(canvas, size, _adaptiveMarkFraction),
    );
    // Ícone monocromático do Android 13: o sistema tinge a silhueta com a cor
    // do tema do aparelho, então aqui vai só a forma, em branco.
    await _write(
      '${dir.path}/ic_launcher_monochrome.png',
      adaptive,
      (canvas, size) => _paintMark(
        canvas,
        size,
        _adaptiveMarkFraction,
        plate: const Color(0xFFFFFFFF),
        arc: const Color(0xFFFFFFFF),
      ),
    );
  }

  final preview = Platform.environment['PREVIEW_OUT'];
  if (preview != null) await _writeContactSheet(preview);

  stdout.writeln('ícones gravados em $_resDir/mipmap-*');
}

/// Ícone antigo: azulejo cheio, com o canto arredondado desenhado por nós.
void _paintLegacy(ui.Canvas canvas, ui.Size size) {
  _paintTile(canvas, size, rounded: true);
  _paintMark(canvas, size, _legacyMarkFraction);
}

/// O fundo: quase preto, com um degradê radial e um brilho bronze atrás do
/// símbolo. Sem o brilho o azulejo fica chapado e o ícone parece recortado.
///
/// O degradê é **radial e centrado**, não diagonal: a máscara do sistema recorta
/// um círculo no meio dos 108 dp, e um degradê de canto a canto teria a parte
/// clara justamente na área descartada — o ícone chegava na tela chapado.
void _paintTile(ui.Canvas canvas, ui.Size size, {bool rounded = false}) {
  final rect = Offset.zero & size;
  final shape = rounded
      ? RRect.fromRectAndRadius(rect, Radius.circular(size.width * 0.225))
      : RRect.fromRectAndRadius(rect, Radius.zero);
  final glowCenter = rect.center.translate(0, -size.height * 0.07);

  canvas.save();
  canvas.clipRRect(shape);

  canvas.drawRRect(
    shape,
    Paint()
      ..shader = ui.Gradient.radial(glowCenter, size.width * 0.62, [
        Brand.inkRaised,
        Brand.ink,
      ]),
  );

  canvas.drawCircle(
    glowCenter,
    size.width * 0.42,
    Paint()
      ..shader = ui.Gradient.radial(glowCenter, size.width * 0.42, [
        Brand.bronze.withValues(alpha: 0.16),
        Brand.bronze.withValues(alpha: 0),
      ]),
  );

  canvas.restore();
}

void _paintMark(
  ui.Canvas canvas,
  ui.Size size,
  double fraction, {
  Color plate = Brand.bronze,
  Color arc = Brand.bronze,
}) {
  final side = size.width * fraction;
  final offset = (size.width - side) / 2;

  canvas.save();
  canvas.translate(offset, offset);
  paintWeightyMark(canvas, Size.square(side), plate: plate, arc: arc);
  canvas.restore();
}

Future<void> _write(
  String path,
  int side,
  void Function(ui.Canvas, ui.Size) paint,
) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  paint(canvas, Size.square(side.toDouble()));

  final image = await recorder.endRecording().toImage(side, side);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
}

/// Folha de contato para conferir a marca a olho: o ícone grande, o mesmo
/// desenho nos tamanhos em que ele realmente aparece, e o símbolo sozinho
/// sobre claro e sobre escuro.
Future<void> _writeContactSheet(String path) async {
  const width = 760.0;
  const height = 300.0;

  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const Rect.fromLTWH(0, 0, width, height),
    Paint()..color = const Color(0xFF2A2E34),
  );

  void tile(double x, double y, double side) {
    canvas.save();
    canvas.translate(x, y);
    _paintLegacy(canvas, Size.square(side));
    canvas.restore();
  }

  tile(24, 24, 192);
  tile(240, 24, 96);
  tile(240, 136, 48);
  tile(300, 136, 24);

  // Símbolo sem azulejo: sobre escuro e sobre claro, como aparece na barra.
  for (final (dx, bg, tone) in [
    (400.0, Brand.ink, Brand.bronze),
    (580.0, Brand.paper, const Color(0xFF9A6E14)),
  ]) {
    canvas.drawRect(
      Rect.fromLTWH(dx, 24, 160, 252),
      Paint()..color = bg,
    );
    for (final (dy, side) in [(40.0, 96.0), (160.0, 40.0), (160.0, 20.0)]) {
      canvas.save();
      canvas.translate(dx + (side == 20 ? 100 : 32), dy + (side == 96 ? 0 : 10));
      paintWeightyMark(canvas, Size.square(side), plate: tone, arc: tone);
      canvas.restore();
    }
  }

  final image = await recorder.endRecording().toImage(
    width.round(),
    height.round(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();

  File(path).writeAsBytesSync(bytes!.buffer.asUint8List());
  stdout.writeln('prévia: $path');
}
