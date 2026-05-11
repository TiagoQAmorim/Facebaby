import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../firebase/firestore_user_repository.dart';
import 'premium_constants.dart';
import 'premium_platform.dart';

/// Resultado ao tentar abrir o fluxo de compra vitalícia na loja.
enum PurchaseLifetimeResult {
  /// [InAppPurchase.buyNonConsumable] devolveu true — folha da Play/App Store aberta.
  billingFlowLaunched,

  /// Sem produto na loja para o SKU configurado ([PremiumConstants.productIdLifetime]).
  productNotFoundInStore,

  /// Produto encontrado mas [buyNonConsumable] devolveu false (ex.: Billing não disponível, erro do cliente).
  billingLaunchFailed,

  /// [InAppPurchase.isAvailable] é false.
  billingUnavailable,

  /// Web ou plataforma sem loja.
  unsupportedPlatform,
}

/// Compra única vitalícia (substitui a antiga assinatura) + espelho em Firestore + cache local.
///
/// As **regras de produto** (grelhas, PDF, memórias, nuvem, etc.) vivem em [FeatureAccess];
/// aqui só se gere **entitlement** a partir da loja e da nuvem.
class PremiumService extends ChangeNotifier {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  static const _prefEntitlement = 'facebaby_premium_entitlement_v2';
  static const _prefDebugPremium = 'facebaby_plus_debug_force';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  StreamSubscription<User?>? _authSub;

  bool _ready = false;
  bool _storeAvailable = false;
  ProductDetails? _lifetimeProduct;
  bool _entitlement = false;

  /// QA (debug): `SharedPreferences` `facebaby_plus_debug_force` = true força Premium.
  bool _debugPremium = false;

  bool _restoreRequested = false;

  /// Última resposta a [queryProductDetails]: IDs pedidos que a loja não devolveu (SKU inexistente ou inactivo).
  List<String> _lastNotFoundIds = const [];

  bool get isInitialized => _ready;
  bool get storeAvailable => _storeAvailable;
  ProductDetails? get lifetimeProduct => _lifetimeProduct;

  /// True se o último pedido à loja indicou que [PremiumConstants.productIdLifetime] não existe ou não está activo.
  bool get lifetimeSkuMissingFromStore =>
      _lastNotFoundIds.contains(PremiumConstants.productIdLifetime);

  /// Preço localizado devolvido pela Play Billing / StoreKit (`SkuDetails.getPrice()` → [ProductDetails.price]).
  /// Usar sempre na UI em vez de valores fixos por região.
  String get formattedLocalizedPrice {
    final p = _lifetimeProduct;
    if (p != null) {
      final store = p.price.trim();
      if (store.isNotEmpty) return store;
      final fallback = _formatRawWithCurrency(p);
      if (fallback != null) return fallback;
    }
    return PremiumConstants.priceDisplayBr;
  }

  /// ISO 4217 quando disponível (ex.: `BRL`, `EUR`) — útil para analytics; vazio se sem produto.
  String get storeCurrencyCode => _lifetimeProduct?.currencyCode ?? '';

  String? _formatRawWithCurrency(ProductDetails p) {
    if (p.rawPrice <= 0 || p.currencyCode.isEmpty) return null;
    try {
      return NumberFormat.simpleCurrency(name: p.currencyCode).format(p.rawPrice);
    } catch (_) {
      return null;
    }
  }

  /// Reconsulta o catálogo (preços regionais actualizados ao voltar à app ou reabrir o paywall).
  Future<void> refreshStorePricing() async {
    if (!premiumStoreSupported()) return;
    try {
      final available = await _iap.isAvailable();
      if (_storeAvailable != available) {
        _storeAvailable = available;
        notifyListeners();
      }
      if (!_storeAvailable) return;
      await _queryProducts();
    } catch (e, st) {
      debugPrint('refreshStorePricing: $e\n$st');
    }
  }

  /// Premium efetivo (loja + prefs + Firestore já fundidos em [_entitlement]).
  bool get isPremium {
    if (kDebugMode && _debugPremium) return true;
    return _entitlement;
  }

  /// Compatível com código legado “Plus”.
  bool get isPlus => isPremium;

