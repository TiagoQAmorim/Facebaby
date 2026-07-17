import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';

/// Eventos de conversão Firebase Analytics (Google Ads).
///
/// Todas as chamadas são à prova de falhas: erros de analytics nunca quebram
/// o fluxo principal do app.
class AnalyticsService {
  AnalyticsService._();
  static final AnalyticsService instance = AnalyticsService._();

  static const _logPrefix = 'FaceBaby Analytics';

  FirebaseAnalytics get _analytics => FirebaseAnalytics.instance;

  /// Chaves já enviadas como `purchase` nesta sessão (evita duplicata do listener).
  final Set<String> _loggedPurchaseKeys = <String>{};

  /// Chaves já enviadas como `premium_restored` nesta sessão.
  final Set<String> _loggedRestoreKeys = <String>{};

  /// `flutter_test` / `package:test` regista `#test.declarer` na Zone.
  bool get _isAutomatedTest => Zone.current[#test.declarer] != null;

  bool get _enabled => !_isAutomatedTest;

  void _debug(String message) => debugPrint('[$_logPrefix] $message');

  Future<void> _safe(String eventName, Future<void> Function() action) async {
    if (!_enabled) {
      _debug('skip event=$eventName reason=automated_test');
      return;
    }
    try {
      await action();
      _debug('logged event=$eventName');
    } catch (e, st) {
      _debug('failed event=$eventName error=$e');
      developer.log(
        'Analytics event failed: $eventName',
        name: _logPrefix,
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Cadastro concluído (`sign_up`). Métodos: `email`, `google`, `apple`.
  Future<void> logSignUp({required String signUpMethod}) async {
    final method = signUpMethod.trim().toLowerCase();
    debugPrint('[FaceBaby Analytics] >>> sign_up');
    debugPrint('[FaceBaby Analytics] >>> sign_up method=$method');
    if (!_enabled) {
      debugPrint(
        '[FaceBaby Analytics] >>> sign_up SKIPPED reason=automated_test',
      );
      return;
    }
    try {
      await _analytics.logSignUp(signUpMethod: method);
      debugPrint('[FaceBaby Analytics] >>> sign_up OK');
      _debug('sign_up method=$method');
    } catch (e, s) {
      debugPrint('[FaceBaby Analytics] sign_up ERROR: $e');
      debugPrintStack(stackTrace: s);
    }
  }

  /// Perfil de bebê criado com sucesso (`baby_profile_created`).
  Future<void> logBabyProfileCreated({required bool isFirstBaby}) {
    return _safe('baby_profile_created', () async {
      await _analytics.logEvent(
        name: 'baby_profile_created',
        parameters: {
          'is_first_baby': isFirstBaby,
        },
      );
      _debug('baby_profile_created is_first_baby=$isFirstBaby');
    });
  }

  /// Início do checkout Premium (`begin_checkout`).
  ///
  /// [value] e preço do item vêm de [ProductDetails] da loja.
  Future<void> logBeginCheckout({
    required ProductDetails product,
    required String itemName,
  }) {
    final value = _productValue(product);
    final name = itemName.trim().isEmpty ? product.title : itemName.trim();
    return _safe('begin_checkout', () async {
      await _analytics.logBeginCheckout(
        value: value,
        currency: 'BRL',
        items: [
          AnalyticsEventItem(
            itemId: product.id,
            itemName: name,
            price: value,
            quantity: 1,
          ),
        ],
      );
      _debug(
        'begin_checkout product=${product.id} value=$value currency=BRL',
      );
    });
  }

  /// Assinatura Premium confirmada pela loja (`purchase`).
  ///
  /// Não usar para restauração. Deduplica por [transactionId]/purchaseID.
  Future<void> logPremiumPurchase({
    required PurchaseDetails purchase,
    required ProductDetails? product,
    required String itemName,
  }) {
    final txId = _transactionId(purchase);
    final dedupeKey = txId.isNotEmpty
        ? 'purchase_$txId'
        : 'purchase_${purchase.productID}_${purchase.transactionDate ?? ''}';
    if (!_loggedPurchaseKeys.add(dedupeKey)) {
      _debug('skip purchase reason=duplicate key=$dedupeKey');
      return Future<void>.value();
    }

    final value = product != null ? _productValue(product) : null;
    final name = itemName.trim().isEmpty
        ? (product?.title ?? purchase.productID)
        : itemName.trim();

    return _safe('purchase', () async {
      await _analytics.logPurchase(
        currency: 'BRL',
        value: value,
        transactionId: txId.isEmpty ? null : txId,
        items: [
          AnalyticsEventItem(
            itemId: purchase.productID,
            itemName: name,
            price: value,
            quantity: 1,
          ),
        ],
      );
      _debug(
        'purchase product=${purchase.productID} value=$value '
        'transactionId=${txId.isEmpty ? '(none)' : txId}',
      );
    });
  }

  /// Restauração de compra concluída (`premium_restored`) — nunca como `purchase`.
  Future<void> logPremiumRestored({required String productId}) {
    final id = productId.trim();
    if (id.isEmpty) {
      _debug('skip premium_restored reason=empty_product_id');
      return Future<void>.value();
    }
    final dedupeKey = 'restore_$id';
    if (!_loggedRestoreKeys.add(dedupeKey)) {
      _debug('skip premium_restored reason=duplicate product=$id');
      return Future<void>.value();
    }
    return _safe('premium_restored', () async {
      await _analytics.logEvent(
        name: 'premium_restored',
        parameters: {
          'product_id': id,
        },
      );
      _debug('premium_restored product_id=$id');
    });
  }

  static double? _productValue(ProductDetails product) {
    if (product.rawPrice > 0) return product.rawPrice;
    final text = product.price.trim();
    if (text.isEmpty) return null;
    final cleaned = text.replaceAll(RegExp(r'[^\d.,]'), '');
    if (cleaned.isEmpty) return null;
    if (cleaned.contains(',') && cleaned.contains('.')) {
      return double.tryParse(cleaned.replaceAll('.', '').replaceAll(',', '.'));
    }
    if (cleaned.contains(',')) {
      return double.tryParse(cleaned.replaceAll(',', '.'));
    }
    return double.tryParse(cleaned);
  }

  static String _transactionId(PurchaseDetails purchase) {
    final id = purchase.purchaseID?.trim() ?? '';
    if (id.isNotEmpty) return id;
    return '';
  }
}
