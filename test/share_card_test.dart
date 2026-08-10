import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:treino/app/design/brand.dart';
import 'package:treino/app/theme.dart';
import 'package:treino/data/db/database.dart';
import 'package:treino/data/repos/progress_repository.dart';
import 'package:treino/domain/metrics/progress_metrics.dart';
import 'package:treino/domain/models/enums.dart';
import 'package:treino/domain/models/performance.dart';
import 'package:treino/features/share/session_share_card.dart';

/// O card tem tamanho fixo: ou o conteúdo cabe em 400 × 500, ou estoura. Estes
/// testes existem para o estouro aparecer aqui e não numa imagem já salva na
/// galeria — a única coisa que a tela de imagem não consegue avisar.
///
/// Passando `SHARE_CARD_OUT=/caminho/prefixo`, cada caso também é gravado em
/// PNG para conferência visual.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('pt_BR');
    await _loadInter();
  });

  /// Monta o card nos **dois** temas. Desde que a imagem passou a seguir o tema
  /// do app, um caso que caiba no escuro e não no claro é possível, e sem os
  /// dois o teste cobriria só metade do que o app gera.
  Future<void> pumpCard(
    WidgetTester tester,
    SessionShareData data, {
    required String name,
  }) async {
    for (final (suffix, theme) in [
      ('escuro', darkTheme()),
      ('claro', lightTheme()),
    ]) {
      final key = GlobalKey();

      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('pt', 'BR'),
          debugShowCheckedModeBanner: false,
          theme: theme,
          home: Center(
            child: RepaintBoundary(
              key: key,
              child: SessionShareCard(data: data),
            ),
          ),
        ),
      );
      await tester.pump();

      // Um RenderFlex que estoura reporta erro; aqui isso é falha de teste.
      expect(tester.takeException(), isNull, reason: '$name ($suffix)');

      // O card é rasterizado isolado. Sem um Material acima, todo texto sai com
      // o sublinhado amarelo de "faltou Material" — e vai para o arquivo. Note
      // que o `home` aqui é um Center pelado, de propósito: o card tem que se
      // bastar, sem depender de quem o coloca na tela.
      expect(
        find.ancestor(of: find.text(appName), matching: find.byType(Material)),
        findsWidgets,
      );

      final prefix = Platform.environment['SHARE_CARD_OUT'];
      if (prefix != null) {
        await _dump(tester, key, '$prefix-$name-$suffix.png');
      }
    }
  }

  testWidgets('treino cheio, com recordes e vários grupos', (tester) async {
    await pumpCard(tester, _fullSession(), name: 'cheio');
  });

  testWidgets('treino sem recorde nenhum', (tester) async {
    await pumpCard(tester, _fullSession(records: 0), name: 'sem-recorde');
  });

  // O caso mais alto que o card consegue produzir: a lista de recordes cheia
  // **mais** a contagem do que sobrou. Foi exatamente este que estourou no
  // aparelho enquanto o teste só cobria dois recordes.
  testWidgets('lista de recordes cheia com sobra é o caso mais alto', (
    tester,
  ) async {
    final data = _fullSession(records: 4);
    expect(data.records.length, greaterThan(3));
    await pumpCard(tester, data, name: 'recordes-cheios');
  });

  testWidgets('treino curto: um exercício, uma série', (tester) async {
    await pumpCard(
      tester,
      _data(
        routineName: 'Peito rápido',
        exercises: [
          _exerciseSummary('Supino reto barra', MuscleGroup.peito, 1),
        ],
      ),
      name: 'curto',
    );
  });

  testWidgets('mais grupos que a legenda mostra viram "outros"', (
    tester,
  ) async {
    final data = _data(
      routineName: 'Full body',
      exercises: [
        for (final (i, group) in MuscleGroup.values.indexed)
          _exerciseSummary('Exercício ${i + 1}', group, 3),
      ],
    );

    await pumpCard(tester, data, name: 'muitos-grupos');
    expect(data.summary.volumeByGroup.length, MuscleGroup.values.length);
  });

  testWidgets('nomes longos e volume alto não estouram', (tester) async {
    await pumpCard(
      tester,
      _data(
        routineName: 'Upper 1 — força máxima e acessórios',
        exercises: [
          _exerciseSummary(
            'Desenvolvimento militar em pé com barra olímpica',
            MuscleGroup.ombros,
            5,
            loadKg: 187.5,
            reps: 12,
          ),
          _exerciseSummary(
            'Puxada frontal na polia alta com pegada supinada',
            MuscleGroup.costas,
            5,
            loadKg: 145,
            reps: 15,
          ),
        ],
        records: [
          _record(
            'Desenvolvimento militar em pé com barra olímpica',
            MuscleGroup.ombros,
            from: 182.5,
            to: 187.5,
          ),
        ],
      ),
      name: 'nomes-longos',
    );
  });

  testWidgets('estreia: nada com que comparar', (tester) async {
    final data = _data(
      routineName: 'Lower 1',
      exercises: [
        _exerciseSummary(
          'Agachamento livre',
          MuscleGroup.quadriceps,
          4,
          verdict: Verdict.semReferencia,
        ),
      ],
    );

    expect(data.summary.comparableCount, 0);
    await pumpCard(tester, data, name: 'estreia');
  });
}

