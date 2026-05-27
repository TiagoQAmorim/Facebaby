import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../i18n/app_i18n.dart';
import '../services/ai/family_homily_service.dart';
import '../services/family_homily_read_prefs.dart';
import '../services/premium/feature_access.dart';
import '../services/premium/premium_service.dart';
import '../theme/app_theme.dart';
import '../pages/premium/premium_paywall_screen.dart';

/// Guia Homilia — homilia diária por IA (calendário litúrgico cristão).
class FamilyHomilyPanel extends StatefulWidget {
  const FamilyHomilyPanel({
    super.key,
    required this.requestGeneration,
  });

  final bool requestGeneration;

  @override
  State<FamilyHomilyPanel> createState() => _FamilyHomilyPanelState();
}

class _FamilyHomilyPanelState extends State<FamilyHomilyPanel> {
  final _service = FamilyHomilyService();
  FamilyDailyHomily? _homily;
  bool _loading = false;
  bool _generationAttempted = false;
  String? _error;
  StreamSubscription<FamilyDailyHomily?>? _watchSub;
  bool _markedRead = false;

  @override
  void initState() {
    super.initState();
    PremiumService.instance.addListener(_onPremium);
    if (FeatureAccess.canUseAiFamilyHomily) {
      _watchSub = _service.watchToday().listen(_onHomilyDoc);
      unawaited(_loadCacheOnly());
      if (widget.requestGeneration) {
        unawaited(_bootstrapToday());
      }
    }
  }

