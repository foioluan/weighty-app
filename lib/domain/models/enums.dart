// Os valores destes enums são gravados no banco pelo nome (textEnum do Drift).
// Renomear um valor existente quebra os dados salvos — só acrescente novos.

enum MuscleGroup {
  peito('Peito'),
  costas('Costas'),
  ombros('Ombros'),
  trapezio('Trapézio'),
  biceps('Bíceps'),
  triceps('Tríceps'),
  antebraco('Antebraço'),
  quadriceps('Quadríceps'),
  posteriorCoxa('Posterior de coxa'),
  gluteos('Glúteos'),
  panturrilha('Panturrilha'),
  abdomen('Abdômen');

  const MuscleGroup(this.label);
  final String label;
}

enum Equipment {
  barra('Barra'),
  halter('Halteres'),
  maquina('Máquina'),
  cabo('Cabo'),
  pesoCorporal('Peso corporal'),
  outro('Outro');

  const Equipment(this.label);
  final String label;
}

/// Cada tipo é uma forma diferente de preencher a lista de segmentos de uma
/// série. O banco guarda todos igual: uma lista ordenada de (carga, reps).
enum SetType {
  /// Uma carga, uma contagem de reps.
  normal('Normal', 'Série de trabalho normal'),

  /// Igual à normal, mas fora de qualquer indicador de evolução.
  aquecimento('Aquecimento', 'Não entra nos indicadores'),

  /// Vários segmentos com carga decrescente, sem descanso entre eles.
  drop('Drop set', 'Cargas decrescentes, sem descanso'),

  /// Vários segmentos com a mesma carga e pausa curta entre eles.
  cluster('Cluster set', 'Mesma carga em blocos, pausa curta');

  const SetType(this.label, this.description);
  final String label;
  final String description;

  /// Se o tipo conta para carga máxima, volume e 1RM estimado.
  bool get countsForProgress => this != SetType.aquecimento;

  /// Se o tipo usa mais de um segmento por padrão.
  bool get isMultiSegment => this == SetType.drop || this == SetType.cluster;
}
