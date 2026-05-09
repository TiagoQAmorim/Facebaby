import 'package:flutter/material.dart';
import 'dart:typed_data';
import '../controllers/current_baby_controller.dart';
import '../i18n/app_i18n.dart';
import '../models/memory_item.dart';
import '../services/app_database.dart';
import '../services/mock_baby_service.dart';
import '../theme/app_theme.dart';
import '../utils/photo_b64.dart';
import '../utils/memory_photo_limits.dart';
import '../utils/pick_image_b64.dart';
import '../widgets/card_box.dart';
import '../widgets/section_title.dart';

class MemoriesPage extends StatefulWidget {
  const MemoriesPage({super.key});

  @override
  State<MemoriesPage> createState() => _MemoriesPageState();
}

class _MemoriesPageState extends State<MemoriesPage> with AutomaticKeepAliveClientMixin {
  final _currentBaby = CurrentBabyController.instance;
  final _mockBabyService = MockBabyService();
  Future<List<Map<String, Object?>>>? _listFuture;
  String? _askedDayKey;

  @override
  void initState() {
    super.initState();
    _currentBaby.addListener(_onBabyChanged);
    _reload();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskTodayPhoto());
  }

  @override
  void dispose() {
    _currentBaby.removeListener(_onBabyChanged);
    super.dispose();
  }

  @override
  bool get wantKeepAlive => true;

  int? get _babyId => _currentBaby.currentBabyId;

  String _dayKey(DateTime dt) {
    final d = DateTime(dt.year, dt.month, dt.day);
    return '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  }

  String _dayKeyToLabel(String key) {
    // Expected: YYYY-MM-DD
    final parts = key.split('-');
    if (parts.length != 3) return key;
    final y = parts[0];
    final m = parts[1];
    final d = parts[2];
    if (y.length != 4 || m.length != 2 || d.length != 2) return key;
    return '$d/$m/$y';
  }

  Widget _refBadgeCrop(int i) {
    // Uses the provided reference image as a "sprite sheet" to render example badges.
    // We crop different regions by shifting the alignment inside a ClipRect.
    // Alignment x/y are in [-1, 1].
    const asset = 'assets/memories/mural_badges_ref.png';
    final aligns = <Alignment>[
      const Alignment(-0.75, -0.72),
      const Alignment(0.05, -0.72),
      const Alignment(0.85, -0.72),
      const Alignment(-0.75, -0.10),
      const Alignment(0.05, -0.10),
      const Alignment(0.85, -0.10),
      const Alignment(-0.75, 0.62),
      const Alignment(0.05, 0.62),
      const Alignment(0.85, 0.62),
    ];
    final a = aligns[i % aligns.length];
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: ClipRect(
        child: Align(
          alignment: a,
          widthFactor: 0.32,
          heightFactor: 0.28,
          child: Image.asset(asset, fit: BoxFit.cover),
        ),
      ),
    );
  }

  Widget _exampleMuralBadges(BuildContext context) {
    final small = MediaQuery.of(context).size.width < 360;
    final count = small ? 2 : 3;
    // Titles inspired by your reference screen (kept short for small phones).
    const titles = [
      'Cheguei em casa!',
      'Primeiro sorriso',
      'Primeira Amamentação',
      'Dormindo',
      'Hora do banho',
      'Indo passear',
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: titles.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: count,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: small ? 0.86 : 0.78,
      ),
      itemBuilder: (context, idx) {
        return CardBox(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(child: _refBadgeCrop(idx)),
                    Positioned(
                      right: 8,
                      top: 8,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withAlpha(230),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: const Color(0xFFEEE6F6)),
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.add, size: 18, color: AppTheme.primary),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                titles[idx],
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 2),
              Text(
                'Exemplo',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.black.withAlpha(140), fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  void _onBabyChanged() {
    _askedDayKey = null;
    _reload();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAskTodayPhoto());
  }

  void _reload() {
    final bid = _babyId;
    _listFuture = bid == null ? Future.value(const []) : AppDatabase.instance.listDailyMemories(babyId: bid);
    if (mounted) setState(() {});
  }

  Future<void> _addTodayPhoto() async {
    final bid = _babyId;
    if (bid == null) return;

    final existing = await AppDatabase.instance.getDailyMemory(babyId: bid, day: DateTime.now());
    if (!mounted) return;
    final hasPhoto = (existing?['photo_b64'] as String?)?.trim().isNotEmpty == true;
    if (hasPhoto) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).memoriesAlreadyPostedToday)),
        );
      }
      return;
    }

    final b64 = await pickImageAsB64(context: context, maxBytes: memoryPhotoPickMaxBytes());
    if (b64 == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).memoriesPhotoError)),
        );
      }
      return;
    }
    try {
      await AppDatabase.instance.upsertDailyMemoryPhoto(babyId: bid, photoB64: b64);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${S.of(context).commonCouldNotSave} $e')),
        );
      }
      return;
    }
    _reload();
  }

  void _openMuralPhoto({required String day, required Uint8List bytes}) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return Dialog(
          insetPadding: const EdgeInsets.all(12),
          backgroundColor: Colors.black,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(
              children: [
                Positioned.fill(
                  child: InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  right: 8,
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        icon: const Icon(Icons.close, color: Colors.white),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          day,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _maybeAskTodayPhoto() async {
    final bid = _babyId;
    if (bid == null || !mounted) return;
    final key = _dayKey(DateTime.now());
    if (_askedDayKey == key) return;
    _askedDayKey = key;

    final existing = await AppDatabase.instance.getDailyMemory(babyId: bid, day: DateTime.now());
    final hasPhoto = (existing?['photo_b64'] as String?)?.trim().isNotEmpty == true;
    if (hasPhoto || !mounted) return;

    // If the latest mural update is already today, don't ask again.
    final latest = await AppDatabase.instance.listDailyMemories(babyId: bid, limit: 1);
    final latestKey = (latest.isNotEmpty ? (latest.first['day_key'] as String?) : null)?.trim();
    if (latestKey == key || !mounted) return;

    final shouldAdd = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final d = S.of(ctx);
        return AlertDialog(
          title: Text(d.memoriesTodayTitle),
          content: Text(d.memoriesTodayAsk),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(d.memoriesNotYet)),
            FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(d.memoriesAddPhotoDialog)),
          ],
        );
      },
    );

    if (shouldAdd == true && mounted) {
      await _addTodayPhoto();
    }
  }

  void _showHighlightDetail(MemoryItem item) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(item.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.date, style: TextStyle(color: Colors.black.withAlpha(140), fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Text(item.description),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.of(ctx).pop(), child: Text(S.of(ctx).commonClose))],
      ),
    );
  }

  List<MemoryItem> _highlightItems(S s) {
    return s.lang == AppLang.en ? _mockBabyService.getMemoriesEn() : _mockBabyService.getMemories();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final s = S.of(context);
    final highlights = _highlightItems(s);
    final todayKey = _dayKey(DateTime.now());
    return Stack(
      children: [
        SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.memoriesTitle, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 8),
              Text(s.memoriesSubtitle),
              const SizedBox(height: 20),
              const SizedBox(height: 22),
              SectionTitle(title: s.memoriesHighlights),
              const SizedBox(height: 12),
              Row(
                children: [
                  for (var i = 0; i < highlights.length; i++) ...[
                    Expanded(
                      child: _MemoryHighlightButton(
                        item: highlights[i],
                        onTap: () => _showHighlightDetail(highlights[i]),
                      ),
                    ),
                    if (i < highlights.length - 1) const SizedBox(width: 10),
                  ],
                ],
              ),
              const SizedBox(height: 26),
              FutureBuilder<List<Map<String, Object?>>>(
                future: _listFuture,
                builder: (context, snap) {
                  return SectionTitle(title: s.memoriesWallSection);
                },
              ),
              const SizedBox(height: 12),
              FutureBuilder<List<Map<String, Object?>>>(
                future: _listFuture,
                builder: (context, snapshot) {
                  final rows = snapshot.data ?? const [];
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (rows.isEmpty) {
                    // Show reference-style example badges when there are no photos yet,
                    // so layout matches the desired UI even before user adds the first photo.
                    return _exampleMuralBadges(context);
                  }

                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: rows.length,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: MediaQuery.of(context).size.width < 360 ? 2 : 3,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      // Badge-like tiles: more height for text on small screens.
                      childAspectRatio: MediaQuery.of(context).size.width < 360 ? 0.86 : 0.78,
                    ),
                    itemBuilder: (context, idx) {
                      final r = rows[idx];
                      final day = (r['day_key'] as String?) ?? '—';
                      final b64 = r['photo_b64'] as String?;
                      final bytes = decodePhotoB64(b64);
                      final dayLabel = _dayKeyToLabel(day);
                      return InkWell(
                        borderRadius: BorderRadius.circular(20),
                        onTap: bytes == null ? null : () => _openMuralPhoto(day: day, bytes: bytes),
                        child: CardBox(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Stack(
                                  children: [
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(16),
                                        child: bytes == null
                                            ? Container(
                                                color: const Color(0xFFF8F3FF),
                                                alignment: Alignment.center,
                                                child: const Icon(Icons.broken_image_outlined),
                                              )
                                            : Image.memory(bytes, fit: BoxFit.cover, width: double.infinity),
                                      ),
                                    ),
                                    Positioned(
                                      right: 8,
                                      top: 8,
                                      child: Container(
                                        width: 28,
                                        height: 28,
                                        decoration: BoxDecoration(
                                          color: Colors.white.withAlpha(230),
                                          borderRadius: BorderRadius.circular(999),
                                          border: Border.all(color: const Color(0xFFEEE6F6)),
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text('📸', style: TextStyle(fontSize: 14)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Foto do dia',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontWeight: FontWeight.w900),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                dayLabel,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: Colors.black.withAlpha(140), fontWeight: FontWeight.w700, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: SafeArea(
            top: false,
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: _listFuture,
              builder: (context, snap) {
                final rows = snap.data ?? const [];
                final alreadyToday = rows.any((r) => ((r['day_key'] as String?) ?? '').trim() == todayKey);
                return Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: alreadyToday ? null : _addTodayPhoto,
                    borderRadius: BorderRadius.circular(999),
                    child: AnimatedOpacity(
                      opacity: alreadyToday ? 0.45 : 1.0,
                      duration: const Duration(milliseconds: 160),
                      child: Container(
                        width: 54,
                        height: 54,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFEEE6F6)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withAlpha(18), blurRadius: 10, offset: const Offset(0, 4)),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: const Icon(Icons.add_rounded, size: 30, color: AppTheme.primary),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

class _MemoryHighlightButton extends StatelessWidget {
  final MemoryItem item;
  final VoidCallback onTap;

  const _MemoryHighlightButton({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: CardBox(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(item.emoji, style: const TextStyle(fontSize: 26)),
              const SizedBox(height: 8),
              Text(
                item.title,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, height: 1.15, color: AppTheme.textPrimary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
