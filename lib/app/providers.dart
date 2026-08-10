import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/db/database.dart' show AppDatabase, Exercise;
import '../data/repos/exercise_repository.dart';
import '../data/repos/progress_repository.dart'
    show ProgressRepository, ProgressPoint, SessionShareData, SessionSummary;
import '../data/repos/routine_repository.dart';
import '../data/repos/session_repository.dart';
import '../domain/models/enums.dart';
import 'settings.dart';
import '../domain/models/performance.dart';

/// Banco único do app. Sobrescrito nos testes por um em memória.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final exerciseRepositoryProvider = Provider(
  (ref) => ExerciseRepository(ref.watch(databaseProvider)),
);

final routineRepositoryProvider = Provider(
  (ref) => RoutineRepository(ref.watch(databaseProvider)),
);

final sessionRepositoryProvider = Provider(
  (ref) => SessionRepository(ref.watch(databaseProvider)),
);

final progressRepositoryProvider = Provider(
  (ref) => ProgressRepository(ref.watch(databaseProvider)),
);

/// Lista da home.
final routineSummariesProvider = StreamProvider(
  (ref) => ref.watch(routineRepositoryProvider).watchSummaries(),
);

final routineDetailProvider = FutureProvider.family<RoutineDetail?, int>(
  (ref, id) => ref.watch(routineRepositoryProvider).detail(id),
);

/// Filtros do catálogo de exercícios.
///
/// `autoDispose` de propósito: sem ele o filtro digitado continuava valendo
/// depois de sair da tela, enquanto o campo de texto voltava vazio — a lista
/// aparecia filtrada sem nada explicando o porquê.
final catalogSearchProvider = StateProvider.autoDispose<String>((ref) => '');
final catalogGroupProvider = StateProvider.autoDispose<MuscleGroup?>(
  (ref) => null,
);

final exerciseCatalogProvider = StreamProvider.autoDispose((ref) {
  return ref
      .watch(exerciseRepositoryProvider)
      .watchCatalog(
        group: ref.watch(catalogGroupProvider),
        search: ref.watch(catalogSearchProvider),
      );
});

/// A sessão em andamento, se houver — usada para oferecer "retomar treino".
final activeSessionProvider = FutureProvider(
  (ref) => ref.watch(sessionRepositoryProvider).activeSession(),
);

/// A sessão sendo executada, com exercícios, séries e segmentos.
final liveSessionProvider = StreamProvider.family<LiveSession?, int>(
  (ref, sessionId) =>
      ref.watch(sessionRepositoryProvider).watchSession(sessionId),
);

/// Chave da consulta de "última vez": o exercício, e a sessão atual que precisa
/// ficar de fora da busca para não comparar o treino com ele mesmo.
typedef LastPerformanceKey = ({int exerciseId, int sessionId});

final lastPerformanceProvider =
    FutureProvider.family<List<PerformedSet>, LastPerformanceKey>((ref, key) {
      return ref
          .watch(progressRepositoryProvider)
          .lastPerformance(key.exerciseId, excludeSessionId: key.sessionId);
    });

/// Passo dos botões de carga, vindo dos ajustes.
final weightIncrementProvider = Provider<double>(
  (ref) => ref.watch(settingsProvider).weightIncrement,
);

/// Histórico de sessões finalizadas.
final finishedSessionsProvider = StreamProvider(
  (ref) => ref.watch(sessionRepositoryProvider).watchFinished(),
);

/// Resumo de uma sessão: métricas e veredito por exercício.
final sessionSummaryProvider = FutureProvider.family<SessionSummary?, int>(
  (ref, sessionId) =>
      ref.watch(progressRepositoryProvider).summarize(sessionId),
);

/// Resumo + recordes, para a imagem do treino. Um provider só porque a imagem
/// não pode aparecer meio pronta enquanto a outra metade carrega.
final sessionShareProvider = FutureProvider.family<SessionShareData?, int>(
  (ref, sessionId) =>
      ref.watch(progressRepositoryProvider).shareData(sessionId),
);

final exerciseByIdProvider = FutureProvider.family<Exercise?, int>(
  (ref, id) => ref.watch(exerciseRepositoryProvider).byId(id),
);

/// Resumo da semana no topo da home.
final weekSummaryProvider = FutureProvider(
  (ref) => ref.watch(progressRepositoryProvider).weekSummary(),
);

/// Série histórica de um exercício, para o gráfico.
final exerciseHistoryProvider = FutureProvider.family<List<ProgressPoint>, int>(
  (ref, exerciseId) =>
      ref.watch(progressRepositoryProvider).history(exerciseId),
);

/// Qual métrica o gráfico de progressão está exibindo.
enum ProgressMetricKind {
  carga('Carga'),
  volume('Volume'),
  oneRm('1RM est.');

  const ProgressMetricKind(this.label);
  final String label;
}

final progressMetricProvider = StateProvider((ref) => ProgressMetricKind.carga);
