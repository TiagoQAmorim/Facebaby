import 'package:flutter/material.dart';
import '../../controllers/memory_controller.dart';
import '../../i18n/app_i18n.dart';
import '../../models/baby_memory.dart';
import '../../models/memory_badge.dart';
import '../../pages/memories/add_memory_page.dart';
import '../../pages/memories/memory_badges_catalog.dart';
import '../../pages/memories/memory_detail_carousel_page.dart';
import '../../pages/memories/memory_detail_page.dart';
import '../../pages/premium/premium_paywall_screen.dart';
import '../../services/premium/feature_access.dart';
import '../../utils/portal_page_route.dart';
import 'empty_memory_card.dart';
import 'filled_memory_card.dart';

bool _memoryHasPhoto(BabyMemory m) {
  final b64 = m.photoB64?.trim();
  if (b64 != null && b64.isNotEmpty) return true;
  final u = m.photoUrl?.trim();
  return u != null && u.isNotEmpty;
}

class _AddMemoryBadgeCard extends StatelessWidget {
  const _AddMemoryBadgeCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: const Color(0xFFEAFBFC),
            border: Border.all(color: const Color(0xFF00C4CC).withAlpha(75)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(230),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.add_rounded,
                  color: Color(0xFF00AAB2),
                  size: 30,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                S.of(context).memoryAddBadgeCta,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                  color: Color(0xFF167A80),
                  height: 1.15,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

bool _memoryHasContent(BabyMemory m) => FeatureAccess.memoryHasBody(m);

class MemoryGrid extends StatefulWidget {
  final List<MemoryBadge> badges;
  final MemoryController controller;
  final int babyId;
  final Map<String, Object?> babyRow;

  const MemoryGrid({
    super.key,
    required this.badges,
    required this.controller,
    required this.babyId,
    required this.babyRow,
  });

  @override
  State<MemoryGrid> createState() => _MemoryGridState();
}

class _MemoryGridState extends State<MemoryGrid>
    with SingleTickerProviderStateMixin {
  late final AnimationController _appear = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 520));

  @override
  void initState() {
    super.initState();
    _appear.forward();
  }

  @override
  void dispose() {
    _appear.dispose();
    super.dispose();
  }

  int _cols(double w) {
    if (w < 360) return 3;
    if (w < 600) return 3;
    if (w < 900) return 4;
    return 5;
  }

  double _spacing(double w) => (w < 360) ? 5 : 6;

  MemoryBadge _badgeForMemory(BabyMemory memory) {
    return MemoryBadgesCatalog.findBadgeById(memory.badgeId) ??
        MemoryBadgesCatalog.customFromMemory(
          id: memory.badgeId,
          title: memory.title,
        );
  }

  Future<void> _tryOpenAddMemory({
    required BuildContext context,
    required int babyId,
    required Map<String, Object?> babyRow,
    required MemoryController controller,
    required List<MemoryBadge> availableBadges,
    MemoryBadge? badge,
    BabyMemory? initialMemory,
  }) async {
    final badgeId = badge?.id ?? initialMemory?.badgeId;
    if (!FeatureAccess.canOpenNewMemoryMoment(
      controller: controller,
      badgeId: badgeId,
    )) {
      await showMemoryPremiumLimitDialog(context);
      return;
    }
    await _openAddMemory(
      context: context,
      babyId: babyId,
      babyRow: babyRow,
      controller: controller,
      availableBadges: availableBadges,
      badge: badge,
      initialMemory: initialMemory,
    );
  }

  Future<void> _openAddMemory({
    required BuildContext context,
    required int babyId,
    required Map<String, Object?> babyRow,
    required MemoryController controller,
    required List<MemoryBadge> availableBadges,
    MemoryBadge? badge,
    BabyMemory? initialMemory,
  }) async {
    await Navigator.of(context).push<bool>(
      portalPageRoute<bool>(
        builder: (_) => AddMemoryPage(
          babyId: babyId,
          badge: badge,
          controller: controller,
          availableBadges: availableBadges,
          initialMemory: initialMemory,
          babyBirthDate:
              DateTime.tryParse((babyRow['birth_date'] as String?) ?? ''),
          currentWeightKg: (babyRow['weight_kg'] as num?)?.toDouble(),
          currentHeightCm: (babyRow['height_cm'] as num?)?.toDouble(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final badges = widget.badges;
    final controller = widget.controller;
    final babyId = widget.babyId;
    final babyRow = widget.babyRow;

    final curved = CurvedAnimation(parent: _appear, curve: Curves.easeOutCubic);

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero)
            .animate(curved),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cols = _cols(w);
            final gap = _spacing(w);
            const ratio = 0.84;
            final usedBadgeIds = controller.byBadge.keys.toSet();
            final availableBadges =
                badges.where((b) => !usedBadgeIds.contains(b.id)).toList();
            final filled = controller.byBadge.values
                .where(_memoryHasContent)
                .toList()
              ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
            final emptyBadges = badges.where((b) {
              final memory = controller.byBadge[b.id];
              return memory == null || !_memoryHasContent(memory);
            }).toList();

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filled.length + emptyBadges.length + 1,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                childAspectRatio: ratio,
              ),
              itemBuilder: (context, i) {
                if (i == 0) {
                  return _AddMemoryBadgeCard(
                    onTap: () => _tryOpenAddMemory(
                      context: context,
                      babyId: babyId,
                      babyRow: babyRow,
                      controller: controller,
                      availableBadges: availableBadges,
                    ),
                  );
                }

                final filledIndex = i - 1;
                if (filledIndex >= filled.length) {
                  final badge = emptyBadges[filledIndex - filled.length];
                  return EmptyMemoryCard(
                    badge: badge,
                    onTap: () => _tryOpenAddMemory(
                      context: context,
                      babyId: babyId,
                      babyRow: babyRow,
                      controller: controller,
                      availableBadges: availableBadges,
                      badge: badge,
                      initialMemory: controller.byBadge[badge.id],
                    ),
                  );
                }

                final memory = filled[filledIndex];
                final badge = _badgeForMemory(memory);
                return FilledMemoryCard(
                  badge: badge,
                  memory: memory,
                  onTap: () {
                    if (_memoryHasPhoto(memory)) {
                      final carousel = <MemoryPhotoCarouselEntry>[];
                      for (final mm in filled) {
                        if (_memoryHasPhoto(mm)) {
                          carousel.add(
                            MemoryPhotoCarouselEntry(
                              badge: _badgeForMemory(mm),
                              memory: mm,
                            ),
                          );
                        }
                      }
                      if (carousel.isEmpty) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MemoryDetailPage(
                              badge: badge,
                              memory: memory,
                              heroTag: 'mem_${memory.badgeId}_$i',
                              controller: controller,
                            ),
                          ),
                        );
                        return;
                      }
                      final idx =
                          carousel.indexWhere((e) => e.memory.id == memory.id);
                      final initial = idx < 0 ? 0 : idx;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => MemoryDetailCarouselPage(
                            entries: carousel,
                            initialIndex: initial,
                            controller: controller,
                          ),
                        ),
                      );
                      return;
                    }
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MemoryDetailPage(
                          badge: badge,
                          memory: memory,
                          heroTag: 'mem_${memory.badgeId}_$i',
                          controller: controller,
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      ),
    );
  }
}
