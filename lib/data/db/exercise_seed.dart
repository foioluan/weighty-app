import '../../domain/models/enums.dart';

/// Catálogo inicial gravado na criação do banco. O usuário pode arquivar
/// qualquer um destes e criar os seus (`isCustom`).
class SeedExercise {
  const SeedExercise(this.name, this.group, this.equipment);

  final String name;
  final MuscleGroup group;
  final Equipment equipment;
}

const seedExercises = <SeedExercise>[
  // Peito
  SeedExercise('Supino reto barra', MuscleGroup.peito, Equipment.barra),
  SeedExercise('Supino reto halteres', MuscleGroup.peito, Equipment.halter),
  SeedExercise('Supino inclinado barra', MuscleGroup.peito, Equipment.barra),
  SeedExercise(
    'Supino inclinado halteres',
    MuscleGroup.peito,
    Equipment.halter,
  ),
  SeedExercise('Supino declinado barra', MuscleGroup.peito, Equipment.barra),
  SeedExercise('Supino máquina', MuscleGroup.peito, Equipment.maquina),
  SeedExercise('Crucifixo halteres', MuscleGroup.peito, Equipment.halter),
  SeedExercise('Peck deck', MuscleGroup.peito, Equipment.maquina),
  SeedExercise('Crossover polia alta', MuscleGroup.peito, Equipment.cabo),
  SeedExercise('Flexão de braço', MuscleGroup.peito, Equipment.pesoCorporal),
  SeedExercise('Paralelas', MuscleGroup.peito, Equipment.pesoCorporal),

  // Costas
  SeedExercise(
    'Barra fixa pronada',
    MuscleGroup.costas,
    Equipment.pesoCorporal,
  ),
  SeedExercise(
    'Barra fixa supinada',
    MuscleGroup.costas,
    Equipment.pesoCorporal,
  ),
  SeedExercise('Puxada frente na polia', MuscleGroup.costas, Equipment.cabo),
  SeedExercise('Puxada supinada na polia', MuscleGroup.costas, Equipment.cabo),
  SeedExercise('Remada curvada barra', MuscleGroup.costas, Equipment.barra),
  SeedExercise('Remada curvada halteres', MuscleGroup.costas, Equipment.halter),
  SeedExercise(
    'Remada unilateral halter',
    MuscleGroup.costas,
    Equipment.halter,
  ),
  SeedExercise('Remada cavalinho', MuscleGroup.costas, Equipment.maquina),
  SeedExercise('Remada baixa na polia', MuscleGroup.costas, Equipment.cabo),
  SeedExercise('Pullover na polia', MuscleGroup.costas, Equipment.cabo),
  SeedExercise('Levantamento terra', MuscleGroup.costas, Equipment.barra),

  // Ombros
  SeedExercise(
    'Desenvolvimento militar barra',
    MuscleGroup.ombros,
    Equipment.barra,
  ),
  SeedExercise(
    'Desenvolvimento halteres',
    MuscleGroup.ombros,
    Equipment.halter,
  ),
  SeedExercise(
    'Desenvolvimento máquina',
    MuscleGroup.ombros,
    Equipment.maquina,
  ),
  SeedExercise(
    'Elevação lateral halteres',
    MuscleGroup.ombros,
    Equipment.halter,
  ),
  SeedExercise('Elevação lateral na polia', MuscleGroup.ombros, Equipment.cabo),
  SeedExercise(
    'Elevação frontal halteres',
    MuscleGroup.ombros,
    Equipment.halter,
  ),
  SeedExercise('Crucifixo inverso', MuscleGroup.ombros, Equipment.maquina),
  SeedExercise('Face pull', MuscleGroup.ombros, Equipment.cabo),

  // Trapézio
  SeedExercise('Encolhimento halteres', MuscleGroup.trapezio, Equipment.halter),
  SeedExercise('Encolhimento barra', MuscleGroup.trapezio, Equipment.barra),

  // Bíceps
  SeedExercise('Rosca direta barra', MuscleGroup.biceps, Equipment.barra),
  SeedExercise('Rosca direta halteres', MuscleGroup.biceps, Equipment.halter),
  SeedExercise('Rosca alternada', MuscleGroup.biceps, Equipment.halter),
  SeedExercise('Rosca martelo', MuscleGroup.biceps, Equipment.halter),
  SeedExercise('Rosca scott', MuscleGroup.biceps, Equipment.maquina),
  SeedExercise('Rosca concentrada', MuscleGroup.biceps, Equipment.halter),
  SeedExercise('Rosca na polia baixa', MuscleGroup.biceps, Equipment.cabo),

  // Tríceps
  SeedExercise('Tríceps testa barra', MuscleGroup.triceps, Equipment.barra),
  SeedExercise('Tríceps pulley corda', MuscleGroup.triceps, Equipment.cabo),
  SeedExercise('Tríceps pulley barra', MuscleGroup.triceps, Equipment.cabo),
  SeedExercise('Tríceps francês halter', MuscleGroup.triceps, Equipment.halter),
  SeedExercise('Tríceps coice', MuscleGroup.triceps, Equipment.halter),
  SeedExercise('Supino fechado', MuscleGroup.triceps, Equipment.barra),
  SeedExercise(
    'Mergulho no banco',
    MuscleGroup.triceps,
    Equipment.pesoCorporal,
  ),

  // Antebraço
  SeedExercise('Rosca inversa', MuscleGroup.antebraco, Equipment.barra),
  SeedExercise('Rosca de punho', MuscleGroup.antebraco, Equipment.halter),

  // Quadríceps
  SeedExercise('Agachamento livre', MuscleGroup.quadriceps, Equipment.barra),
  SeedExercise('Agachamento frontal', MuscleGroup.quadriceps, Equipment.barra),
  SeedExercise('Agachamento hack', MuscleGroup.quadriceps, Equipment.maquina),
  SeedExercise('Leg press 45', MuscleGroup.quadriceps, Equipment.maquina),
  SeedExercise('Cadeira extensora', MuscleGroup.quadriceps, Equipment.maquina),
  SeedExercise('Agachamento búlgaro', MuscleGroup.quadriceps, Equipment.halter),
  SeedExercise('Afundo', MuscleGroup.quadriceps, Equipment.halter),

  // Posterior de coxa
  SeedExercise('Mesa flexora', MuscleGroup.posteriorCoxa, Equipment.maquina),
  SeedExercise('Cadeira flexora', MuscleGroup.posteriorCoxa, Equipment.maquina),
  SeedExercise('Flexora em pé', MuscleGroup.posteriorCoxa, Equipment.maquina),
  SeedExercise('Stiff barra', MuscleGroup.posteriorCoxa, Equipment.barra),
  SeedExercise('Stiff halteres', MuscleGroup.posteriorCoxa, Equipment.halter),
  SeedExercise('Terra romeno', MuscleGroup.posteriorCoxa, Equipment.barra),

  // Glúteos
  SeedExercise('Elevação pélvica', MuscleGroup.gluteos, Equipment.barra),
  SeedExercise('Cadeira abdutora', MuscleGroup.gluteos, Equipment.maquina),
  SeedExercise('Glúteo na polia', MuscleGroup.gluteos, Equipment.cabo),
  SeedExercise('Coice na máquina', MuscleGroup.gluteos, Equipment.maquina),

  // Panturrilha
  SeedExercise('Panturrilha em pé', MuscleGroup.panturrilha, Equipment.maquina),
  SeedExercise(
    'Panturrilha sentado',
    MuscleGroup.panturrilha,
    Equipment.maquina,
  ),
  SeedExercise(
    'Panturrilha no leg press',
    MuscleGroup.panturrilha,
    Equipment.maquina,
  ),

  // Abdômen
  SeedExercise(
    'Abdominal supra solo',
    MuscleGroup.abdomen,
    Equipment.pesoCorporal,
  ),
  SeedExercise('Abdominal na polia', MuscleGroup.abdomen, Equipment.cabo),
  SeedExercise('Abdominal máquina', MuscleGroup.abdomen, Equipment.maquina),
  SeedExercise(
    'Elevação de pernas suspenso',
    MuscleGroup.abdomen,
    Equipment.pesoCorporal,
  ),
];
