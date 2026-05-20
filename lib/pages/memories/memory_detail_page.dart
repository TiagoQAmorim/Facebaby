import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:photo_view/photo_view.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../controllers/memory_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../services/premium/feature_access.dart';
import '../premium/premium_paywall_screen.dart';
import '../../models/baby_memory.dart';
import '../../models/memory_badge.dart';
import '../../theme/app_theme.dart';
import '../../utils/memory_share_file.dart';
import '../../utils/memory_share_transport.dart';
import '../../utils/memory_moment_localizations.dart';
import '../../utils/photo_b64.dart';
import '../../utils/portal_layout.dart';
import '../../utils/portal_night_ui.dart';
import '../../utils/portal_page_route.dart';
import '../../utils/weekly_photo_schedule.dart';
import '../../utils/measurement_format.dart';
import '../../widgets/memories/cached_memory_photo.dart';
import '../../widgets/memories/memory_badge_icon.dart';
import '../../widgets/memories/memory_share_card.dart';
import '../../widgets/weekly_photo_crown_icon.dart';
import 'add_memory_page.dart';

enum _ShareExportKind { jpeg, pdf }

class MemoryDetailPage extends StatefulWidget {
  final MemoryBadge badge;
  final BabyMemory memory;
  final String heroTag;
  final MemoryController controller;

  const MemoryDetailPage({
    super.key,
    required this.badge,
    required this.memory,
    required this.heroTag,
    required this.controller,
  });

  @override
  State<MemoryDetailPage> createState() => _MemoryDetailPageState();
}

class _MemoryDetailPageState extends State<MemoryDetailPage> {
  late BabyMemory _memory;
  bool _savingPublic = false;
  bool _shareBusy = false;
  final GlobalKey _shareCaptureKey = GlobalKey();

  /// Bytes efetivamente usados pelo [MemoryShareCard] (captura JPG/PDF).
  /// Mantém foto local (base64) ou descarga de [BabyMemory.photoUrl] — igual ao preview na página.
  Uint8List? _sharePhotoResolved;

  /// Fundo suave tipo mock (cartão principal “informações do momento”).
  static const _purpleCardBg = Color(0xFFF3EEFF);
  static const _purpleTitle = Color(0xFF7B5FB8);

  /// Quadros individuais.
  static const _chipAgeBg = Color(0xFFEDE8FF);
  static const _chipWeightBg = Color(0xFFFFE9F5);
  static const _chipHeightBg = Color(0xFFE5F2FF);
  static const _chipMoodBg = Color(0xFFFFF6E5);

  @override
  void initState() {
    super.initState();
    _memory = widget.memory;
    final b64 = decodePhotoB64(_memory.photoB64);
    if (b64 != null) {
      _sharePhotoResolved = b64;
    } else {
      final url = (_memory.photoUrl ?? '').trim();
      if (url.isNotEmpty) {
        unawaited(_downloadSharePhotoForExport(url));
      }
    }
  }

  void _restartShareResolvedPhoto({required bool loadUrlIfNeeded}) {
    final local = decodePhotoB64(_memory.photoB64);
    if (local != null) {
      if (!mounted) {
        _sharePhotoResolved = local;
        return;
      }
      setState(() => _sharePhotoResolved = local);
      return;
    }

    final url = (_memory.photoUrl ?? '').trim();

    void clearResolved() {
      if (!mounted) {
        _sharePhotoResolved = null;
        return;
      }
      if (_sharePhotoResolved != null) {
        setState(() => _sharePhotoResolved = null);
      } else {
        _sharePhotoResolved = null;
      }
    }

    if (!loadUrlIfNeeded || url.isEmpty) {
      clearResolved();
      return;
    }

    clearResolved();
    unawaited(_downloadSharePhotoForExport(url));
  }

  Future<void> _downloadSharePhotoForExport(String url) async {
    try {
      Uint8List? out;
      try {
        final file = await memoryPhotoCacheManager.getSingleFile(url);
        out = await file.readAsBytes();
      } catch (_) {
        final resp =
            await http.get(Uri.parse(url)).timeout(const Duration(seconds: 30));
        if (resp.statusCode >= 200 &&
            resp.statusCode < 300 &&
            resp.bodyBytes.isNotEmpty) {
          out = resp.bodyBytes;
        }
      }
      if (!mounted) return;
      if (out != null && out.isNotEmpty) {
        setState(() => _sharePhotoResolved = out);
      }
    } catch (e, st) {
      debugPrint('share photo download failed: $e\n$st');
    }
  }

