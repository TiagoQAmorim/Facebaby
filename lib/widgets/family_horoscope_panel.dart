import 'dart:async' show StreamSubscription, unawaited;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../i18n/app_i18n.dart';
import '../services/ai/family_horoscope_service.dart';
import '../services/family_horoscope_read_prefs.dart';
import '../services/premium/feature_access.dart';
import '../services/premium/premium_service.dart';
import '../theme/app_theme.dart';
import '../pages/premium/premium_paywall_screen.dart';
import '../utils/family_zodiac_art.dart';
import '../utils/zodiac_keys.dart';

/// Guia Horóscopo — conteúdo diário por IA (geração automática, sem refresh).
class FamilyHoroscopePanel extends StatefulWidget {
  const FamilyHoroscopePanel({
    super.key,
    required this.fatherRegistered,
    required this.onRegisterFather,
  });

  final bool fatherRegistered;
  final VoidCallback onRegisterFather;

  @override
  State<FamilyHoroscopePanel> createState() => _FamilyHoroscopePanelState();
}

class _FamilyHoroscopePanelState extends State<FamilyHoroscopePanel> {
  final _service = FamilyHoroscopeService();
  FamilyDailyHoroscope? _horoscope;
  bool _loading = false;
  String? _error;
  StreamSubscription<FamilyDailyHoroscope?>? _watchSub;

  @override
  void initState() {
    super.initState();
    PremiumService.instance.addListener(_onPremium);
    if (FeatureAccess.canUseAiFamilyHoroscope) {
      _watchSub = _service.watchToday().listen((doc) {
        if (!mounted) return;
        setState(() => _horoscope = doc);
      });
      unawaited(_bootstrapToday());
    }
  }

  @override
  void dispose() {
    _watchSub?.cancel();
    PremiumService.instance.removeListener(_onPremium);
    super.dispose();
  }

  void _onPremium() {
    if (!mounted) return;
    setState(() {});
    if (FeatureAccess.canUseAiFamilyHoroscope) {
      _watchSub ??= _service.watchToday().listen((doc) {
        if (!mounted) return;
        setState(() => _horoscope = doc);
      });
      unawaited(_bootstrapToday());
    } else {
      _watchSub?.cancel();
      _watchSub = null;
    }
  }

  Future<void> _bootstrapToday() async {
    if (!FeatureAccess.canUseAiFamilyHoroscope) return;
    setState(() {
      _loading = _horoscope == null;
      _error = null;
    });
    try {
      final cached = await _service.loadTodayCached();
      if (cached != null && mounted) {
        setState(() => _horoscope = cached);
      }
      await FamilyHoroscopeBootstrap.ensureToday();
      if (mounted) {
        final again = await _service.loadTodayCached();
        if (again != null) setState(() => _horoscope = again);
      }
    } on FamilyHoroscopeException catch (e) {
      if (mounted) {
        setState(() => _error = S.of(context).familyHoroscopeError(
              e.code,
              serverMessage: e.serverMessage,
            ));
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = S.of(context).familyHoroscopeError('internal'));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
      await FamilyHoroscopeUnreadBadge.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final premium = FeatureAccess.canUseAiFamilyHoroscope;
    final dateLabel = DateFormat('dd/MM/yyyy').format(DateTime.now());

    if (!premium) {
      return _PremiumCard(s: s);
    }

    final showSpinner = _loading && _horoscope == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          s.familyHoroscopeDate(dateLabel),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: Colors.black.withAlpha(140),
          ),
        ),
        const SizedBox(height: 12),
        if (!widget.fatherRegistered) ...[
          Material(
            color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              onTap: widget.onRegisterFather,
              borderRadius: BorderRadius.circular(14),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.person_add_alt_1_rounded,
                        color: Color(0xFF6A1B9A)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        s.familyHoroscopeRegisterFather,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        if (showSpinner)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 32),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_horoscope != null) ...[
          _HoroscopeCard(
            title: s.familyHoroscopeMother,
            sign: _horoscope!.motherSign,
            body: _horoscope!.motherText,
          ),
          if (_horoscope!.hasFather) ...[
            const SizedBox(height: 12),
            _HoroscopeCard(
              title: s.familyHoroscopeFather,
              sign: _horoscope!.fatherSign,
              body: _horoscope!.fatherText,
            ),
          ],
          const SizedBox(height: 12),
          _HoroscopeCard(
            title: s.familyHoroscopeBaby,
            sign: _horoscope!.babySign,
            body: _horoscope!.babyText,
          ),
          const SizedBox(height: 12),
          _HoroscopeCard(
            title: s.familyHoroscopeFamilyEnergy,
            sign: null,
            body: _horoscope!.familyCompatibilityText,
            accent: const Color(0xFF8E24AA),
          ),
          const SizedBox(height: 12),
          _HoroscopeCard(
            title: s.familyHoroscopeDailyAdvice,
            sign: null,
            body: _horoscope!.familyAdviceText,
            accent: const Color(0xFFE91E8C),
          ),
        ] else if (!_loading) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              s.familyHoroscopeError('internal'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.black.withAlpha(140),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Colors.red.shade700, fontSize: 13),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          s.familyHoroscopeDisclaimer,
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
            const Icon(Icons.nights_stay_rounded,
                size: 48, color: Color(0xFF8E24AA)),
            const SizedBox(height: 12),
            Text(
              s.familyHoroscopePremiumTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 17,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              s.familyHoroscopePremiumBody,
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

class _HoroscopeCard extends StatelessWidget {
  const _HoroscopeCard({
    required this.title,
    required this.body,
    this.sign,
    this.accent,
  });

  final String title;
  final String body;
  final String? sign;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final border = accent ?? const Color(0xFFCE93D8);
    return Material(
      color: Colors.white.withAlpha(245),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: border.withAlpha(80)),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (sign != null && sign!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: _ZodiacSignIcon(sign: sign!, size: 32),
                  ),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 15,
                      color: border.withAlpha(240),
                    ),
                  ),
                ),
              ],
            ),
            if (sign != null && sign!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                sign!,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: Colors.black.withAlpha(120),
                ),
              ),
            ],
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

/// Ícone PNG do signo (`assets/family/zodiac_*.png`), igual à árvore familiar.
class _ZodiacSignIcon extends StatelessWidget {
  const _ZodiacSignIcon({required this.sign, this.size = 32});

  final String sign;
  final double size;

  @override
  Widget build(BuildContext context) {
    final id = zodiacIdFromSignLabel(sign);
    if (id == null) {
      return Icon(
        Icons.star_rounded,
        size: size,
        color: const Color(0xFF8E24AA).withAlpha(200),
      );
    }
    return Image.asset(
      familyZodiacIconAsset(id),
      width: size,
      height: size,
      fit: BoxFit.contain,
      errorBuilder: (_, __, ___) => Icon(
        Icons.star_rounded,
        size: size,
        color: const Color(0xFF8E24AA),
      ),
    );
  }
}