  @override
  void didUpdateWidget(covariant FamilyHomilyPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.requestGeneration &&
        !oldWidget.requestGeneration &&
        FeatureAccess.canUseAiFamilyHomily) {
      unawaited(_bootstrapToday());
    }
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    PremiumService.instance.removeListener(_onPremium);
    super.dispose();
  }

  void _onHomilyDoc(FamilyDailyHomily? doc) {
    if (!mounted) return;
    setState(() => _homily = doc);
    if (doc != null && doc.homilyText.trim().isNotEmpty) {
      unawaited(_markReadIfNeeded());
    }
  }

  Future<void> _markReadIfNeeded() async {
    if (_markedRead || !widget.requestGeneration) return;
    _markedRead = true;
    await FamilyHomilyReadPrefs.markTodayRead();
  }

  void _onPremium() {
    if (!mounted) return;
    setState(() {});
    if (FeatureAccess.canUseAiFamilyHomily) {
      _watchSub ??= _service.watchToday().listen(_onHomilyDoc);
      unawaited(_loadCacheOnly());
      if (widget.requestGeneration) {
        unawaited(_bootstrapToday());
      }
    } else {
      _watchSub?.cancel();
      _watchSub = null;
    }
  }

  Future<void> _loadCacheOnly() async {
    final cached = await _service.loadTodayCached();
    if (!mounted || cached == null) return;
    setState(() => _homily = cached);
    if (cached.homilyText.trim().isNotEmpty) {
      await _markReadIfNeeded();
    }
    await FamilyHomilyUnreadBadge.refresh();
  }

  Future<void> _bootstrapToday() async {
    if (!FeatureAccess.canUseAiFamilyHomily) return;
    if (_loading) return;
    final lang = FamilyHomilyService.languageCodeFromApp(S.of(context));
    setState(() {
      _loading = true;
      _error = null;
      _generationAttempted = true;
    });
    try {
      final cached = await _service.loadTodayCached();
      if (cached != null && mounted) {
        setState(() => _homily = cached);
      }
      await FamilyHomilyBootstrap.ensureToday(languageCode: lang);
      if (mounted) {
        final again = await _service.loadTodayCached();
        if (again != null) {
          setState(() => _homily = again);
          await _markReadIfNeeded();
        }
      }
    } on FamilyHomilyException catch (e) {
      if (mounted) {
        setState(() => _error = S.of(context).familyHomilyError(
              e.code,
              serverMessage: e.serverMessage,
            ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = S.of(context).familyHomilyError('internal'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
      await FamilyHomilyUnreadBadge.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final premium = FeatureAccess.canUseAiFamilyHomily;
    final dateLabel = DateFormat('dd/MM/yyyy').format(DateTime.now());

    if (!premium) {
      return _PremiumCard(s: s);
    }

    final waitingForContent =
        widget.requestGeneration && _loading && _homily == null;
    final showError = widget.requestGeneration &&
        !_loading &&
        _homily == null &&
        _generationAttempted;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.familyHomilyDate(dateLabel),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black.withAlpha(140),
          ),
        ),
        const SizedBox(height: 12),
        if (!widget.requestGeneration)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              s.familyHomilyOpenTabHint,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withAlpha(130),
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          )
        else if (waitingForContent)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Column(
              children: [
                const CircularProgressIndicator(
                  color: Color(0xFF5D4037),
                ),
                const SizedBox(height: 16),
                Text(
                  s.familyHomilyLoading,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.black.withAlpha(150),
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          )
        else if (_homily != null) ...[
          if (_homily!.liturgicalDay.trim().isNotEmpty)
            _HomilyMetaCard(
              icon: Icons.church_rounded,
              label: s.familyHomilyLiturgicalDay,
              body: _homily!.liturgicalDay,
              accent: const Color(0xFF5D4037),
            ),
          if (_homily!.feastOrMemorial.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _HomilyMetaCard(
              icon: Icons.celebration_rounded,
              label: s.familyHomilyFeast,
              body: _homily!.feastOrMemorial,
              accent: const Color(0xFF8D6E63),
            ),
          ],
          if (_homily!.gospelReference.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            _HomilyMetaCard(
              icon: Icons.menu_book_rounded,
              label: s.familyHomilyGospel,
              body: _homily!.gospelReference,
              accent: const Color(0xFF6A1B9A),
            ),
          ],
          const SizedBox(height: 12),
          _HomilyBodyCard(
            title: s.familyHomilyTitle,
            body: _homily!.homilyText,
          ),
          if (_homily!.familyReflection.trim().isNotEmpty) ...[
            const SizedBox(height: 12),
            _HomilyBodyCard(
              title: s.familyHomilyFamilyReflection,
              body: _homily!.familyReflection,
              accent: const Color(0xFF3949AB),
            ),
          ],
        ] else if (showError)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              _error ?? s.familyHomilyError('internal'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withAlpha(140),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const SizedBox(height: 16),
        Text(
          s.familyHomilyDisclaimer,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 10.5,
            height: 1.35,
            fontStyle: FontStyle.italic,
            color: Colors.black.withAlpha(110),
          ),
        ),
      ],
    );
  }
}

class _PremiumCard extends StatelessWidget {
  const _PremiumCard({required this.s});
  final S s;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(235),
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const Icon(Icons.church_rounded, size: 48, color: Color(0xFF5D4037)),
            const SizedBox(height: 12),
            Text(
              s.familyHomilyPremiumTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.familyHomilyPremiumBody,
              textAlign: TextAlign.center,
              style: TextStyle(
                height: 1.4,
                color: Colors.black.withAlpha(160),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => openPremiumPaywall(context),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primaryPink,
              ),
              child: Text(s.familyPremiumUnlockCta),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomilyMetaCard extends StatelessWidget {
  const _HomilyMetaCard({
    required this.icon,
    required this.label,
    required this.body,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(245),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: accent.withAlpha(60)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                      color: accent.withAlpha(220),
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    body,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.4,
                      fontWeight: FontWeight.w600,
                      color: Colors.black.withAlpha(200),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomilyBodyCard extends StatelessWidget {
  const _HomilyBodyCard({
    required this.title,
    required this.body,
    this.accent = const Color(0xFF5D4037),
  });

  final String title;
  final String body;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withAlpha(245),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: accent.withAlpha(70)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 15,
                color: accent.withAlpha(240),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              body,
              style: TextStyle(
                fontSize: 14,
                height: 1.45,
                color: Colors.black.withAlpha(200),
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