  String _weightStr() {
    final w = _memory.weightAtMoment;
    return MeasurementFormat.weight(w, decimalsKg: 2);
  }

  String _heightStr() {
    final h = _memory.heightAtMoment;
    return MeasurementFormat.length(h, decimalsCm: 1);
  }

  String _moodStr() =>
      (_memory.moodAtMoment == null || _memory.moodAtMoment!.trim().isEmpty)
          ? '—'
          : _memory.moodAtMoment!.trim();

  String _ageStr() => (_memory.babyAgeAtMoment == null ||
          _memory.babyAgeAtMoment!.trim().isEmpty)
      ? '—'
      : _memory.babyAgeAtMoment!.trim();

  String _tipText() => S.of(context).memoryTipForBadgeId(widget.badge.id);

  void _openFullPhoto(BuildContext context, Uint8List bytes) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      useSafeArea: false,
      barrierColor: Colors.black,
      builder: (ctx) {
        final pad = MediaQuery.paddingOf(ctx);
        final sz = MediaQuery.sizeOf(ctx);
        return Material(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PhotoView(
                imageProvider: MemoryImage(bytes),
                gaplessPlayback: true,
                minScale: PhotoViewComputedScale.contained * 0.85,
                maxScale: PhotoViewComputedScale.covered * 4,
                initialScale: PhotoViewComputedScale.contained,
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                loadingBuilder: (c, event) => const Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
                filterQuality: FilterQuality.medium,
                customSize: sz,
              ),
              Positioned(
                top: pad.top + 8,
                right: 12,
                child: IconButton(
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withAlpha(140)),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _openFullPhotoFromNetworkUrl(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      useSafeArea: false,
      barrierColor: Colors.black,
      builder: (ctx) {
        final pad = MediaQuery.paddingOf(ctx);
        final sz = MediaQuery.sizeOf(ctx);
        final provider = memoryPhotoNetworkImageProvider(url);
        return Material(
          color: Colors.black,
          child: Stack(
            fit: StackFit.expand,
            children: [
              PhotoView(
                imageProvider: provider,
                gaplessPlayback: true,
                minScale: PhotoViewComputedScale.contained * 0.85,
                maxScale: PhotoViewComputedScale.covered * 4,
                initialScale: PhotoViewComputedScale.contained,
                backgroundDecoration: const BoxDecoration(color: Colors.black),
                loadingBuilder: (c, event) => const Center(
                  child: CircularProgressIndicator(color: Colors.white54),
                ),
                filterQuality: FilterQuality.medium,
                customSize: sz,
              ),
              Positioned(
                top: pad.top + 8,
                right: 12,
                child: IconButton(
                  style: IconButton.styleFrom(
                      backgroundColor: Colors.black.withAlpha(140)),
                  icon: const Icon(Icons.close, color: Colors.white, size: 28),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _persistPublic(BabyMemory next) async {
    if (_savingPublic) return;
    setState(() => _savingPublic = true);
    try {
      await widget.controller.upsert(next);
      if (mounted) setState(() => _memory = next);
    } finally {
      if (mounted) setState(() => _savingPublic = false);
    }
  }

  Future<void> _requestPublicOff() async {
    await _persistPublic(
      _memory.copyWith(
        isPublic: false,
        publicDisabledAt: DateTime.now(),
        eligibleForWeeklyPhoto: false,
      ),
    );
  }

  Future<void> _requestPublicOn() async {
    final bytes = decodePhotoB64(_memory.photoB64);
    final url = (_memory.photoUrl ?? '').trim();
    final hasPhoto = bytes != null || url.isNotEmpty;
    final s = S.of(context);
    if (!hasPhoto) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(s.weeklyPhotoPublicNeedPhoto)));
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    final key = 'fb_weekly_photo_confirm_${_memory.babyId}_${_memory.badgeId}';
    final seen = prefs.getBool(key) ?? false;
    if (!seen) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(s.weeklyPhotoConfirmTitle),
          content: Text(s.weeklyPhotoConfirmBody),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(s.weeklyPhotoConfirmCancel)),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: Text(s.weeklyPhotoConfirmOk)),
          ],
        ),
      );
      if (ok != true) return;
      await prefs.setBool(key, true);
    }
    if (!mounted) return;
    final now = DateTime.now();
    await _persistPublic(
      _memory.copyWith(
        isPublic: true,
        publicEnabledAt: now,
        publicDisabledAt: null,
      ),
    );
  }

  Future<void> _onPublicToggleChanged(bool v) async {
    if (_savingPublic) return;
    if (v) {
      await _requestPublicOn();
    } else {
      await _requestPublicOff();
    }
  }

  Future<void> _setShowBabyFirstName(bool v) async {
    await _persistPublic(_memory.copyWith(showBabyFirstNameWhenPublic: v));
  }

  Future<void> _openEditor() async {
    final ok = await Navigator.of(context).push<bool>(
      portalPageRoute<bool>(
        builder: (_) => AddMemoryPage(
          babyId: _memory.babyId,
          badge: widget.badge,
          controller: widget.controller,
          initialMemory: _memory,
        ),
      ),
    );
    if (ok == true && mounted) {
      final m = widget.controller.byBadge[widget.badge.id];
      if (m != null) {
        setState(() => _memory = m);
        _restartShareResolvedPhoto(loadUrlIfNeeded: true);
      }
    }
  }

  Future<void> _promptShare() async {
    if (_shareBusy) return;
    final strings = S.of(context);
    if (kIsWeb) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(strings.memoryShareWebOnlyMobile)),
      );
      return;
    }

