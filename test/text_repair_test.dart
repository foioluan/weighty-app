import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:treino/data/db/text_repair.dart';

/// Simula a corrupção real: os bytes UTF-8 do texto lidos como Latin-1.
String corrupt(String value) => latin1.decode(utf8.encode(value));

void main() {
  group('repairDoubleEncoded', () {
    test('reverte a corrupção observada no aparelho', () {
      // Exatamente o que apareceu na tela: "ElevaÃ§Ã£o pÃ©lvica".
      expect(repairDoubleEncoded('ElevaÃ§Ã£o pÃ©lvica'), 'Elevação pélvica');
      expect(
        repairDoubleEncoded('Desenvolvimento mÃ¡quina'),
        'Desenvolvimento máquina',
      );
    });

    test('reverte todos os nomes acentuados do catálogo', () {
      const nomes = [
        'Elevação de pernas suspenso',
        'Tríceps pulley corda',
        'Rosca scott',
        'Abdominal máquina',
        'Agachamento búlgaro',
        'Panturrilha em pé',
        'Glúteo na polia',
        'Trapézio',
        'Antebraço',
        'Bíceps',
      ];

      for (final nome in nomes) {
        final quebrado = corrupt(nome);
        if (quebrado == nome) continue; // sem acento, nada a corromper
        expect(repairDoubleEncoded(quebrado), nome, reason: nome);
      }
    });

    test('não mexe em texto que já está correto', () {
      for (final nome in [
        'Supino reto barra',
        'Elevação pélvica',
        'Tríceps testa barra',
        'Upper 1',
        'Agachamento búlgaro',
      ]) {
        expect(repairDoubleEncoded(nome), isNull, reason: nome);
      }
    });

    test('não mexe em texto sem a assinatura da corrupção', () {
      expect(repairDoubleEncoded('Treino da manhã'), isNull);
      expect(repairDoubleEncoded('Peito e tríceps'), isNull);
      expect(repairDoubleEncoded(''), isNull);
    });

    test('recusa texto com caractere fora de Latin-1', () {
      // O Ã sozinho ativaria a heurística, mas o emoji não cabe em Latin-1:
      // não pode ter vindo desta corrupção, então fica intocado.
      expect(repairDoubleEncoded('Treino Ã 💪'), isNull);
      expect(repairDoubleEncoded('Ã—'), isNull);
    });

    test('recusa quando a reinterpretação não dá UTF-8 válido', () {
      // Â seguido de espaço não forma sequência UTF-8 válida (0xC2 0x20).
      expect(repairDoubleEncoded('Treino Â com Ã espaços'), isNull);
    });

    test('é idempotente: reparar duas vezes não estraga', () {
      final uma = repairDoubleEncoded('ElevaÃ§Ã£o pÃ©lvica')!;
      expect(uma, 'Elevação pélvica');
      expect(repairDoubleEncoded(uma), isNull);
    });

    test('aguenta dupla corrupção sem inventar resultado', () {
      // Texto corrompido duas vezes: uma passada devolve o estado intermediário,
      // não o original — e isso é correto, não deve adivinhar.
      final duasVezes = corrupt(corrupt('Elevação'));
      final umaPassada = repairDoubleEncoded(duasVezes);
      expect(umaPassada, corrupt('Elevação'));
      expect(repairDoubleEncoded(umaPassada!), 'Elevação');
    });
  });
}
