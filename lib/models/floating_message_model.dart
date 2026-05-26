import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/floating_message_action.dart';

/// Tipos de mensagem no balão flutuante.
enum FloatingMessageType {
  adminAd('admin_ad'),
  adminNotice('admin_notice'),
  promoBanner('promo_banner'),
  aiTip('ai_tip'),
  aiSummary('ai_summary'),
  aiAlert('ai_alert'),
  premiumOffer('premium_offer');

  const FloatingMessageType(this.firestoreValue);
  final String firestoreValue;

  static FloatingMessageType? fromFirestore(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    for (final t in FloatingMessageType.values) {
      if (t.firestoreValue == v) return t;
    }
    return null;
  }

  bool get isAi =>
      this == aiTip || this == aiSummary || this == aiAlert;

  bool get isAdmin =>
      this == adminAd || this == adminNotice || this == promoBanner;

  String get collapsedEmoji => switch (this) {
        adminAd || adminNotice || promoBanner => '📣',
        aiTip || aiSummary || aiAlert => '🤖',
        premiumOffer => '❤️',
      };
}

/// Como o usuário pode fechar o balão.
enum FloatingMessageDismissMode {
  closeButton('close_button'),
  dragToDismiss('drag_to_dismiss'),
  both('both');

  const FloatingMessageDismissMode(this.firestoreValue);
  final String firestoreValue;

  static FloatingMessageDismissMode fromFirestore(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    for (final m in FloatingMessageDismissMode.values) {
      if (m.firestoreValue == v) return m;
    }
    return FloatingMessageDismissMode.both;
  }

  bool get allowsCloseButton =>
      this == closeButton || this == both;

  bool get allowsDragDismiss =>
      this == dragToDismiss || this == both;
}

/// Mensagem global `floating_messages/{id}`.
class FloatingMessage {
  const FloatingMessage({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    this.icon,
    this.actionLabel,
    this.actionRoute,
    this.actionUrl,
    this.imageUrl,
    this.imageAlt,
    this.imageAspectRatio,
    this.priority = 0,
    this.active = true,
    this.startsAt,
    this.endsAt,
    this.targetAudience = 'all',
    this.dismissMode = FloatingMessageDismissMode.both,
    this.createdAt,
    this.updatedAt,
    this.critical = false,
  });

  final String id;
  final String title;
  final String message;
  final FloatingMessageType type;
  final String? icon;
  final String? actionLabel;
  final String? actionRoute;
  final String? actionUrl;
  final String? imageUrl;
  final String? imageAlt;
  final double? imageAspectRatio;
  final int priority;
  final bool active;
  final DateTime? startsAt;
  final DateTime? endsAt;
  final String targetAudience;
  final FloatingMessageDismissMode dismissMode;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  /// Se true, pode reaparecer após dismiss (alertas críticos).
  final bool critical;

  String get displayIcon => (icon?.trim().isNotEmpty ?? false)
      ? icon!.trim()
      : type.collapsedEmoji;

  bool get hasHttpsActionUrl => FloatingMessageAction.isValidHttpsUrl(actionUrl);

  bool get hasInternalRoute {
    final r = actionRoute?.trim() ?? '';
    return r.startsWith('/');
  }

  /// CTA só com rótulo e destino válido (https tem prioridade sobre rota).
  bool get hasActionButton {
    final label = actionLabel?.trim() ?? '';
    if (label.isEmpty) return false;
    return hasHttpsActionUrl || hasInternalRoute;
  }

  /// URL externa efetiva (somente https).
  String? get effectiveActionUrl => hasHttpsActionUrl ? actionUrl!.trim() : null;

  /// Rota interna só se não houver URL https válida.
  String? get effectiveActionRoute {
    if (hasHttpsActionUrl) return null;
    return hasInternalRoute ? actionRoute!.trim() : null;
  }

  bool get hasRenderableContent =>
      message.trim().isNotEmpty || (imageUrl?.trim().isNotEmpty ?? false);

  bool get isBannerLayout =>
      type == FloatingMessageType.promoBanner &&
      (imageUrl?.trim().isNotEmpty ?? false);

  /// Card promocional grande (admin com imagem ou promo_banner).
  bool get isPromoLayout =>
      isBannerLayout ||
      (type == FloatingMessageType.adminAd &&
          (imageUrl?.trim().isNotEmpty ?? false));

  factory FloatingMessage.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final d = doc.data() ?? {};
    final type = FloatingMessageType.fromFirestore('${d['type'] ?? ''}') ??
        FloatingMessageType.adminNotice;
    final aspect = d['imageAspectRatio'];
    return FloatingMessage(
      id: doc.id,
      title: '${d['title'] ?? ''}'.trim(),
      message: '${d['message'] ?? d['text'] ?? ''}'.trim(),
      type: type,
      icon: _optString(d['icon']),
      actionLabel: _optString(d['actionLabel'] ?? d['actionButtonLabel']),
      actionRoute: _optString(d['actionRoute']),
      actionUrl: _optString(d['actionUrl']),
      imageUrl: _optString(d['imageUrl']),
      imageAlt: _optString(d['imageAlt']),
      imageAspectRatio: aspect is num ? aspect.toDouble() : null,
      priority: (d['priority'] as num?)?.toInt() ?? 0,
      active: d['active'] == true,
      startsAt: _ts(d['startsAt']),
      endsAt: _ts(d['endsAt']),
      targetAudience: '${d['targetAudience'] ?? 'all'}'.trim().isEmpty
          ? 'all'
          : '${d['targetAudience']}'.trim(),
      dismissMode: FloatingMessageDismissMode.fromFirestore(
        '${d['dismissMode'] ?? ''}',
      ),
      createdAt: _ts(d['createdAt']),
      updatedAt: _ts(d['updatedAt']),
      critical: d['critical'] == true,
    );
  }

  /// Legado: `users/{uid}/inbox_broadcasts`.
  factory FloatingMessage.fromInboxBroadcast({
    required String campaignId,
    required String text,
    String? imageUrl,
    String? actionUrl,
    String? actionButtonLabel,
  }) {
    return FloatingMessage(
      id: campaignId,
      title: '',
      message: text,
      type: FloatingMessageType.adminAd,
      imageUrl: imageUrl,
      actionUrl: actionUrl,
      actionLabel: actionButtonLabel,
      priority: 50,
      dismissMode: FloatingMessageDismissMode.both,
    );
  }

  static String? _optString(Object? v) {
    final s = '${v ?? ''}'.trim();
    return s.isEmpty ? null : s;
  }

  static DateTime? _ts(Object? v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    return null;
  }
}

/// Estado por usuário `floating_message_reads/{uid}/messages/{id}`.
class FloatingMessageReadState {
  const FloatingMessageReadState({
    this.seenAt,
    this.dismissedAt,
    this.clickedAt,
  });

  final DateTime? seenAt;
  final DateTime? dismissedAt;
  final DateTime? clickedAt;

  bool get isDismissed => dismissedAt != null;

  factory FloatingMessageReadState.fromMap(Map<String, dynamic>? d) {
    if (d == null) return const FloatingMessageReadState();
    return FloatingMessageReadState(
      seenAt: FloatingMessage._ts(d['seenAt']),
      dismissedAt: FloatingMessage._ts(d['dismissedAt']),
      clickedAt: FloatingMessage._ts(d['clickedAt']),
    );
  }
}