  Future<void> initialize() async {
    if (_ready) return;

    final prefs = await SharedPreferences.getInstance();
    _entitlement = prefs.getBool(_prefEntitlement) ?? false;
    assert(() {
      _debugPremium = prefs.getBool(_prefDebugPremium) ?? false;
      return true;
    }());

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      if (user != null) {
        unawaited(syncPremiumFromFirestore());
      }
    });
    debugPrint('PremiumService: auth listener ${_authSub != null}');

    if (!premiumStoreSupported()) {
      _ready = true;
      notifyListeners();
      unawaited(syncPremiumFromFirestore());
      return;
    }

    try {
      _storeAvailable = await _iap.isAvailable();
      if (!_storeAvailable) {
        _ready = true;
        notifyListeners();
        unawaited(syncPremiumFromFirestore());
        return;
      }

      _purchaseSub = _iap.purchaseStream.listen(
        _onPurchaseUpdates,
        onError: (Object e) => debugPrint('IAP stream error: $e'),
      );
      debugPrint('PremiumService: IAP listener ${_purchaseSub != null ? "on" : "off"}');

      await _queryProducts();

      /// Reconcilia com a conta da loja ao abrir (reinstalação / outro dispositivo).
      _restoreRequested = true;
      await _iap.restorePurchases();
    } catch (e, st) {
      debugPrint('PremiumService.initialize: $e\n$st');
    }

    _ready = true;
    notifyListeners();
    unawaited(syncPremiumFromFirestore());
  }

  Future<void> _queryProducts() async {
    final sku = PremiumConstants.productIdLifetime;
    final response = await _iap.queryProductDetails({sku});
    _lastNotFoundIds = List<String>.from(response.notFoundIDs);

    if (response.error != null) {
      debugPrint('PremiumService queryProductDetails IAPError: ${response.error}');
    }
    if (response.notFoundIDs.isNotEmpty) {
      debugPrint(
        'PremiumService queryProductDetails: loja não devolveu estes IDs: ${response.notFoundIDs}. '
        'Em Play Console crie um produto in-app gerido **activo** com ID exactamente "$sku" '
        '(Monetizar → Produtos in-app). Aguarde até ~24h após criar o produto.',
      );
    }
    if (response.productDetails.isNotEmpty) {
      ProductDetails? match;
      for (final p in response.productDetails) {
        if (p.id == sku) {
          match = p;
          break;
        }
      }
      _lifetimeProduct = match ?? response.productDetails.first;
    } else {
      _lifetimeProduct = null;
    }
    notifyListeners();
  }

  void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
          debugPrint('Purchase error: ${p.error}');
          break;
        case PurchaseStatus.purchased:
        case PurchaseStatus.restored:
          if (p.productID == PremiumConstants.productIdLifetime) {
            unawaited(_persistEntitlement(true));
          }
          break;
        case PurchaseStatus.canceled:
          break;
      }
      if (p.pendingCompletePurchase) {
        unawaited(_completeSafe(p));
      }
    }
    if (_restoreRequested) {
      _restoreRequested = false;
      notifyListeners();
    }
  }

  Future<void> _completeSafe(PurchaseDetails p) async {
    try {
      await _iap.completePurchase(p);
    } catch (e) {
      debugPrint('completePurchase: $e');
    }
  }

  Future<void> _persistEntitlement(bool value, {bool pushRemote = true}) async {
    _entitlement = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEntitlement, value);
    notifyListeners();
    if (value && pushRemote) {
      await _pushPremiumToFirestore(true);
    }
  }

  Future<void> _pushPremiumToFirestore(bool premium) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirestoreUserRepository.instance.saveUserProfile(uid, {
        'premiumLifetime': premium,
        'premiumProductId': PremiumConstants.productIdLifetime,
      });
    } catch (e, st) {
      debugPrint('Premium Firestore push failed: $e\n$st');
    }
  }

  /// Lê `users/{uid}.premiumLifetime` e activa cache local (fallback quando a loja demora).
  Future<void> syncPremiumFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      final data = await FirestoreUserRepository.instance.getUserProfile(uid);
      final remote = data?['premiumLifetime'] == true;
      if (remote && !_entitlement) {
        await _persistEntitlement(true, pushRemote: false);
      }
      if (!remote && _entitlement) {
        /// Este dispositivo diz Premium mas a nuvem não — re-envia (ex.: compra offline).
        await _pushPremiumToFirestore(true);
      }
    } catch (e, st) {
      debugPrint('syncPremiumFromFirestore: $e\n$st');
    }
  }

  /// Compra vitalícia (non-consumable). O utilizador completa o pagamento na folha da loja.
  Future<PurchaseLifetimeResult> purchaseLifetime() async {
    if (!premiumStoreSupported()) return PurchaseLifetimeResult.unsupportedPlatform;
    if (!_storeAvailable) return PurchaseLifetimeResult.billingUnavailable;

    var product = _lifetimeProduct;
    if (product == null) {
      await _queryProducts();
      product = _lifetimeProduct;
    }
    if (product == null) {
      debugPrint(
        'PremiumService purchaseLifetime: sem ProductDetails para SKU "${PremiumConstants.productIdLifetime}". '
        'notFound=$_lastNotFoundIds',
      );
      return PurchaseLifetimeResult.productNotFoundInStore;
    }

    final param = PurchaseParam(productDetails: product);
    final ok = await _iap.buyNonConsumable(purchaseParam: param);
    if (!ok) {
      debugPrint(
        'PremiumService purchaseLifetime: buyNonConsumable=false. '
        'Causas frequentes: APK não instalado pela Play (teste interno/fechado), '
        'conta de teste não licenciada, ou Billing temporariamente indisponível.',
      );
      return PurchaseLifetimeResult.billingLaunchFailed;
    }
    return PurchaseLifetimeResult.billingFlowLaunched;
  }

  Future<void> restorePurchases() async {
    if (!premiumStoreSupported() || !_storeAvailable) return;
    _restoreRequested = true;
    await _iap.restorePurchases();
  }

  /// Testes: revoga entitlement local (não remove compra na loja).
  Future<void> debugClearEntitlement() async {
    assert(kDebugMode);
    _entitlement = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEntitlement, false);
    notifyListeners();
  }

}
