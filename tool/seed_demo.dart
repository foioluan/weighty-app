// Gera um banco com dados de exemplo para conferir as telas no emulador.
// Usa os repositórios do app, então o schema nunca sai de sincronia.
//
//   SEED_OUT=/caminho/treino.sqlite flutter test tool/seed_demo.dart
//
// Roda pelo flutter test porque o projeto depende do Flutter (drift_flutter),
// e `dart run` não consegue compilar isso. Fica em tool/, fora do glob de
// test/, então não entra na suíte normal nem no APK.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:treino/data/db/database.dart';

import 'demo_data.dart';

void main() {
  test(
    'gera o banco de demonstração',
    _seed,
    timeout: const Timeout(Duration(minutes: 3)),
  );
}

Future<void> _seed() async {
  final path = Platform.environment['SEED_OUT'] ?? 'demo.sqlite';
  final file = File(path);
  if (file.existsSync()) file.deleteSync();

  final db = AppDatabase(NativeDatabase(file));
  final ids = await seedDemo(db);

  // Deixa os ids usados aparecerem no output para inspeção rápida.
  final sessionCount = (await db.select(db.sessions).get()).length;
  final segmentCount = (await db.select(db.setSegments).get()).length;
  await db.close();

  stdout.writeln('banco: $path');
  stdout.writeln('sessoes: $sessionCount, segmentos: $segmentCount');
  stdout.writeln('rotinas: upper=${ids.upper} lower=${ids.lower}');
  stdout.writeln(
    'exercicios: remada=${ids.remada} desenv=${ids.desenvolvimento} '
    'rosca=${ids.rosca}',
  );
}
