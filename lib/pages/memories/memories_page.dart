import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../controllers/current_baby_controller.dart';
import '../../controllers/memory_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../services/premium/feature_access.dart';
import '../../services/premium/premium_constants.dart';
import '../../services/premium/premium_service.dart';
import '../../models/memory_badge.dart';
import '../../services/app_database.dart';
import '../../services/memory_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/memory_album_pdf.dart';
import '../../utils/memory_share_transport.dart';
import '../premium/premium_paywall_screen.dart';
import '../../utils/portal_layout.dart';
import '../../widgets/card_box.dart';
import '../../widgets/memories/memory_grid.dart';
import 'memory_badges_catalog.dart';

class MemoriesPage extends StatefulWidget {
  const MemoriesPage({super.key});

  @override
  State<MemoriesPage> createState() => _MemoriesPageState();
}

class _MemoriesPageState extends State<MemoriesPage> with AutomaticKeepAliveClientMixin {
  final currentBaby = CurrentBabyController.instance;
  late final MemoryController controller;

  @override
  void initState() {
    super.initState();
    controller = MemoryController(service: MemoryService(AppDatabase.instance));
    currentBaby.addListener(_onBaby);
    _onBaby();
  }

  @override
  void dispose() {
    currentBaby.removeListener(_onBaby);
    controller.dispose();
    super.dispose();
  }

  void _onBaby() {
    controller.loadForBaby(currentBaby.currentBabyId);
  }

