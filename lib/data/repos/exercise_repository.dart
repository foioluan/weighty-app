import 'package:drift/drift.dart';

import '../../domain/models/enums.dart';
import '../db/database.dart';

class ExerciseRepository {
  ExerciseRepository(this._db);

  final AppDatabase _db;

  /// Catálogo visível, opcionalmente filtrado por grupo muscular e por busca
  /// livre no nome.
  Stream<List<Exercise>> watchCatalog({MuscleGroup? group, String? search}) {
    final query = _db.select(_db.exercises)
      ..where((t) => t.archivedAt.isNull())
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);

    if (group != null) {
      query.where((t) => t.muscleGroup.equalsValue(group));
    }

    final term = search?.trim();
    if (term != null && term.isNotEmpty) {
      query.where((t) => t.name.lower().contains(term.toLowerCase()));
    }

    return query.watch();
  }

  Future<Exercise?> byId(int id) => (_db.select(
    _db.exercises,
  )..where((t) => t.id.equals(id))).getSingleOrNull();

  Future<int> create({
    required String name,
    required MuscleGroup group,
    required Equipment equipment,
  }) {
    return _db
        .into(_db.exercises)
        .insert(
          ExercisesCompanion.insert(
            name: name.trim(),
            muscleGroup: group,
            equipment: equipment,
            isCustom: const Value(true),
          ),
        );
  }

  Future<void> rename(int id, String name) {
    return (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
      ExercisesCompanion(name: Value(name.trim())),
    );
  }

  /// Arquiva em vez de apagar: o histórico continua apontando para o exercício.
  Future<void> archive(int id) {
    return (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
      ExercisesCompanion(archivedAt: Value(DateTime.now())),
    );
  }

  Future<void> unarchive(int id) {
    return (_db.update(_db.exercises)..where((t) => t.id.equals(id))).write(
      const ExercisesCompanion(archivedAt: Value(null)),
    );
  }
}
