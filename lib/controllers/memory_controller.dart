import 'package:flutter/foundation.dart';
import '../models/baby_memory.dart';
import '../services/memory_service.dart';

class MemoryController extends ChangeNotifier {
  final MemoryService service;

  MemoryController({required this.service});

  int? _babyId;
  bool _loading = false;
  Object? _error;
  final Map<String, BabyMemory> _byBadge = {};

  bool get loading => _loading;
  Object? get error => _error;
  Map<String, BabyMemory> get byBadge => Map.unmodifiable(_byBadge);

  Future<void> loadForBaby(int? babyId) async {
    _babyId = babyId;
    _byBadge.clear();
    _error = null;
    if (babyId == null) {
      notifyListeners();
      return;
    }
    _loading = true;
    notifyListeners();
    try {
      final list = await service.listForBaby(babyId);
      for (final m in list) {
        _byBadge[m.badgeId] = m;
      }
    } catch (e) {
      _error = e;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> upsert(BabyMemory memory) async {
    final bid = _babyId ?? memory.babyId;
    await service.upsert(memory);
    await loadForBaby(bid);
  }

  Future<void> deleteByBadge(String badgeId) async {
    final bid = _babyId;
    if (bid == null) return;
    await service.deleteByBadge(babyId: bid, badgeId: badgeId);
    await loadForBaby(bid);
  }
}
