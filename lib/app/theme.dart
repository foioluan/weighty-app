import 'package:flutter/material.dart';

import 'design/tokens.dart';
import 'design/typography.dart';

export 'design/tokens.dart';
export 'design/typography.dart';

/// Atalhos para os componentes lerem a paleta sem repetir a busca da extensão.
extension ThemeAccess on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
}

/// Rolagem com inércia elástica e sem o brilho de overscroll do Android — que
/// é uma das assinaturas visuais mais reconhecíveis da plataforma.
class AppScrollBehavior extends MaterialScrollBehavior {
  const AppScrollBehavior();

  @override
  Widget buildOverscrollIndicator(_, Widget child, _) => child;

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics());
}

ThemeData darkTheme() => _build(AppColors.dark, Brightness.dark);
ThemeData lightTheme() => _build(AppColors.light, Brightness.light);

ThemeData _build(AppColors c, Brightness brightness) {
  final scheme = ColorScheme(
    brightness: brightness,
    primary: c.accent,
    onPrimary: c.onAccent,
    secondary: c.accent,
    onSecondary: c.onAccent,
    error: c.down,
    onError: Colors.white,
    surface: c.surface,
    onSurface: c.textPrimary,
    surfaceContainerHighest: c.surfaceInput,
    onSurfaceVariant: c.textSecondary,
    outline: c.hairlineStrong,
    outlineVariant: c.hairline,
  );

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: c.bg,
    canvasColor: c.bg,
    fontFamily: AppText.family,
    extensions: [c],
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,

    // Os componentes próprios cobrem as telas, mas o Material ainda entra por
    // baixo em teclado, seleção de texto e menus do sistema. Sem isto, esses
    // pontos voltam a parecer app padrão.
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: c.accent,
      selectionColor: c.accent.withValues(alpha: 0.3),
      selectionHandleColor: c.accent,
    ),
    textTheme: _textTheme(c),
    iconTheme: IconThemeData(color: c.textSecondary, size: 20),
    dividerTheme: DividerThemeData(
      color: c.hairline,
      thickness: 0.5,
      space: 0.5,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(
        color: c.surfaceRaised,
        borderRadius: BorderRadius.circular(Radii.sm),
        border: Border.all(color: c.hairline),
      ),
      textStyle: AppText.caption.copyWith(color: c.textPrimary),
    ),
    // Toast e diálogo têm componente próprio; estes temas são a rede de
    // segurança para qualquer chamada que escape.
    snackBarTheme: SnackBarThemeData(
      backgroundColor: c.surfaceRaised,
      contentTextStyle: AppText.callout.copyWith(color: c.textPrimary),
      actionTextColor: c.accent,
      behavior: SnackBarBehavior.floating,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.md),
        side: BorderSide(color: c.hairline),
      ),
    ),
    dialogTheme: DialogThemeData(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Radii.xl),
      ),
      titleTextStyle: AppText.title2.copyWith(color: c.textPrimary),
      contentTextStyle: AppText.callout.copyWith(color: c.textSecondary),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: c.surfaceRaised,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(Radii.xl)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: c.accent,
      linearTrackColor: c.hairline,
      circularTrackColor: Colors.transparent,
      strokeWidth: 2,
    ),
  );
}

TextTheme _textTheme(AppColors c) {
  final primary = c.textPrimary;
  final secondary = c.textSecondary;

  return TextTheme(
    displaySmall: AppText.numberLarge.copyWith(color: primary),
    headlineMedium: AppText.largeTitle.copyWith(color: primary),
    headlineSmall: AppText.title1.copyWith(color: primary),
    titleLarge: AppText.title1.copyWith(color: primary),
    titleMedium: AppText.title2.copyWith(color: primary),
    titleSmall: AppText.title3.copyWith(color: primary),
    bodyLarge: AppText.body.copyWith(color: primary),
    bodyMedium: AppText.callout.copyWith(color: secondary),
    bodySmall: AppText.footnote.copyWith(color: secondary),
    labelLarge: AppText.bodyStrong.copyWith(color: primary),
    labelMedium: AppText.caption.copyWith(color: secondary),
    labelSmall: AppText.overline.copyWith(color: c.textTertiary),
  );
}