    if (!FeatureAccess.canExportBadges) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(strings.plusSnackLockedFeature)));
      await openPremiumPaywall(context);
      return;
    }

    final kind = await showModalBottomSheet<_ShareExportKind>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final s = S.of(ctx);
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.image_outlined),
                title: Text(s.memoryShareSheetJpegTitle),
                subtitle: Text(s.memoryShareSheetJpegSubtitle),
                onTap: () => Navigator.pop(ctx, _ShareExportKind.jpeg),
              ),
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: Text(s.memoryShareSheetPdfTitle),
                subtitle: Text(s.memoryShareSheetPdfSubtitle),
                onTap: () => Navigator.pop(ctx, _ShareExportKind.pdf),
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );

    if (kind == null || !mounted) return;

    var showedLoader = false;
    setState(() => _shareBusy = true);

    try {
      if (!mounted) return;
      showedLoader = true;
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => PopScope(
          canPop: false,
          child: AlertDialog(
            content: Row(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(width: 20),
                Expanded(child: Text(S.of(context).memoriesAlbumGenerating)),
              ],
            ),
          ),
        ),
      );

      // Esperar pipeline de imagem: [MemoryShareCard] usa Image.memory (decode assíncrono);
      // sem isto o RepaintBoundary pode capturar só o retângulo vazio.
      await Future<void>.delayed(const Duration(milliseconds: 96));
      await _maybePrecacheResolvedSharePhotoForCapture();

      final png =
          await repaintBoundaryToPngBytes(_shareCaptureKey, pixelRatio: 3);
      final jpg = encodePngBytesToJpg(png, quality: 88);
      final stamp = DateTime.now().millisecondsSinceEpoch;

      switch (kind) {
        case _ShareExportKind.jpeg:
          await shareTempBytes(
              jpg, 'facebaby_memoria_$stamp.jpg', 'image/jpeg');
          break;
        case _ShareExportKind.pdf:
          final pdfBin = await buildSinglePagePdfWithImage(jpg);
          await shareTempBytes(
              pdfBin, 'facebaby_memoria_$stamp.pdf', 'application/pdf');
          break;
      }
    } on UnsupportedError catch (e) {
      if (mounted) {
        final s = S.of(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(e.message ?? s.memorySharePlatformUnavailable)),
        );
      }
    } catch (e, st) {
      debugPrint('$e\n$st');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).memoryShareError(e))),
        );
      }
    } finally {
      if (showedLoader && mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }
      if (mounted) setState(() => _shareBusy = false);
    }
  }

  Future<void> _maybePrecacheResolvedSharePhotoForCapture() async {
    Uint8List? resolved =
        decodePhotoB64(_memory.photoB64) ?? _sharePhotoResolved;
    final url = (_memory.photoUrl ?? '').trim();
    if (resolved == null && url.isNotEmpty) {
      await _downloadSharePhotoForExport(url);
      resolved = decodePhotoB64(_memory.photoB64) ?? _sharePhotoResolved;
      // [MemoryShareCard] atualiza com novo override só após rebuild.
      await WidgetsBinding.instance.endOfFrame;
    }
    if (!mounted) return;

    if (resolved != null && resolved.isNotEmpty) {
      await precacheImage(MemoryImage(resolved), context);
    } else if (url.isNotEmpty) {
      await precacheImage(memoryPhotoNetworkImageProvider(url), context);
    } else {
      return;
    }
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 48));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final bytes = decodePhotoB64(_memory.photoB64);
    final url = (_memory.photoUrl ?? '').trim();
    final desc = (_memory.description ?? '').trim();

    Widget photoSquare(double side, double radius) {
      Widget inner = ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: SizedBox(
          width: side,
          height: side,
          child: (bytes == null && url.isEmpty)
              ? Container(
                  color: MemoryBadgeIcon.mutedDiskBackground,
                  alignment: Alignment.center,
                  child: MemoryBadgeIcon(
                    badge: widget.badge,
                    muted: true,
                    size: 56,
                    shape: MemoryBadgeIconShape.original,
                  ),
                )
              : (bytes != null
                  ? Image.memory(bytes, fit: BoxFit.cover)
                  : CachedMemoryPhoto(
                      imageUrl: url,
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.medium,
                      placeholder: (_, __) => ColoredBox(
                        color: AppTheme.softPurple.withAlpha(80),
                        child: const Center(
                          child: SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      ),
                    )),
        ),
      );
      if (bytes != null) {
        inner = GestureDetector(
            onTap: () => _openFullPhoto(context, bytes), child: inner);
      } else if (url.isNotEmpty) {
        inner = GestureDetector(
            onTap: () => _openFullPhotoFromNetworkUrl(context, url),
            child: inner);
      }
      return inner;
    }

    return PortalNightUi.listen((context, night) {
      final pageBg = PortalNightUi.detailPageBackground(night);
      return Stack(
        alignment: Alignment.topLeft,
        clipBehavior: Clip.none,
        children: [
          Scaffold(
            backgroundColor: pageBg,
            appBar: AppBar(
              backgroundColor: night ? AppTheme.background : null,
              surfaceTintColor: Colors.transparent,
              foregroundColor: AppTheme.textPrimary,
              iconTheme: const IconThemeData(color: AppTheme.textPrimary),
              actionsIconTheme:
                  const IconThemeData(color: AppTheme.textPrimary),
              title: const SizedBox.shrink(),
              actions: [
                IconButton(
                    onPressed: _openEditor,
                    icon: const Icon(Icons.edit_outlined)),
                IconButton(
                    onPressed: () {}, icon: const Icon(Icons.more_vert)),
              ],
            ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 6, 20, 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 900),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        MemoryBadgeIcon(
                          badge: widget.badge,
                          muted: bytes == null && url.isEmpty,
                          size: 42,
                          shape: MemoryBadgeIconShape.original,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.memoryBadgeTitle(widget.badge),
                                style: TextStyle(
                                  fontSize: portalSp(context, 22),
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.textPrimary,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                formatMemoryMomentDateTime(
                                    context, _memory.memoryDate),
                                style: TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: portalSp(context, 14),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    LayoutBuilder(
                      builder: (context, c) {
                        final veryNarrow = c.maxWidth < 340;
                        final side = veryNarrow
                            ? (c.maxWidth * 0.42).clamp(140.0, 190.0)
                            : (c.maxWidth * 0.40).clamp(180.0, 300.0);
                        const radius = 22.0;
                        final textStyle = TextStyle(
                          color: AppTheme.textPrimary.withAlpha(200),
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                          fontSize: portalSp(context, 16),
                        );

                        if (desc.isEmpty) {
                          final muted = Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              s.memoryNoDescription,
                              style:
                                  textStyle.copyWith(color: AppTheme.textMuted),
                            ),
                          );
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              photoSquare(side, radius),
                              const SizedBox(width: 18),
                              Expanded(child: muted),
                            ],
                          );
                        }

                        final remainingW =
                            (c.maxWidth - side - 18).clamp(90.0, 10000.0);
                        if (remainingW < 120) {
                          // Muito estreito: não força layout “revista” para não esmagar o texto.
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Align(
                                  alignment: Alignment.centerLeft,
                                  child: photoSquare(side, radius)),
                              const SizedBox(height: 14),
                              Text(desc, style: textStyle),
                            ],
                          );
                        }
                        final tp = TextPainter(
                          text: TextSpan(text: desc, style: textStyle),
                          textDirection: Directionality.of(context),
                          textScaler: MediaQuery.textScalerOf(context),
                        )..layout(maxWidth: remainingW);

                        final cutPos =
                            tp.getPositionForOffset(Offset(remainingW, side));
                        final cut = cutPos.offset.clamp(0, desc.length);
                        final lead = desc.substring(0, cut).trimRight();
                        final tail = desc.substring(cut).trimLeft();

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                photoSquare(side, radius),
                                const SizedBox(width: 18),
                                Expanded(
                                  child: Text(
                                    lead.isEmpty ? desc : lead,
                                    style: textStyle,
                                  ),
                                ),
                              ],
                            ),
                            if (tail.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              Text(tail, style: textStyle),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(10, 12, 10, 11),
                      decoration: BoxDecoration(
                        color: _purpleCardBg,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.memoryMomentInfoTitle,
                            style: TextStyle(
                              color: _purpleTitle,
                              fontWeight: FontWeight.w900,
                              fontSize: portalSp(context, 14),
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: _MomentStatChip(
                                  bg: _chipAgeBg,
                                  iconBg: const Color(0xFFD9CCFF),
                                  icon: Icons.calendar_month_rounded,
                                  iconColor: AppTheme.primaryPurple,
                                  label: s.memoryStatAgeLabel,
                                  value: _ageStr(),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: _MomentStatChip(
                                  bg: _chipWeightBg,
                                  iconBg: const Color(0xFFFFD0EA),
                                  icon: Icons.monitor_weight_rounded,
                                  iconColor: AppTheme.primaryPink,
                                  label: s.memoryStatWeightLabel,
                                  value: _weightStr(),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: _MomentStatChip(
                                  bg: _chipHeightBg,
                                  iconBg: const Color(0xFFCCE6FF),
                                  icon: Icons.straighten_rounded,
                                  iconColor: AppTheme.babyBlue,
                                  label: s.memoryStatHeightLabel,
                                  value: _heightStr(),
                                ),
                              ),
                              const SizedBox(width: 3),
                              Expanded(
                                child: _MomentStatChip(
                                  bg: _chipMoodBg,
                                  iconBg: const Color(0xFFFFEDC4),
                                  icon: Icons.sentiment_satisfied_alt_rounded,
                                  iconColor: AppTheme.yellow,
                                  label: s.memoryStatMoodLabel,
                                  value: _moodStr(),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if ((_memory.motherNotes ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 20),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.note_alt_rounded,
                              color: AppTheme.yellow.withAlpha(220), size: 22),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  s.memoryMotherNotesLabel,
                                  style: TextStyle(
                                    color: AppTheme.textSecondary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: portalSp(context, 14),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  _memory.motherNotes!.trim(),
                                  style: TextStyle(
                                    color: AppTheme.textPrimary.withAlpha(210),
                                    height: 1.4,
                                    fontWeight: FontWeight.w600,
                                    fontSize: portalSp(context, 14.5),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 22),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: _purpleCardBg,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome_rounded,
                                  color: _purpleTitle, size: 22),
                              const SizedBox(width: 10),
                              Text(
                                s.memoryTipForYouTitle,
                                style: TextStyle(
                                  color: _purpleTitle,
                                  fontWeight: FontWeight.w900,
                                  fontSize: portalSp(context, 15),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _tipText(),
                            style: TextStyle(
                              color: AppTheme.textPrimary.withAlpha(200),
                              height: 1.45,
                              fontWeight: FontWeight.w600,
                              fontSize: portalSp(context, 14),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (WeeklyPhotoSchedule.showParticipatingBadge(
                      isPublic: _memory.isPublic,
                      hasPhoto: bytes != null || url.isNotEmpty,
                      publicEnabledAt: _memory.publicEnabledAt,
                      now: DateTime.now(),
                    )) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.softPurple.withAlpha(160),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            WeeklyPhotoCrownIcon(size: portalSp(context, 22)),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.weeklyPhotoParticipatingBadge,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, height: 1.25),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    if (_memory.weeklyPhotoWinner) ...[
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryPink.withAlpha(55),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.celebration_rounded,
                                color: AppTheme.primaryPink, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                s.weeklyPhotoWinnerBadge,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, height: 1.25),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _shareBusy ? null : _promptShare,
                        icon: Icon(Icons.ios_share_rounded,
                            color: AppTheme.primaryPurple),
                        label: Text(
                          s.memoryShareButton,
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              color: AppTheme.primaryPurple),
                        ),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          side: BorderSide(
                              color: AppTheme.primaryPurple.withAlpha(180)),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(22)),
                          backgroundColor: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                s.weeklyPhotoPublicOff,
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontWeight: !_memory.isPublic
                                      ? FontWeight.w900
                                      : FontWeight.w600,
                                  fontSize: portalSp(context, 15),
                                  color: !_memory.isPublic
                                      ? AppTheme.textPrimary
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ),
                            Switch(
                              value: _memory.isPublic,
                              onChanged: _savingPublic
                                  ? null
                                  : (v) {
                                      unawaited(_onPublicToggleChanged(v));
                                    },
                            ),
                            Expanded(
                              child: Text(
                                s.weeklyPhotoPublicOn,
                                textAlign: TextAlign.start,
                                style: TextStyle(
                                  fontWeight: _memory.isPublic
                                      ? FontWeight.w900
                                      : FontWeight.w600,
                                  fontSize: portalSp(context, 15),
                                  color: _memory.isPublic
                                      ? AppTheme.textPrimary
                                      : AppTheme.textMuted,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Text(
                          s.weeklyPhotoPublicExplainer,
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            height: 1.45,
                            fontWeight: FontWeight.w600,
                            fontSize: portalSp(context, 13.5),
                          ),
                        ),
                      ],
                    ),
                    if (_memory.isPublic) ...[
                      const SizedBox(height: 4),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(s.weeklyPhotoShowBabyFirstName,
                            style:
                                const TextStyle(fontWeight: FontWeight.w700)),
                        value: _memory.showBabyFirstNameWhenPublic,
                        onChanged: _savingPublic
                            ? null
                            : (v) {
                                unawaited(_setShowBabyFirstName(v));
                              },
                      ),
                    ],
                    const SizedBox(height: 10),
                    Text(
                      s.weeklyPhotoDisclaimerFooter,
                      style: TextStyle(
                        fontSize: portalSp(context, 11.5),
                        color: AppTheme.textMuted,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: MediaQuery.paddingOf(context).bottom + 12),
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: -8000,
          top: 0,
          child: RepaintBoundary(
            key: _shareCaptureKey,
            child: MemoryShareCard(
              badge: widget.badge,
              memory: _memory,
              tipText: _tipText(),
              photoBytesOverride:
                  decodePhotoB64(_memory.photoB64) ?? _sharePhotoResolved,
            ),
          ),
        ),
        ],
      );
    });
  }
}

