import 'package:flutter/material.dart';
import '../../controllers/memory_controller.dart';
import '../../models/baby_memory.dart';
import '../../models/memory_badge.dart';
import '../../pages/memories/add_memory_page.dart';
import '../../pages/memories/memory_detail_carousel_page.dart';
import '../../pages/memories/memory_detail_page.dart';
import 'empty_memory_card.dart';
import 'filled_memory_card.dart';

bool _memoryHasPhoto(BabyMemory m) {
  final b64 = m.photoB64?.trim();
  if (b64 != null && b64.isNotEmpty) return true;
  final u = m.photoUrl?.trim();
  return u != null && u.isNotEmpty;
}

bool _memoryHasContent(BabyMemory m) {
  if (_memoryHasPhoto(m)) return true;
  return (m.description ?? '').trim().isNotEmpty;
}

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

class _MemoryGridState extends State<MemoryGrid> with SingleTickerProviderStateMixin {
  late final AnimationController _appear =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 520));

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
        position: Tween<Offset>(begin: const Offset(0, 0.035), end: Offset.zero).animate(curved),
        child: LayoutBuilder(
          builder: (context, c) {
            final w = c.maxWidth;
            final cols = _cols(w);
            final gap = _spacing(w);
            const ratio = 0.84;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: badges.length,
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: cols,
                mainAxisSpacing: gap,
                crossAxisSpacing: gap,
                childAspectRatio: ratio,
              ),
              itemBuilder: (context, i) {
                final badge = badges[i];
                final memory = controller.byBadge[badge.id];

                if (memory == null || !_memoryHasContent(memory)) {
                  return EmptyMemoryCard(
                    badge: badge,
                    onTap: () async {
                      final saved = await Navigator.of(context).push<bool>(
                        MaterialPageRoute(
                          builder: (_) => AddMemoryPage(
                            babyId: babyId,
                            badge: badge,
                            controller: controller,
                            babyBirthDate: DateTime.tryParse((babyRow['birth_date'] as String?) ?? ''),
                            currentWeightKg: (babyRow['weight_kg'] as num?)?.toDouble(),
                            currentHeightCm: (babyRow['height_cm'] as num?)?.toDouble(),
                          ),
                        ),
                      );
                      if (saved == true) {
                        // already refreshed by controller; no-op
                      }
                    },
                  );
                }

                return FilledMemoryCard(
                  badge: badge,
                  memory: memory,
                  onTap: () {
                    if (_memoryHasPhoto(memory)) {
                      final carousel = <MemoryPhotoCarouselEntry>[];
                      for (final b in badges) {
                        final mm = controller.byBadge[b.id];
                        if (mm != null && _memoryHasPhoto(mm)) {
                          carousel.add(MemoryPhotoCarouselEntry(badge: b, memory: mm));
                        }
                      }
                      if (carousel.isEmpty) {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => MemoryDetailPage(
                              badge: badge,
                              memory: memory,
                              heroTag: 'mem_${badge.id}_$i',
                              controller: controller,
                            ),
                          ),
                        );
                        return;
                      }
                      final idx = carousel.indexWhere((e) => e.badge.id == badge.id);
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
                          heroTag: 'mem_${badge.id}_$i',
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