  Future<void> _showAlbumPdfActions(Uint8List pdfBytes, String fileName) async {
    final s = S.of(context);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.memoriesAlbumPdfReadyTitle,
                style: Theme.of(ctx).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  await shareTempBytes(pdfBytes, fileName, 'application/pdf');
                },
                icon: const Icon(Icons.ios_share_rounded),
                label: Text(s.memoriesAlbumShareAction),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    await savePdfBytes(pdfBytes, fileName);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.memoriesAlbumSavedSnack)));
                  } catch (e) {
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${s.memoriesAlbumSaveFailedSnack} ($e)')),
                    );
                  }
                },
                icon: const Icon(Icons.download_rounded),
                label: Text(s.memoriesAlbumSaveAction),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _exportMemoryAlbum(List<MemoryBadge> badges) async {
    final babyId = currentBaby.currentBabyId;
    final babyRow = currentBaby.currentBabyRow;
    if (!mounted || babyId == null || babyRow == null) return;
    final s = S.of(context);

    if (!FeatureAccess.canGenerateMemoryBook) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.plusSnackLockedFeature)));
      await openPremiumPaywall(context);
      return;
    }

    final filled = _filledCount(badges);
    if (filled == 0) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.memoriesAlbumNeedFilled)));
      return;
    }

    final pages = <MemoryAlbumPageInput>[];
    for (final b in badges) {
      final m = controller.byBadge[b.id];
      if (m == null) continue;
      final hasPhoto = (m.photoB64?.trim().isNotEmpty == true) || (m.photoUrl?.trim().isNotEmpty == true);
      final hasDesc = (m.description ?? '').trim().isNotEmpty;
      if (!hasPhoto && !hasDesc) continue;
      pages.add(MemoryAlbumPageInput(
        badge: b,
        memory: m,
      ));
    }
    if (pages.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(s.memoriesAlbumNeedFilled)));
      return;
    }

    if (kIsWeb) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.memoriesAlbumError)),
      );
      return;
    }

    showDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Text(s.memoriesAlbumGenerating)),
            ],
          ),
        ),
      ),
    );

    try {
      final babyName = ((babyRow['name'] as String?) ?? '').trim();
      final displayName = babyName.isEmpty ? '—' : babyName;
      final pdfBytes = await buildMemoryAlbumMemoryBookPdf(
        context: context,
        babyName: displayName,
        strings: MemoryAlbumPdfStrings(
          coverMainTitle: s.memoriesAlbumCoverMain,
          coverTagline: s.memoriesAlbumCoverTagline(displayName),
          footer: s.memoriesAlbumFooter,
        ),
        pages: pages,
      );
      final stamp = DateTime.now().toIso8601String().replaceAll(':', '').split('.').first;
      final fileName = 'facebaby_album_$stamp.pdf';
      if (!mounted) return;
      await _showAlbumPdfActions(pdfBytes, fileName);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${s.memoriesAlbumError} ($e)')),
        );
      }
    } finally {
      if (mounted) {
        final nav = Navigator.of(context, rootNavigator: true);
        if (nav.canPop()) nav.pop();
      }
    }
  }

  @override
  bool get wantKeepAlive => true;

  int _filledCount(List<MemoryBadge> badges) {
    var n = 0;
    for (final b in badges) {
      final m = controller.byBadge[b.id];
      if (m != null &&
          (m.photoB64?.trim().isNotEmpty == true ||
              m.photoUrl?.trim().isNotEmpty == true ||
              (m.description ?? '').trim().isNotEmpty)) {
        n++;
      }
    }
    return n;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final babyId = currentBaby.currentBabyId;
    final babyRow = currentBaby.currentBabyRow;
    final badges = MemoryBadgesCatalog.all();

    return AnimatedBuilder(
      animation: Listenable.merge([controller, currentBaby, PremiumService.instance]),
      builder: (context, _) {
        final tint = AppTheme.backdropTintForSex(
          ((babyRow?['sex'] as String?)?.trim().toUpperCase() == 'M') ? 'M' : 'F',
        );
        final filled = _filledCount(badges);
        final total = badges.length;
        final showProgress = babyId != null &&
            babyRow != null &&
            !controller.loading &&
            controller.error == null;

        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.memoriesTitle,
                    style: TextStyle(fontSize: portalSp(context, 28), fontWeight: FontWeight.w900, height: 1.15),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.memoriesSubtitle,
                    maxLines: 4,
                    softWrap: true,
                    style: TextStyle(color: AppTheme.textPrimary.withAlpha(170), height: 1.35, fontSize: portalSp(context, 14)),
                  ),
                ],
              ),
              if (showProgress) ...[
                const SizedBox(height: 16),
                _MemoriesProgressBanner(
                  tint: tint,
                  filled: filled,
                  total: total,
                  progressLabel: s.memoriesProgressSaved(filled, total),
                  cheerEmpty: filled == 0 ? s.memoriesCheerEmpty : null,
                  freePlanCaption: PremiumService.instance.isPremium
                      ? null
                      : s.plusMemoryCounterFree(filled, PremiumConstants.freeMemoryMomentsMax),
                ),
              ],
              if (babyId != null && babyRow != null && !controller.loading && controller.error == null) ...[
                const SizedBox(height: 14),
                _MemoryAlbumPromoCard(
                  onDownload: () => _exportMemoryAlbum(badges),
                  title: s.memoriesAlbumPromoTitle,
                  subtitle: s.memoriesAlbumPromoSubtitle,
                  cta: s.memoriesAlbumDownloadCta,
                ),
              ],
              const SizedBox(height: 18),
              if (babyId == null || babyRow == null)
                CardBox(
                  child: Text(
                    s.feedingNoBabyHint,
                    style: TextStyle(color: Colors.black.withAlpha(140), fontWeight: FontWeight.w700),
                  ),
                )
              else if (controller.loading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 28),
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (controller.error != null)
                CardBox(
                  child: Text(
                    'Erro ao carregar memórias: ${controller.error}',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                )
              else
                MemoryGrid(
                  key: ValueKey(babyId),
                  badges: badges,
                  controller: controller,
                  babyId: babyId,
                  babyRow: babyRow,
                ),
              const SizedBox(height: 18),
            ],
          ),
        );
      },
    );
  }
}

/// Convite promocional para descarregar o PDF completo do álbum.
class _MemoryAlbumPromoCard extends StatelessWidget {
  final VoidCallback onDownload;
  final String title;
  final String subtitle;
  final String cta;

  const _MemoryAlbumPromoCard({
    required this.onDownload,
    required this.title,
    required this.subtitle,
    required this.cta,
  });

