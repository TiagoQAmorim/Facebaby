import 'dart:async';

import 'package:flutter/foundation.dart';

import '../controllers/current_baby_controller.dart';
import '../models/floating_message_model.dart';
import '../repositories/floating_message_repository.dart';
import 'admin_broadcast_inbox_service.dart';
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

/// Seleciona mensagens ativas para o balão (sem OpenAI).
class FloatingMessageService {
  FloatingMessageService._();
  static final FloatingMessageService instance = FloatingMessageService._();

  final FloatingMessageRepository _repo = FloatingMessageRepository();

  final Set<String> _sessionDismissed = {};
  FloatingMessage? _cached;
  List<FloatingMessage> _cachedList = const [];
  DateTime? _cacheAt;
  static const _cacheTtl = Duration(seconds: 45);

  StreamSubscription<List<FloatingMessage>>? _messagesSub;
  StreamSubscription<List<AdminBroadcastInboxItem>>? _inboxSub;
  final _controller = StreamController<FloatingMessage?>.broadcast();
  final _listController = StreamController<List<FloatingMessage>>.broadcast();

  Stream<FloatingMessage?> watchBestMessage() {
    _ensureWatching();
    return Stream.multi((multi) {
      multi.add(_cached);
      final sub = _controller.stream.listen(
        multi.add,
        onError: multi.addError,
        onDone: multi.close,
      );
      multi.onCancel = sub.cancel;
    });
  }

  /// Todas as mensagens ativas ordenadas por prioridade (para navegação).
  Stream<List<FloatingMessage>> watchActiveMessageList() {
    _ensureWatching();
    return Stream.multi((multi) {
      multi.add(_cachedList);
      final sub = _listController.stream.listen(
        multi.add,
        onError: multi.addError,
        onDone: multi.close,
      );
      multi.onCancel = sub.cancel;
    });
  }

  void _ensureWatching() {
    if (_messagesSub != null) return;
    _messagesSub = _repo.watchActiveMessages(limit: 20).listen((_) {
      unawaited(_refresh(force: true));
    });
    _inboxSub = AdminBroadcastInboxService.instance.watchActive().listen((_) {
      unawaited(_refresh(force: true));
    });
    unawaited(_refresh(force: true));
  }

  void dispose() {
    _messagesSub?.cancel();
    _messagesSub = null;
    _inboxSub?.cancel();
    _inboxSub = null;
    _controller.close();
    _listController.close();
  }

  Future<void> _refresh({bool force = false}) async {
    final prevId = _cached?.id;
    final list = await listActiveMessages(forceRefresh: force);
    if (!_controller.isClosed) {
      final picked = list.isEmpty ? null : list.first;
      if (force || picked?.id != prevId) {
        _controller.add(picked);
      }
    }
    if (!_listController.isClosed) {
      _listController.add(list);
    }
  }

  Future<List<FloatingMessage>> listActiveMessages({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh &&
        _cacheAt != null &&
        DateTime.now().difference(_cacheAt!) < _cacheTtl &&
        _cachedList.isNotEmpty) {
      return _cachedList;
    }

    final now = DateTime.now();
    final ctx = await FloatingMessageUserContext.load();
    final resetBefore = await _repo.fetchResetBefore();

    final global = await _repo.fetchActiveMessages(limit: 20);
    List<FloatingMessage> legacy = const [];
    try {
      legacy = await _repo.fetchLegacyInbox();
    } catch (e) {
      debugPrint('FloatingMessageService legacy inbox: $e');
    }

    final seenIds = <String>{};
    final candidates = <FloatingMessage>[];
    for (final m in [...global, ...legacy]) {
      if (seenIds.add(m.id)) candidates.add(m);
    }
    if (candidates.isEmpty) {
      _cached = null;
      _cachedList = const [];
      _cacheAt = DateTime.now();
      return _cachedList;
    }

    final ids = candidates.map((c) => c.id).toList();
    final reads = await _repo.readStatesFor(ids);

    final active = <FloatingMessage>[];
    for (final msg in candidates) {
      if (!msg.active && global.any((g) => g.id == msg.id)) continue;
      if (resetBefore != null &&
          msg.createdAt != null &&
          msg.createdAt!.isBefore(resetBefore)) {
        continue;
      }
      if (!_isInSchedule(msg, now)) continue;
      if (!_matchesAudience(msg.targetAudience, ctx)) continue;

      final read = reads[msg.id];
      if (read?.isDismissed == true && !msg.critical) continue;
      if (_sessionDismissed.contains(msg.id) && !msg.critical) continue;

      active.add(msg);
    }

    active.sort((a, b) {
      final p = b.priority.compareTo(a.priority);
      if (p != 0) return p;
      final ac = a.createdAt;
      final bc = b.createdAt;
      if (ac != null && bc != null) return bc.compareTo(ac);
      return b.id.compareTo(a.id);
    });

    _cachedList = active;
    _cached = active.isEmpty ? null : active.first;
    _cacheAt = DateTime.now();
    return _cachedList;
  }

  Future<FloatingMessage?> pickBestMessage({bool forceRefresh = false}) async {
    final list = await listActiveMessages(forceRefresh: forceRefresh);
    return list.isEmpty ? null : list.first;
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
    _cacheAt = null;
    await _refresh(force: true);
  }

  /// Fecha todas as mensagens ativas da fila (drag-to-dismiss em lote).
  Future<void> dismissAll(Iterable<FloatingMessage> messages) async {
    final list = messages.toList();
    if (list.isEmpty) return;
    for (final msg in list) {
      _sessionDismissed.add(msg.id);
      await _repo.markDismissed(msg.id);
      if (msg.type == FloatingMessageType.adminAd &&
          msg.imageUrl != null &&
          msg.id.isNotEmpty) {
        await _repo.dismissLegacyInbox(msg.id);
      }
    }
    _cacheAt = null;
    await _refresh(force: true);
  }

  Future<void> onActionTapped(FloatingMessage msg) async {
    await _repo.markClicked(msg.id);
  }
}
