import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app/design/brand.dart';
import 'app/router.dart';
import 'app/settings.dart';
import 'app/splash.dart';
import 'app/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Sem isto o DateFormat com locale pt_BR lança ao formatar datas.
  await initializeDateFormatting('pt_BR');

  // As preferências são lidas antes do primeiro quadro para o app já nascer no
  // tema certo. Lidas depois, quem usa tema claro veria um quadro escuro.
  final settings = await SettingsNotifier.read();

  runApp(
    ProviderScope(
      overrides: [
        settingsProvider.overrideWith(
          (ref) => SettingsNotifier(initial: settings),
        ),
      ],
      child: const WeightyApp(),
    ),
  );
}

class WeightyApp extends ConsumerWidget {
  const WeightyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: appName,
      debugShowCheckedModeBanner: false,
      theme: lightTheme(),
      darkTheme: darkTheme(),
      themeMode: ref.watch(settingsProvider).themeMode,
      scrollBehavior: const AppScrollBehavior(),
      // A abertura entra por aqui e não como rota: assim o app é construído
      // embaixo dela e já está pronto quando ela sai.
      //
      // O BackdropGroup faz os vidros da tela dividirem uma passada de
      // desfoque, em vez de cada um desfocar o fundo por conta própria.
      builder: (_, child) =>
          BackdropGroup(child: SplashGate(child: child ?? const SizedBox())),
      routerConfig: router,
      locale: const Locale('pt', 'BR'),
      supportedLocales: const [Locale('pt', 'BR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
    );
  }
}
