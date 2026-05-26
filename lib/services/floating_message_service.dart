import 'dart:async';

import 'package:flutter/foundation.dart';

import '../controllers/current_baby_controller.dart';
import '../models/floating_message_model.dart';
import '../repositories/floating_message_repository.dart';
import 'premium/premium_service.dart';

/// Contexto do utilizador para `targetAudience`.
class FloatingMessageUserContext {
  const FloatingMessageUserContext({
    this.isPremium = false,
    this.youngestBabyAgeMonths,
    this.aiActive = false,
  });

  final bool isPremium;
  final int? youngestBabyAgeMonths;
  final bool aiActive;

  static Future<FloatingMessageUserContext> load() async {
    final premium = PremiumService.instance.isPremium;
    int? months;
    final row = CurrentBabyController.instance.currentBabyRow;
    final birthRaw = row?['birth_date'] as String?;
    if (birthRaw != null && birthRaw.trim().isNotEmpty) {
      final birth = DateTime.tryParse(birthRaw.trim());
      if (birth != null) {
        months = (DateTime.now().difference(birth).inDays / 30.44).floor();
      }
    }
    return FloatingMessageUserContext(
      isPremium: premium,
      youngestBabyAgeMonths: months,
      aiActive: true,
    );
  }
}

/// Seleciona uma mensagem ativa para o balão (sem OpenAI).
class FloatingMessageService {
  FloatingMessageService._();
  static final FloatingMessageService instance = FloatingMessageService._();

  final FloatingMessageRepository _repo = FloatingMessageRepository();

  final Set<String> _sessionDismissed = {};
  FloatingMessage? _cached;
  DateTime? _cacheAt;
  static const _cacheTtl = Duration(seconds: 45);

  StreamSubscription<List<FloatingMessage>>? _messagesSub;
  final _controller = StreamController<FloatingMessage?>.broadcast();

  Stream<FloatingMessage?> watchBestMessage() {
    _ensureWatching();
    return _controller.stream;
  }

  void _ensureWatching() {
    if (_messagesSub != null) return;
    _messagesSub = _repo.watchActiveMessages(limit: 5).listen((_) {
      unawaited(_refresh());
    });
    unawaited(_refresh());
  }

  void dispose() {
    _messagesSub?.cancel();
    _messagesSub = null;
    _controller.close();
  }

  Future<void> _refresh() async {
    final picked = await pickBestMessage();
    _cached = picked;
    _cacheAt = DateTime.now();
    if (!_controller.isClosed) _controller.add(picked);
  }

  Future<FloatingMessage?> pickBestMessage({bool forceRefresh = false}) async {
    if (!forceRefresh &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl &&
        (_cached != null || _sessionDismissed.isNotEmpty)) {
      return _cached;
    }

    final now = DateTime.now();
    final ctx = await FloatingMessageUserContext.load();

    final global = await _repo.fetchActiveMessages(limit: 5);
    List<FloatingMessage> legacy = const [];
    try {
      legacy = await _repo.fetchLegacyInbox();
    } catch (e) {
      debugPrint('FloatingMessageService legacy inbox: $e');
    }

    final candidates = <FloatingMessage>[...global, ...legacy];
    if (candidates.isEmpty) {
      _cached = null;
      _cacheAt = DateTime.now();
      return null;
    }

    final ids = candidates.map((c) => c.id).toList();
    final reads = await _repo.readStatesFor(ids);

    FloatingMessage? best;
    for (final msg in candidates) {
      if (!msg.active && global.any((g) => g.id == msg.id)) continue;
      if (!_isInSchedule(msg, now)) continue;
      if (!_matchesAudience(msg.targetAudience, ctx)) continue;

      final read = reads[msg.id];
      if (read?.isDismissed == true && !msg.critical) continue;
      if (_sessionDismissed.contains(msg.id) && !msg.critical) continue;

      if (best == null) {
        best = msg;
        continue;
      }
      if (msg.priority > best.priority) {
        best = msg;
        continue;
      }
      if (msg.priority == best.priority) {
        final mc = msg.createdAt;
        final bc = best.createdAt;
        if (mc != null && bc != null && mc.isAfter(bc)) best = msg;
      }
    }

    _cached = best;
    _cacheAt = DateTime.now();
    return best;
  }

  bool _isInSchedule(FloatingMessage msg, DateTime now) {
    if (msg.startsAt != null && now.isBefore(msg.startsAt!)) return false;
    if (msg.endsAt != null && now.isAfter(msg.endsAt!)) return false;
    return true;
  }

  bool _matchesAudience(String raw, FloatingMessageUserContext ctx) {
    final key = raw.trim().toLowerCase();
    if (key.isEmpty || key == 'all') return true;
    switch (key) {
      case 'free_users':
        return !ctx.isPremium;
      case 'premium_users':
      case 'plus_users':
        return ctx.isPremium;
      case 'no_subscription':
        return !ctx.isPremium;
      case 'baby_under_6m':
      case 'baby_under_6_months':
        final m = ctx.youngestBabyAgeMonths;
        return m != null && m <= 6;
      case 'baby_over_6m':
      case 'baby_over_6_months':
        final m = ctx.youngestBabyAgeMonths;
        return m != null && m > 6;
      case 'ai_active':
        return ctx.aiActive;
      default:
        return true;
    }
  }

  Future<void> onMessageShown(FloatingMessage msg) async {
    await _repo.markSeen(msg.id);
  }

  Future<void> dismiss(FloatingMessage msg) async {
    _sessionDismissed.add(msg.id);
    await _repo.markDismissed(msg.id);
    if (msg.type == FloatingMessageType.adminAd &&
        msg.imageUrl != null &&
        msg.id.isNotEmpty) {
      await _repo.dismissLegacyInbox(msg.id);
    }
    _cached = null;
    await _refresh();
  }

  Future<void> onActionTapped(FloatingMessage msg) async {
    await _repo.markClicked(msg.id);
  }
}
