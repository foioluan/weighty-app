import 'dart:convert';

/// Reverte texto com dupla codificação: bytes UTF-8 que foram interpretados
/// como Latin-1 e regravados. `ElevaÃ§Ã£o` volta a ser `Elevação`.
///
/// Devolve `null` quando não há nada a corrigir, para o chamador só escrever no
/// banco as linhas que realmente mudam.
///
/// A operação é conservadora de propósito. Um "reparo" que erra estraga o nome
/// que o usuário digitou, então só age quando os três sinais batem: o texto tem
/// a assinatura da corrupção, todos os caracteres cabem em Latin-1, e a
/// reinterpretação produz UTF-8 válido.
String? repairDoubleEncoded(String value) {
  // UTF-8 lido como Latin-1 sempre deixa Ã ou Â antes do segundo byte. Sem
  // isso, não é dupla codificação.
  if (!value.contains('Ã') && !value.contains('Â')) return null;

  // latin1.encode lança para qualquer caractere acima de 0xFF; um texto com
  // emoji ou aspas tipográficas, por exemplo, não veio desta corrupção.
  for (final unit in value.codeUnits) {
    if (unit > 0xFF) return null;
  }

  try {
    final decoded = utf8.decode(latin1.encode(value));
    return decoded == value ? null : decoded;
  } on FormatException {
    // Os bytes não formam UTF-8 válido: o texto é outra coisa e fica como está.
    return null;
  }
}
