import 'package:intl/intl.dart';

/// Cargas saem sem casa decimal quando são inteiras (70, não 70,0) e com uma
/// casa quando não são (67,5). Vírgula, como se escreve em português.
String formatWeight(double kg) {
  final rounded = (kg * 100).round() / 100;
  if (rounded == rounded.roundToDouble()) return rounded.toStringAsFixed(0);

  // Uma casa quando basta (67,5); duas só para anilhas de 1,25.
  final oneDecimal = (rounded * 10).round() / 10;
  final digits = oneDecimal == rounded ? 1 : 2;
  return rounded.toStringAsFixed(digits).replaceAll('.', ',');
}

/// Delta com sinal explícito: "+2,5", "−5", "=".
String formatDelta(double kg) {
  if (kg == 0) return '=';
  final sign = kg > 0 ? '+' : '−';
  return '$sign${formatWeight(kg.abs())}';
}

String formatVolume(double kg) {
  return NumberFormat.decimalPattern('pt_BR').format(kg.round());
}

/// Volume semanal em tonelada quando passa de 1000 kg: "14,2" lê melhor que
/// "14.200" num número de destaque.
String formatTonnage(double kg) {
  if (kg < 1000) return kg.round().toString();
  return (kg / 1000).toStringAsFixed(1).replaceAll('.', ',');
}

/// "hoje", "ontem", "há 6 dias", ou a data quando fica distante demais.
String formatRelativeDate(DateTime date, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(reference.year, reference.month, reference.day);
  final days = today.difference(day).inDays;

  if (days == 0) return 'hoje';
  if (days == 1) return 'ontem';
  if (days < 30) return 'há $days dias';
  return DateFormat("d 'de' MMMM", 'pt_BR').format(date);
}

String formatShortDate(DateTime date) =>
    DateFormat('d MMM', 'pt_BR').format(date);

String formatDuration(Duration d) {
  final minutes = d.inMinutes;
  final seconds = d.inSeconds % 60;
  return '$minutes:${seconds.toString().padLeft(2, '0')}';
}
