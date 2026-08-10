import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Preferências do app. São poucas e simples, então ficam em
/// SharedPreferences em vez de ocupar espaço no banco de treinos.
class Settings {
  const Settings({this.weightIncrement = 2.5, this.themeMode = ThemeMode.dark});

  final double weightIncrement;
  final ThemeMode themeMode;

  Settings copyWith({double? weightIncrement, ThemeMode? themeMode}) =>
      Settings(
        weightIncrement: weightIncrement ?? this.weightIncrement,
        themeMode: themeMode ?? this.themeMode,
      );
}

class SettingsNotifier extends StateNotifier<Settings> {
  /// Com [initial] preenchido não há leitura assíncrona nenhuma.
  ///
  /// É assim que o app arranca: o `main` lê as preferências antes do primeiro
  /// quadro e entrega prontas. Sem isso, quem usa tema claro via um quadro
  /// escuro (o padrão) antes de a leitura terminar — um piscar que a tela de
  /// abertura só tornaria mais evidente.
  SettingsNotifier({Settings? initial}) : super(initial ?? const Settings()) {
    if (initial == null) _load();
  }

  static const _incrementKey = 'weight_increment';
  static const _themeKey = 'theme_mode';

  /// Lê as preferências do disco. Usada pelo `main` antes de `runApp`.
  static Future<Settings> read() async =>
      _from(await SharedPreferences.getInstance());

  static Settings _from(SharedPreferences prefs) => Settings(
    weightIncrement: prefs.getDouble(_incrementKey) ?? 2.5,
    themeMode: ThemeMode.values.firstWhere(
      (m) => m.name == prefs.getString(_themeKey),
      orElse: () => ThemeMode.dark,
    ),
  );

  Future<void> _load() async {
    state = _from(await SharedPreferences.getInstance());
  }

  Future<void> setWeightIncrement(double value) async {
    state = state.copyWith(weightIncrement: value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_incrementKey, value);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = state.copyWith(themeMode: mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, mode.name);
  }
}

final settingsProvider = StateNotifierProvider<SettingsNotifier, Settings>(
  (ref) => SettingsNotifier(),
);