  @override
  Widget build(BuildContext context) {
    final accent = Color.lerp(AppTheme.primaryPink, AppTheme.primaryPurple, 0.45)!;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onDownload,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(Colors.white, accent, 0.14)!,
                Color.lerp(AppTheme.mint, AppTheme.babyBlue, 0.35)!,
                Color.lerp(Colors.white, AppTheme.primaryPurple, 0.08)!,
              ],
              stops: const [0.0, 0.5, 1.0],
            ),
            border: Border.all(color: Colors.white.withAlpha(220), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: accent.withAlpha(55),
                blurRadius: 22,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(11),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            Colors.white.withAlpha(230),
                            Color.lerp(Colors.white, accent, 0.12)!,
                          ],
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(color: accent.withAlpha(50), blurRadius: 10, offset: const Offset(0, 4)),
                        ],
                        border: Border.all(color: Colors.white.withAlpha(200)),
                      ),
                      child: Icon(Icons.menu_book_rounded, size: 28, color: accent.withAlpha(245)),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  title,
                                  style: TextStyle(
                                    fontSize: portalSp(context, 16.5),
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                    color: AppTheme.textPrimary,
                                    letterSpacing: -0.3,
                                  ),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: accent.withAlpha(36),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.picture_as_pdf_rounded, size: 15, color: accent.withAlpha(240)),
                                    const SizedBox(width: 4),
                                    Text(
                                      'PDF',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w900,
                                        fontSize: portalSp(context, 11),
                                        color: accent.withAlpha(240),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: portalSp(context, 13),
                              height: 1.4,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.textSecondary.withAlpha(235),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: onDownload,
                    icon: const Icon(Icons.download_rounded, size: 22),
                    label: Text(cta, style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.2)),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Card destacado: progresso do álbum + convite quando ainda está vazio.
class _MemoriesProgressBanner extends StatelessWidget {
  final Color tint;
  final int filled;
  final int total;
  final String progressLabel;
  final String? cheerEmpty;
  final String? freePlanCaption;

  const _MemoriesProgressBanner({
    required this.tint,
    required this.filled,
    required this.total,
    required this.progressLabel,
    this.cheerEmpty,
    this.freePlanCaption,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = total > 0 ? (filled / total).clamp(0.0, 1.0) : 0.0;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(tint, AppTheme.primaryPurple, 0.14)!,
            Color.lerp(tint, AppTheme.mint, 0.12)!,
            Color.lerp(Colors.white, AppTheme.babyBlue, 0.06)!,
          ],
          stops: const [0.0, 0.55, 1.0],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withAlpha(210)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryPurple.withAlpha(42),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(200),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(color: AppTheme.primaryPurple.withAlpha(24), blurRadius: 8, offset: const Offset(0, 2)),
                  ],
                ),
                child: Icon(Icons.auto_awesome_rounded, size: 22, color: AppTheme.primaryPurple.withAlpha(240)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  progressLabel,
                  style: TextStyle(
                    fontSize: portalSp(context, 14.5),
                    fontWeight: FontWeight.w900,
                    height: 1.2,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(230),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AppTheme.primaryPurple.withAlpha(50)),
                ),
                child: Text(
                  '$filled/$total',
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: portalSp(context, 13),
                    color: AppTheme.primaryPurple,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 9,
              backgroundColor: Colors.white.withAlpha(140),
              valueColor: AlwaysStoppedAnimation<Color>(
                Color.lerp(AppTheme.primaryPurple, AppTheme.mint, 0.35)!,
              ),
            ),
          ),
          if (freePlanCaption != null) ...[
            const SizedBox(height: 10),
            Text(
              freePlanCaption!,
              style: TextStyle(
                fontSize: portalSp(context, 12.5),
                fontWeight: FontWeight.w700,
                height: 1.35,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          if (cheerEmpty != null) ...[
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(Icons.touch_app_rounded, size: 18, color: AppTheme.textSecondary.withAlpha(220)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    cheerEmpty!,
                    style: TextStyle(
                      fontSize: portalSp(context, 13),
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
