import 'package:flutter/material.dart';

import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../models/baby_memory.dart';
import '../services/app_database.dart';
import '../services/memory_service.dart';
import '../theme/app_theme.dart';
import '../utils/photo_b64.dart';
import '../utils/portal_layout.dart';
import '../utils/portal_time_of_day.dart';
import '../app/shell_nested_nav.dart';
import '../widgets/memories/cached_memory_photo.dart';

/// Faixa horizontal «Últimas memórias» na Home — últimas 4 fotos da mãe no bebé atual.
class HomeRecentMemoriesSection extends StatefulWidget {
  const HomeRecentMemoriesSection({super.key});

  @override
  State<HomeRecentMemoriesSection> createState() =>
      _HomeRecentMemoriesSectionState();
}

class _HomeRecentMemoriesSectionState extends State<HomeRecentMemoriesSection> {
  final _current = CurrentBabyController.instance;
  List<BabyMemory> _recent = const [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _current.addListener(_onBabyChanged);
    _reload();
  }

  @override
  void dispose() {
    _current.removeListener(_onBabyChanged);
    super.dispose();
  }

  void _onBabyChanged() {
    _reload();
  }

  Future<void> _reload() async {
    final babyId = _current.currentBabyId;
    if (babyId == null) {
      if (!mounted) return;
      setState(() {
        _recent = const [];
        _loading = false;
      });
      return;
    }
    if (mounted) setState(() => _loading = true);
    try {
      final all = await MemoryService(AppDatabase.instance).listForBaby(babyId);
      final withPhoto = all.where(_hasPhoto).take(4).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _recent = withPhoto;
        _loading = false;
      });
    } catch (e) {
      debugPrint('HomeRecentMemoriesSection._reload failed: $e');
      if (!mounted) return;
      setState(() {
        _recent = const [];
        _loading = false;
      });
    }
  }

  static bool _hasPhoto(BabyMemory m) {
    final b64 = m.photoB64?.trim();
    final url = m.photoUrl?.trim();
    return (b64 != null && b64.isNotEmpty) || (url != null && url.isNotEmpty);
  }

  void _openMemoriesTab() {
    ShellNestedNav.tabNavigatorKeys[2].currentState
        ?.popUntil((route) => route.isFirst);
    ShellNestedNav.selectTab?.call(2);
  }

  @override
  Widget build(BuildContext context) {
    if (!_loading && _recent.isEmpty) return const SizedBox.shrink();

    final s = S.of(context);
    final thumbSize = portalSp(context, 92).clamp(80.0, 104.0);
    final radius = portalSp(context, 20).clamp(16.0, 24.0);
    final night = PortalTimeOfDay.isNight(DateTime.now());
    final headingColor =
        night ? PortalTimeOfDay.nightOutlinedTextColor : AppTheme.textSecondary;
    final seeAllColor = night
        ? PortalTimeOfDay.nightOutlinedTextColor
        : const Color(0xFF5B6B8C);
    final nightShadows = night ? PortalTimeOfDay.nightTextOutlineShadows : null;

    return Padding(
      padding: const EdgeInsets.only(top: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  s.homeRecentMemoriesTitle,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: portalSp(context, 18),
                    color: headingColor,
                    shadows: nightShadows,
                    height: 1.2,
                  ),
                ),
              ),
              TextButton(
                onPressed: _openMemoriesTab,
                style: TextButton.styleFrom(
                  foregroundColor: seeAllColor,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Text(
                  s.reportMonthlySeeAllMemories,
                  style: TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: portalSp(context, 14),
                    shadows: nightShadows,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: portalSp(context, 10)),
          if (_loading)
            SizedBox(
              height: thumbSize,
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            SizedBox(
              height: thumbSize,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _recent.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) {
                  return _HomeMemoryThumb(
                    memory: _recent[i],
                    size: thumbSize,
                    radius: radius,
                    onTap: _openMemoriesTab,
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

class _HomeMemoryThumb extends StatelessWidget {
  const _HomeMemoryThumb({
    required this.memory,
    required this.size,
    required this.radius,
    required this.onTap,
  });

  final BabyMemory memory;
  final double size;
  final double radius;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final b64 = memory.photoB64?.trim();
    final url = memory.photoUrl?.trim();
    final bytes = decodePhotoB64(b64);

    Widget img;
    if (bytes != null) {
      img = Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (url != null && url.isNotEmpty) {
      img = CachedMemoryPhoto(
        imageUrl: url,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
        placeholder: (_, __) => const ColoredBox(
          color: Color(0xFFEDE7F6),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (_, __, ___) => const ColoredBox(
          color: Color(0xFFEDE7F6),
          child: Icon(Icons.image_rounded, color: Color(0xFF8E7CC3)),
        ),
      );
    } else {
      img = const ColoredBox(
        color: Color(0xFFEDE7F6),
        child: Icon(Icons.image_rounded, color: Color(0xFF8E7CC3)),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(radius),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(radius),
          child: SizedBox(width: size, height: size, child: img),
        ),
      ),
    );
  }
}
