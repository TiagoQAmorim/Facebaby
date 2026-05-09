import 'package:flutter/material.dart';

import '../../controllers/memory_controller.dart';
import '../../models/baby_memory.dart';
import '../../models/memory_badge.dart';
import 'memory_detail_page.dart';

/// Memória com foto + badge, na ordem do catálogo (para deslizar entre momentos com imagem).
class MemoryPhotoCarouselEntry {
  final MemoryBadge badge;
  final BabyMemory memory;

  const MemoryPhotoCarouselEntry({required this.badge, required this.memory});
}

/// Navegação horizontal entre memórias que têm foto (deslizar esquerda/direita).
class MemoryDetailCarouselPage extends StatefulWidget {
  final List<MemoryPhotoCarouselEntry> entries;
  final int initialIndex;
  final MemoryController controller;

  const MemoryDetailCarouselPage({
    super.key,
    required this.entries,
    required this.initialIndex,
    required this.controller,
  });

  @override
  State<MemoryDetailCarouselPage> createState() => _MemoryDetailCarouselPageState();
}

class _MemoryDetailCarouselPageState extends State<MemoryDetailCarouselPage> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
    final n = widget.entries.length;
    final start = n == 0 ? 0 : widget.initialIndex.clamp(0, n - 1);
    _pageController = PageController(initialPage: start);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final entries = widget.entries;
    if (entries.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('Nenhuma memória com foto.')),
      );
    }
    return PageView.builder(
      controller: _pageController,
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final e = entries[index];
        return MemoryDetailPage(
          badge: e.badge,
          memory: e.memory,
          heroTag: 'carousel_${e.badge.id}_$index',
          controller: widget.controller,
        );
      },
    );
  }
}