// ---------------------------------------------------------------------------
// Dados fabricados. Sem banco de propósito: o que está sob teste é o desenho.
// ---------------------------------------------------------------------------

SessionShareData _fullSession({int records = 2}) {
  const names = [
    ('Supino reto barra', MuscleGroup.peito),
    ('Remada curvada barra', MuscleGroup.costas),
    ('Desenvolvimento halteres', MuscleGroup.ombros),
    ('Rosca direta barra', MuscleGroup.biceps),
  ];

  return _data(
    routineName: 'Upper 1',
    exercises: [
      for (final (i, (name, group)) in names.indexed)
        _exerciseSummary(name, group, 4, loadKg: 72.5 - i * 10, reps: 8 + i),
    ],
    records: [
      for (var i = 0; i < records; i++)
        _record(
          names[i].$1,
          names[i].$2,
          from: 70.0 - i * 10,
          to: 72.5 - i * 10,
        ),
    ],
  );
}

SessionShareData _data({
  required String routineName,
  required List<ExerciseSummary> exercises,
  List<LoadRecord> records = const [],
}) {
  return SessionShareData(
    summary: SessionSummary(
      session: Session(
        id: 1,
        routineId: 1,
        routineName: routineName,
        startedAt: DateTime(2026, 8, 5, 18),
        finishedAt: DateTime(2026, 8, 5, 18, 52),
      ),
      exercises: exercises,
    ),
    records: records,
  );
}

Exercise _exercise(String name, MuscleGroup group) => Exercise(
  id: name.hashCode,
  name: name,
  muscleGroup: group,
  equipment: Equipment.barra,
  isCustom: false,
);

ExerciseSummary _exerciseSummary(
  String name,
  MuscleGroup group,
  int setCount, {
  double loadKg = 60,
  int reps = 10,
  Verdict verdict = Verdict.evoluiu,
}) {
  final sets = [
    for (var i = 0; i < setCount; i++)
      PerformedSet(
        position: i,
        type: SetType.normal,
        segments: [SegmentData(weightKg: loadKg, reps: reps)],
      ),
  ];
  final metrics = computeMetrics(sets);

  return ExerciseSummary(
    exercise: _exercise(name, group),
    metrics: metrics,
    previous: verdict == Verdict.semReferencia ? null : metrics,
    verdict: verdict,
    sets: sets,
  );
}

LoadRecord _record(
  String name,
  MuscleGroup group, {
  required double from,
  required double to,
}) => LoadRecord(
  exercise: _exercise(name, group),
  loadKg: to,
  reps: 8,
  previousBestKg: from,
);

/// A Inter não é carregada nos testes por padrão, e sem ela o texto sai na
/// fonte de teste — com métricas erradas, o que tornaria o teste de estouro
/// inútil.
Future<void> _loadInter() async {
  for (final file in [
    'Inter-Regular.ttf',
    'Inter-Medium.ttf',
    'Inter-SemiBold.ttf',
  ]) {
    final bytes = await File('assets/fonts/$file').readAsBytes();
    await (FontLoader(
      'Inter',
    )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
}

Future<void> _dump(WidgetTester tester, GlobalKey key, String path) async {
  final boundary =
      key.currentContext!.findRenderObject() as RenderRepaintBoundary;

  // `runAsync` é obrigatório: o relógio do teste é falso, e a rasterização
  // depende de async de verdade. Sem ele o `toImage` fica esperando para sempre.
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: shareCardPixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  });

  if (bytes != null) File(path).writeAsBytesSync(bytes);
}
