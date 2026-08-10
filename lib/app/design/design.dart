/// Ponto único de import do design system. As telas importam só este arquivo.
///
/// O theme.dart já reexporta tokens e tipografia, então aqui só entram os
/// componentes — reexportar tokens por dois caminhos seria redundante.
library;

export '../theme.dart';
export 'brand.dart';
export 'components/controls.dart';
export 'components/data.dart';
export 'components/feedback.dart';
export 'components/fields.dart';
export 'components/layout.dart';
export 'haptics.dart';
export 'components/motion.dart';
export 'components/tab_bar.dart';
