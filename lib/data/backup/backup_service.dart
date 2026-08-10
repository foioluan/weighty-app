import 'dart:convert';

import 'package:drift/drift.dart';

import '../../domain/models/enums.dart';
import '../db/database.dart';

/// Erro de importação com mensagem pronta para mostrar ao usuário.
class BackupException implements Exception {
  BackupException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Exportação e importação do banco inteiro em JSON.
///
/// A serialização é escrita à mão de propósito: o formato do backup precisa
/// sobreviver a mudanças no gerador do Drift e a versões futuras do schema.
class BackupService {
  BackupService(this._db);

  final AppDatabase _db;

  /// Versão do formato do arquivo, independente do schemaVersion do banco.
  static const formatVersion = 1;

  Future<String> exportJson() async {
    final data = {
      'formatVersion': formatVersion,
      'exportedAt': DateTime.now().toIso8601String(),
      'exercises': [
        for (final e in await _db.select(_db.exercises).get())
          {
            'id': e.id,
            'name': e.name,
            'muscleGroup': e.muscleGroup.name,
            'equipment': e.equipment.name,
            'isCustom': e.isCustom,
            'archivedAt': e.archivedAt?.toIso8601String(),
          },
      ],
      'routines': [
        for (final r in await _db.select(_db.routines).get())
          {
            'id': r.id,
            'name': r.name,
            'position': r.position,
            'createdAt': r.createdAt.toIso8601String(),
            'archivedAt': r.archivedAt?.toIso8601String(),
          },
      ],
      'routineExercises': [
        for (final r in await _db.select(_db.routineExercises).get())
          {
            'id': r.id,
            'routineId': r.routineId,
            'exerciseId': r.exerciseId,
            'position': r.position,
          },
      ],
      'plannedSets': [
        for (final p in await _db.select(_db.plannedSets).get())
          {
            'id': p.id,
            'routineExerciseId': p.routineExerciseId,
            'position': p.position,
            'setType': p.setType.name,
            'targetReps': p.targetReps,
            'targetRepsMax': p.targetRepsMax,
            'segmentCount': p.segmentCount,
          },
      ],
      'sessions': [
        for (final s in await _db.select(_db.sessions).get())
          {
            'id': s.id,
            'routineId': s.routineId,
            'routineName': s.routineName,
            'startedAt': s.startedAt.toIso8601String(),
            'finishedAt': s.finishedAt?.toIso8601String(),
          },
      ],
      'sessionExercises': [
        for (final s in await _db.select(_db.sessionExercises).get())
          {
            'id': s.id,
            'sessionId': s.sessionId,
            'exerciseId': s.exerciseId,
            'position': s.position,
          },
      ],
      'loggedSets': [
        for (final l in await _db.select(_db.loggedSets).get())
          {
            'id': l.id,
            'sessionExerciseId': l.sessionExerciseId,
            'position': l.position,
            'setType': l.setType.name,
            'plannedSetId': l.plannedSetId,
            'completed': l.completed,
          },
      ],
      'setSegments': [
        for (final s in await _db.select(_db.setSegments).get())
          {
            'id': s.id,
            'loggedSetId': s.loggedSetId,
            'position': s.position,
            'weightKg': s.weightKg,
            'reps': s.reps,
          },
      ],
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Substitui todo o conteúdo do banco pelo do arquivo. É tudo ou nada: se
  /// qualquer linha falhar, a transação desfaz e o banco fica como estava.
  Future<void> importJson(String source) async {
    final Map<String, dynamic> data;
    try {
      data = jsonDecode(source) as Map<String, dynamic>;
    } on FormatException {
      throw BackupException('O arquivo não é um backup válido do app.');
    }

    final version = data['formatVersion'];
    if (version is! int) {
      throw BackupException('O arquivo não é um backup válido do app.');
    }
    if (version > formatVersion) {
      throw BackupException(
        'Este backup foi feito numa versão mais nova do app. '
        'Atualize o app antes de importar.',
      );
    }

    await _db.transaction(() async {
      // Ordem inversa das dependências para não esbarrar nas chaves
      // estrangeiras durante a limpeza.
      await _db.delete(_db.setSegments).go();
      await _db.delete(_db.loggedSets).go();
      await _db.delete(_db.sessionExercises).go();
      await _db.delete(_db.sessions).go();
      await _db.delete(_db.plannedSets).go();
      await _db.delete(_db.routineExercises).go();
      await _db.delete(_db.routines).go();
      await _db.delete(_db.exercises).go();

      for (final row in _rows(data, 'exercises')) {
        await _db
            .into(_db.exercises)
            .insert(
              ExercisesCompanion.insert(
                id: Value(row['id'] as int),
                name: row['name'] as String,
                muscleGroup: _enumByName(
                  MuscleGroup.values,
                  row['muscleGroup'],
                  MuscleGroup.peito,
                ),
                equipment: _enumByName(
                  Equipment.values,
                  row['equipment'],
                  Equipment.outro,
                ),
                isCustom: Value(row['isCustom'] as bool? ?? false),
                archivedAt: Value(_date(row['archivedAt'])),
              ),
            );
      }

      for (final row in _rows(data, 'routines')) {
        await _db
            .into(_db.routines)
            .insert(
              RoutinesCompanion.insert(
                id: Value(row['id'] as int),
                name: row['name'] as String,
                position: Value(row['position'] as int? ?? 0),
                createdAt: Value(_date(row['createdAt']) ?? DateTime.now()),
                archivedAt: Value(_date(row['archivedAt'])),
              ),
            );
      }

      for (final row in _rows(data, 'routineExercises')) {
        await _db
            .into(_db.routineExercises)
            .insert(
              RoutineExercisesCompanion.insert(
                id: Value(row['id'] as int),
                routineId: row['routineId'] as int,
                exerciseId: row['exerciseId'] as int,
                position: row['position'] as int,
              ),
            );
      }

      for (final row in _rows(data, 'plannedSets')) {
        await _db
            .into(_db.plannedSets)
            .insert(
              PlannedSetsCompanion.insert(
                id: Value(row['id'] as int),
                routineExerciseId: row['routineExerciseId'] as int,
                position: row['position'] as int,
                setType: _enumByName(
                  SetType.values,
                  row['setType'],
                  SetType.normal,
                ),
                targetReps: Value(row['targetReps'] as int?),
                targetRepsMax: Value(row['targetRepsMax'] as int?),
                segmentCount: Value(row['segmentCount'] as int? ?? 1),
              ),
            );
      }

      for (final row in _rows(data, 'sessions')) {
        await _db
            .into(_db.sessions)
            .insert(
              SessionsCompanion.insert(
                id: Value(row['id'] as int),
                routineId: Value(row['routineId'] as int?),
                routineName: row['routineName'] as String,
                startedAt: _date(row['startedAt']) ?? DateTime.now(),
                finishedAt: Value(_date(row['finishedAt'])),
              ),
            );
      }

      for (final row in _rows(data, 'sessionExercises')) {
        await _db
            .into(_db.sessionExercises)
            .insert(
              SessionExercisesCompanion.insert(
                id: Value(row['id'] as int),
                sessionId: row['sessionId'] as int,
                exerciseId: row['exerciseId'] as int,
                position: row['position'] as int,
              ),
            );
      }

      for (final row in _rows(data, 'loggedSets')) {
        await _db
            .into(_db.loggedSets)
            .insert(
              LoggedSetsCompanion.insert(
                id: Value(row['id'] as int),
                sessionExerciseId: row['sessionExerciseId'] as int,
                position: row['position'] as int,
                setType: _enumByName(
                  SetType.values,
                  row['setType'],
                  SetType.normal,
                ),
                plannedSetId: Value(row['plannedSetId'] as int?),
                completed: Value(row['completed'] as bool? ?? false),
              ),
            );
      }

      for (final row in _rows(data, 'setSegments')) {
        await _db
            .into(_db.setSegments)
            .insert(
              SetSegmentsCompanion.insert(
                id: Value(row['id'] as int),
                loggedSetId: row['loggedSetId'] as int,
                position: row['position'] as int,
                weightKg: (row['weightKg'] as num).toDouble(),
                reps: row['reps'] as int,
              ),
            );
      }

      // Um backup exportado de um banco corrompido traz os nomes corrompidos.
      // Roda ao fim, com tudo já inserido, dentro da mesma transação.
      await _db.repairEncoding();
    });
  }

  Iterable<Map<String, dynamic>> _rows(Map<String, dynamic> data, String key) {
    final list = data[key];
    if (list == null) return const [];
    if (list is! List) {
      throw BackupException('O campo "$key" do backup está corrompido.');
    }
    return list.cast<Map<String, dynamic>>();
  }

  DateTime? _date(Object? value) =>
      value is String ? DateTime.tryParse(value) : null;

  /// Um valor de enum desconhecido (backup de uma versão mais nova, ou arquivo
  /// editado à mão) cai no padrão em vez de derrubar a importação inteira.
  T _enumByName<T extends Enum>(List<T> values, Object? name, T fallback) {
    if (name is! String) return fallback;
    for (final value in values) {
      if (value.name == name) return value;
    }
    return fallback;
  }
}