class _MomentStatChip extends StatelessWidget {
  final Color bg;
  final Color iconBg;
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  static const double _nominalChipWidth = 78;

  const _MomentStatChip({
    required this.bg,
    required this.iconBg,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final raw = ((c.maxWidth - 8) / _nominalChipWidth).clamp(0.52, 1.15);
        final textScale =
            MediaQuery.textScalerOf(context).scale(1.0).clamp(0.85, 1.5);
        final s = (raw / textScale).clamp(0.48, 1.12);
        final padH = (3 * s).clamp(2.0, 6.0);
        final padV = (5 * s).clamp(3.0, 9.0);
        final iconD = (30 * s).clamp(21.0, 34.0);
        final iconIx = (16 * s).clamp(12.0, 19.0);
        final gapIco = (4 * s).clamp(2.0, 8.0);
        final gapLbl = (2 * s).clamp(1.0, 4.0);
        final fsLabel = portalSp(context, 9 * s.clamp(0.65, 1.08));
        final fsValue = portalSp(context, 10.5 * s.clamp(0.65, 1.06));
        final labelStyle = TextStyle(
          fontSize: fsLabel.clamp(6.5, 11),
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
          height: 1.05,
        );
        final valueStyle = TextStyle(
          fontSize: fsValue.clamp(7.5, 13),
          fontWeight: FontWeight.w900,
          color: AppTheme.textPrimary,
          height: 1.1,
        );
        final r = BorderRadius.circular((11 * s).clamp(9.0, 16));
        return Container(
          constraints:
              BoxConstraints(minWidth: c.maxWidth, maxWidth: c.maxWidth),
          padding: EdgeInsets.fromLTRB(padH, padV, padH, padV),
          decoration: BoxDecoration(color: bg, borderRadius: r),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: iconD,
                height: iconD,
                decoration:
                    BoxDecoration(color: iconBg, shape: BoxShape.circle),
                alignment: Alignment.center,
                child: Icon(icon, size: iconIx, color: iconColor),
              ),
              SizedBox(height: gapIco),
              Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: labelStyle,
              ),
              SizedBox(height: gapLbl),
              Text(
                value,
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: valueStyle,
              ),
            ],
          ),
        );
      },
    );
  }
}
