import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
// RenderRepaintBoundary não vem no material.dart, e é o objeto que sabe se
// rasterizar.
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../app/design/design.dart';
import '../../app/providers.dart';
import '../../data/repos/progress_repository.dart';
import 'session_share_card.dart';

/// Mostra a imagem do treino e a disponibiliza para download.
///
/// Não há compartilhamento aqui de propósito: o app rasteriza o card e grava na
/// galeria. O que acontece depois com o arquivo é decisão de quem tirou.
class SessionSharePage extends ConsumerStatefulWidget {
  const SessionSharePage({
    super.key,
    required this.sessionId,
    this.backLabel = 'Resumo',
  });

  final int sessionId;
  final String backLabel;

  @override
  ConsumerState<SessionSharePage> createState() => _SessionSharePageState();
}

class _SessionSharePageState extends ConsumerState<SessionSharePage> {
  /// Aponta para o RepaintBoundary que embrulha o card no tamanho real. É por
  /// ele que a imagem é capturada, e não pela tela: assim a redução da prévia
  /// não entra no arquivo.
  final _cardKey = GlobalKey();

  var _saving = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final share = ref.watch(sessionShareProvider(widget.sessionId));
    final data = share.valueOrNull;
    final ready = data != null && data.summary.exercises.isNotEmpty;

    // Sem barra de título e sem barra de botão: a imagem é o conteúdo inteiro
    // da tela, e qualquer moldura só a empurraria para baixo. O voltar e a ação
    // flutuam sobre o fundo, já que o card não chega às bordas verticais.
    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // A faixa útil desconta o voltar em cima e a ação embaixo, senão o
            // card centraliza na tela inteira e fica visivelmente baixo.
            Positioned.fill(
              top: 40,
              bottom: 92,
              child: share.when(
                loading: () => const SizedBox.shrink(),
                error: (e, _) => EmptyState(
                  title: 'Não deu para montar a imagem',
                  message: '$e',
                  icon: LucideIcons.circleAlert,
                ),
                data: (data) {
                  if (data == null) {
                    return const EmptyState(
                      title: 'Sessão não encontrada',
                      message: 'Ela pode ter sido excluída.',
                    );
                  }
                  if (data.summary.exercises.isEmpty) {
                    return const EmptyState(
                      title: 'Nada para mostrar',
                      message:
                          'Este treino não tem série de trabalho registrada, '
                          'então não há indicador nenhum para colocar na '
                          'imagem.',
                      icon: LucideIcons.imageOff,
                    );
                  }
                  return _Preview(cardKey: _cardKey, data: data);
                },
              ),
            ),
            Align(
              alignment: Alignment.topLeft,
              child: AppBackLink(label: widget.backLabel),
            ),
            if (ready)
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: Space.xxl),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AppButton(
                        label: _saving ? 'Salvando…' : 'Baixar',
                        icon: LucideIcons.imageDown,
                        onPressed: _saving ? null : () => _save(data),
                      ),
                      const SizedBox(height: Space.md),
                      Text(
                        'vai para a galeria, no álbum $appName',
                        style: AppText.caption.copyWith(color: c.textTertiary),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _save(SessionShareData data) async {
    setState(() => _saving = true);
    try {
      final bytes = await _rasterize();
      if (bytes == null) {
        if (mounted) {
          AppToast.show(
            context,
            'A imagem ainda não terminou de desenhar. Tente de novo.',
            kind: ToastKind.error,
          );
        }
        return;
      }

      // Do Android 10 em diante isto retorna true sem perguntar nada; nas
      // versões antigas é onde o pedido de permissão aparece.
      if (!await Gal.requestAccess(toAlbum: true)) {
        if (mounted) {
          AppToast.show(
            context,
            'Sem permissão para gravar na galeria.',
            kind: ToastKind.error,
          );
        }
        return;
      }

      await Gal.putImageBytes(
        bytes,
        album: appName,
        name: _fileName(data.summary),
      );

      if (mounted) {
        Haptics.confirm();
        AppToast.show(
          context,
          'Imagem salva na galeria.',
          kind: ToastKind.success,
        );
      }
    } on GalException catch (e) {
      if (mounted) {
        AppToast.show(context, switch (e.type) {
          GalExceptionType.accessDenied =>
            'Sem permissão para gravar na galeria.',
          GalExceptionType.notEnoughSpace =>
            'Sem espaço no aparelho para salvar a imagem.',
          _ => 'Não deu para salvar: ${e.type.message}',
        }, kind: ToastKind.error);
      }
    } catch (e) {
      if (mounted) {
        AppToast.show(
          context,
          'Não deu para salvar: $e',
          kind: ToastKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Rasteriza o card em 1080 × 1350. Devolve nulo se a camada de pintura ainda
  /// não existe — só acontece se o botão for tocado antes do primeiro quadro.
  Future<Uint8List?> _rasterize() async {
    final boundary =
        _cardKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;

    final image = await boundary.toImage(pixelRatio: shareCardPixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return data?.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  /// "weighty-upper-1-2026-08-05": o nome tem que ser reconhecível na galeria,
  /// e ordenável por data quando houver vários.
  String _fileName(SessionSummary summary) {
    final date = DateFormat(
      'yyyy-MM-dd',
    ).format(summary.session.finishedAt ?? summary.session.startedAt);

    final slug = summary.session.routineName
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');

    return 'weighty-${slug.isEmpty ? 'treino' : slug}-$date';
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.cardKey, required this.data});

  final GlobalKey cardKey;
  final SessionShareData data;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return Center(
      // Só a folga lateral mínima: o card ocupa a largura da tela, que é o
      // máximo que 4:5 permite sem trocar a proporção.
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: Space.lg),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(Radii.xl),
            boxShadow: [
              BoxShadow(
                color: const Color(
                  0xFF000000,
                ).withValues(alpha: c.isDark ? 0.5 : 0.18),
                blurRadius: 32,
                offset: const Offset(0, 14),
              ),
            ],
            border: Border.all(color: c.hairlineStrong, width: 0.5),
          ),
          // O canto arredondado é só da prévia. O arquivo salvo sai com canto
          // reto: PNG com canto transparente fica estranho na galeria.
          child: ClipRRect(
            borderRadius: BorderRadius.circular(Radii.xl),
            child: FittedBox(
              child: RepaintBoundary(
                key: cardKey,
                child: SessionShareCard(data: data),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
