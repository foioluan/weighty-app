import 'package:drift/drift.dart';

import '../../domain/models/enums.dart';

/// Catálogo de exercícios. Nunca são apagados de verdade: `archivedAt` esconde
/// o exercício das listas sem furar o histórico das sessões que o referenciam.
class Exercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 80)();
  TextColumn get muscleGroup => textEnum<MuscleGroup>()();
  TextColumn get equipment => textEnum<Equipment>()();
  BoolColumn get isCustom => boolean().withDefault(const Constant(false))();
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

/// Um treino montado: "Upper 1", "Lower 2".
class Routines extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text().withLength(min: 1, max: 60)();
  IntColumn get position => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  DateTimeColumn get archivedAt => dateTime().nullable()();
}

class RoutineExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId =>
      integer().references(Routines, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get position => integer()();
}

/// A série como planejada no treino (antes de executar).
class PlannedSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineExerciseId => integer().references(
    RoutineExercises,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get position => integer()();
  TextColumn get setType => textEnum<SetType>()();

  /// Alvo de repetições. Com `targetRepsMax` preenchido vira faixa (8 a 12).
  IntColumn get targetReps => integer().nullable()();
  IntColumn get targetRepsMax => integer().nullable()();

  /// Quantos segmentos a série tem: quedas do drop, blocos do cluster.
  /// Sempre 1 para normal e aquecimento.
  IntColumn get segmentCount => integer().withDefault(const Constant(1))();
}

/// Uma execução de treino. `routineName` é cópia do nome no momento da sessão
/// para o histórico não mudar se o treino for renomeado depois.
@TableIndex(name: 'idx_sessions_finished', columns: {#finishedAt})
class Sessions extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get routineId => integer().nullable().references(
    Routines,
    #id,
    onDelete: KeyAction.setNull,
  )();
  TextColumn get routineName => text().withLength(min: 1, max: 60)();
  DateTimeColumn get startedAt => dateTime()();

  /// Nulo enquanto a sessão está em andamento. Só sessões finalizadas entram
  /// nas comparações de evolução.
  DateTimeColumn get finishedAt => dateTime().nullable()();
}

// Toda consulta de "última vez" e todo gráfico de progressão entram por
// exerciseId e saem ordenando por data — daí os dois índices.
@TableIndex(name: 'idx_session_exercises_exercise', columns: {#exerciseId})
class SessionExercises extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionId =>
      integer().references(Sessions, #id, onDelete: KeyAction.cascade)();
  IntColumn get exerciseId => integer().references(Exercises, #id)();
  IntColumn get position => integer()();
}

/// A série como executada.
class LoggedSets extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get sessionExerciseId => integer().references(
    SessionExercises,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get position => integer()();
  TextColumn get setType => textEnum<SetType>()();

  /// Nulo quando é uma série extra, adicionada durante o treino.
  IntColumn get plannedSetId => integer().nullable().references(
    PlannedSets,
    #id,
    onDelete: KeyAction.setNull,
  )();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();
}

/// O par (carga, reps) que compõe uma série. Normal e aquecimento têm um só;
/// drop e cluster têm vários. É esta tabela que faz os quatro tipos de série
/// caberem no mesmo modelo.
class SetSegments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get loggedSetId =>
      integer().references(LoggedSets, #id, onDelete: KeyAction.cascade)();
  IntColumn get position => integer()();
  RealColumn get weightKg => real()();
  IntColumn get reps => integer()();
}
