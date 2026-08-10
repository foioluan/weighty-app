import 'dart:io';

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treino/app/design/brand.dart';
import 'package:treino/app/design/tokens.dart';

void main() {
  test('a versão dos Ajustes acompanha a do pubspec', () {
    // Duas fontes de verdade sem trava sempre divergem, e a que aparece na tela
    // é a que fica errada — o usuário lê 1.0.0 num app que já é 1.1.0.
    final pubspec = File('pubspec.yaml').readAsLinesSync();
    final line = pubspec.firstWhere((l) => l.startsWith('version:'));
    final declared = line.split(':')[1].trim().split('+').first;

    expect(
      appVersion,
      declared,
      reason:
          'appVersion em lib/app/design/brand.dart precisa bater com o '
          'version: do pubspec.yaml',
    );
  });

  test('o nome visível do Android é o mesmo da marca', () {
    // O rótulo do launcher é XML e não passa pelo compilador: só um teste
    // percebe se ele ficar para trás de uma troca de nome.
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android:label="$appName"'));
  });

  test('o fundo da abertura nativa é o mesmo do tema', () {
    // O Android pinta este quadro antes de o Flutter existir, e a cor está
    // escrita à mão num XML que nada compila junto com o Dart. Sem esta trava,
    // mexer na paleta deixaria a abertura com um fundo de outra cor e a emenda
    // apareceria como um piscar na abertura do app.
    String colorOf(String dir) {
      final xml = File(
        'android/app/src/main/res/$dir/colors.xml',
      ).readAsStringSync();
      return RegExp(
        r'name="splash_background">#([0-9A-Fa-f]{6})<',
      ).firstMatch(xml)!.group(1)!.toUpperCase();
    }

    String hexOf(Color color) => (color.toARGB32() & 0xFFFFFF)
        .toRadixString(16)
        .padLeft(6, '0')
        .toUpperCase();

    expect(colorOf('values'), hexOf(AppColors.light.bg));
    expect(colorOf('values-night'), hexOf(AppColors.dark.bg));
  });

  test('o applicationId não mudou junto com o nome', () {
    // Trocar o applicationId faz o Android tratar o app como outro e apagar o
    // histórico de treinos na atualização. Ele é intencionalmente diferente do
    // nome visível, e este teste existe para essa diferença ser uma decisão e
    // não um descuido.
    final gradle = File('android/app/build.gradle.kts').readAsStringSync();

    expect(gradle, contains('applicationId = "br.com.luan.treino"'));
  });
}
