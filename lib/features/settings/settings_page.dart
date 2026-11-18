import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/design/design.dart';
import '../../app/formatting.dart';
import '../../app/providers.dart';
import '../../app/settings.dart';
import '../../app/splash.dart' show AppCredit;
import '../../data/backup/backup_service.dart';

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  static const _increments = [1.0, 1.25, 2.0, 2.5, 5.0];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final settings = ref.watch(settingsProvider);

    return AppScaffold(
      largeTitle: 'Ajustes',
      slivers: [
        AppSliverList(
          padding: const EdgeInsets.fromLTRB(
            Space.page,
            Space.md,
            Space.page,
            0,
          ),
          children: [
            const SectionLabel('Treino'),
            InsetGroup(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    Space.xl,
                    Space.lg,
                    Space.xl,
                    Space.lg,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Passo dos botões de carga',
                        style: AppText.body.copyWith(color: c.textPrimary),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        'Quanto − e + somam ou tiram de uma vez.',
                        style: AppText.footnote.copyWith(color: c.textTertiary),
                      ),
                      const SizedBox(height: Space.lg),
                      Row(
                        children: [
                          for (final value in _increments)
                            Padding(
                              padding: const EdgeInsets.only(right: Space.sm),
                              child: AppChip(
                                label: formatWeight(value),
                                selected: settings.weightIncrement == value,
                                onTap: () => ref
                                    .read(settingsProvider.notifier)
                                    .setWeightIncrement(value),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SectionLabel('Aparência'),
            InsetGroup(
              children: [
                for (final entry in const <ThemeMode, (String, String?)>{
                  ThemeMode.dark: ('Escuro', 'O padrão do app'),
                  ThemeMode.light: ('Claro', null),
                  ThemeMode.system: ('Seguir o sistema', null),
                }.entries)
                  AppChoiceRow<ThemeMode>(
                    value: entry.key,
                    groupValue: settings.themeMode,
                    onChanged: (mode) =>
                        ref.read(settingsProvider.notifier).setThemeMode(mode),
                    title: entry.value.$1,
                    subtitle: entry.value.$2,
                  ),
              ],
            ),
            const SectionLabel('Backup'),
            InsetGroup(
              children: [
                AppRow(
                  title: 'Exportar',
                  subtitle: 'Gera um arquivo com treinos e histórico',
                  leading: Icon(
                    LucideIcons.upload,
                    size: 19,
                    color: c.textSecondary,
                  ),
                  showChevron: true,
                  onTap: () => _export(context, ref),
                ),
                AppRow(
                  title: 'Importar',
                  subtitle: 'Substitui tudo que está no app',
                  leading: Icon(
                    LucideIcons.download,
                    size: 19,
                    color: c.textSecondary,
                  ),
                  showChevron: true,
                  onTap: () => _import(context, ref),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                Space.xs,
                Space.lg,
                Space.xs,
                0,
              ),
              child: Text(
                'Os dados ficam só neste aparelho. O backup exportado é a única '
                'forma de recuperá-los se você trocar de celular.',
                style: AppText.footnote.copyWith(
                  color: c.textTertiary,
                  height: 1.45,
                ),
              ),
            ),
            const _BrandFooter(),
          ],
        ),
      ],
    );
  }

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    try {
      final json = await BackupService(ref.read(databaseProvider)).exportJson();

      final stamp = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/weighty-backup-$stamp.json');
      await file.writeAsString(json);

      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path)],
          fileNameOverrides: ['weighty-backup-$stamp.json'],
          text: 'Backup do $appName',
        ),
      );
    } catch (e) {
      if (context.mounted) {
        AppToast.show(
          context,
          'Não deu para exportar: $e',
          kind: ToastKind.error,
        );
      }
    }
  }

  Future<void> _import(BuildContext context, WidgetRef ref) async {
    // Importar apaga tudo, então a confirmação é explícita sobre isso.
    final confirmed = await showAppDialog<bool>(
      context,
      title: 'Importar backup?',
      message:
          'Todos os treinos e todo o histórico que estão no app agora vão ser '
          'apagados e substituídos pelo conteúdo do arquivo. Não dá para '
          'desfazer.',
      actions: const [
        AppDialogAction(label: 'Cancelar', value: false),
        AppDialogAction(
          label: 'Substituir tudo',
          value: true,
          isDestructive: true,
          isPreferred: true,
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;

    try {
      // Sem filtro por extensão: dependendo do app de arquivos, o .json vem
      // com tipo MIME genérico e um filtro estrito esconderia o backup.
      final file = await openFile();
      if (file == null) return;

      await BackupService(
        ref.read(databaseProvider),
      ).importJson(await file.readAsString());

      // Tudo que estava em cache aponta para dados que não existem mais.
      ref.invalidate(routineSummariesProvider);
      ref.invalidate(finishedSessionsProvider);
      ref.invalidate(activeSessionProvider);
      ref.invalidate(exerciseCatalogProvider);

      if (context.mounted) {
        AppToast.show(context, 'Backup importado.', kind: ToastKind.success);
      }
    } on BackupException catch (e) {
      if (context.mounted) {
        AppToast.show(context, e.message, kind: ToastKind.error);
      }
    } catch (e) {
      if (context.mounted) {
        AppToast.show(
          context,
          'Não deu para importar: $e',
          kind: ToastKind.error,
        );
      }
    }
  }
}

/// Rodapé de identidade. É o lugar convencional da marca num app de sistema —
/// e o único lugar dentro do app onde a versão precisa aparecer.
class _BrandFooter extends StatelessWidget {
  const _BrandFooter();

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Padding(
      padding: const EdgeInsets.only(top: Space.xxxl),
      child: Column(
        children: [
          WeightyLockup(style: AppText.title2, color: c.textSecondary),
          const SizedBox(height: Space.xs),
          Text(
            'versão $appVersionLabel',
            style: AppText.caption.copyWith(color: c.textGhost),
          ),
          const SizedBox(height: Space.lg),
          const AppCredit(),
        ],
      ),
    );
  }
}
