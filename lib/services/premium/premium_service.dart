import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:in_app_purchase_android/in_app_purchase_android.dart';
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
  String? _entitlementUid;

  /// QA (debug): `SharedPreferences` `facebaby_plus_debug_force` = true força Premium.
  bool _debugPremium = false;

  String _entitlementPrefKey(String uid) => '${_prefEntitlement}_$uid';

  bool _restoreUiPending = false;

  /// Só true quando o utilizador toca em «Restaurar compras» (não no restore silencioso ao abrir).
  bool _userInitiatedRestore = false;

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

  /// Remove cache global legado (partilhado entre contas no mesmo telemóvel).
  Future<void> _purgeLegacyGlobalEntitlementPref() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefEntitlement);
  }

  static bool _firestoreSaysPremium(Map<String, dynamic>? data) {
    if (data == null) return false;
    final v = data['premiumLifetime'];
    return v == true;
  }

  Future<void> _loadEntitlementForUser(String? uid) async {
    final prefs = await SharedPreferences.getInstance();
    await _purgeLegacyGlobalEntitlementPref();
    if (uid == null || uid.isEmpty) {
      _entitlementUid = null;
      _entitlement = false;
      return;
    }
    _entitlementUid = uid;
    _entitlement = prefs.getBool(_entitlementPrefKey(uid)) ?? false;
  }

  Future<void> _onAuthUserChanged(User? user) async {
    await _loadEntitlementForUser(user?.uid);
    if (user != null) {
      await syncPremiumFromFirestore();
    }
    notifyListeners();
  }

  Future<void> initialize() async {
    if (_ready) return;

    final prefs = await SharedPreferences.getInstance();
    await _loadEntitlementForUser(FirebaseAuth.instance.currentUser?.uid);
    assert(() {
      _debugPremium = prefs.getBool(_prefDebugPremium) ?? false;
      return true;
    }());

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      unawaited(_onAuthUserChanged(user));
    });
    debugPrint('PremiumService: auth listener ${_authSub != null}');

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      await syncPremiumFromFirestore();
    }

    if (!premiumStoreSupported()) {
      _ready = true;
      notifyListeners();
      return;
    }

    try {
      _storeAvailable = await _iap.isAvailable();
      if (!_storeAvailable) {
        _ready = true;
        notifyListeners();
        return;
      }

      _purchaseSub = _iap.purchaseStream.listen(
        _onPurchaseUpdates,
        onError: (Object e) => debugPrint('IAP stream error: $e'),
      );
      debugPrint('PremiumService: IAP listener ${_purchaseSub != null ? "on" : "off"}');

      await _queryProducts();
      // Sem restore automático: compra Play é do dispositivo/conta Google, não do uid Firebase.
      // Estado vem do Firestore; «Restaurar compras» liga a compra ao utilizador actual.
    } catch (e, st) {
      debugPrint('PremiumService.initialize: $e\n$st');
    }

    _ready = true;
    notifyListeners();
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
    unawaited(_processPurchaseUpdates(purchases));
  }

  static bool _indicatesItemAlreadyOwned(IAPError err) {
    final blob = '${err.code} ${err.message} ${err.details ?? ''}'.toLowerCase();
    return blob.contains('itemalreadyowned') ||
        blob.contains('item_already_owned') ||
        blob.contains('billingresponse.itemalreadyowned') ||
        blob.contains('item_owned') ||
        blob.contains('já é seu') ||
        blob.contains('ja e seu') ||
        blob.contains('already yours') ||
        blob.contains('already owned');
  }

  /// True se a Play Billing reporta compra activa do SKU vitalício (sem gravar estado).
  Future<bool> _storeBillingShowsLifetimeSku() async {
    if (!premiumStoreSupported() || !_storeAvailable) return false;
    try {
      final addition = InAppPurchase.instance
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final q = await addition.queryPastPurchases();
      if (q.error != null) {
        debugPrint('queryPastPurchases error: ${q.error}');
        return false;
      }
      final sku = PremiumConstants.productIdLifetime;
      for (final d in q.pastPurchases) {
        if (d.productID == sku) return true;
      }
    } catch (e) {
      debugPrint('_storeBillingShowsLifetimeSku: $e');
    }
    return false;
  }

  /// Devolve true se a Play já tem compra activa deste SKU (Android).
  Future<bool> _tryGrantFromAndroidPastPurchases() async {
    final owned = await _storeBillingShowsLifetimeSku();
    if (!owned) return false;
    await _persistEntitlement(true, pushRemote: true);
    return true;
  }

  /// A compra vitalícia fica na **conta Google da Play**, não no uid Firebase.
  /// Se a Play recusa o fluxo («já é seu»), recuperamos o recibo e ligamo-lo ao utilizador actual.
  Future<void> _tryLinkPlayPurchaseToCurrentUser() async {
    if (!premiumStoreSupported() || !_storeAvailable) return;
    if (await _tryGrantFromAndroidPastPurchases()) {
      await syncPremiumFromFirestore();
      return;
    }
    _userInitiatedRestore = true;
    try {
      await _iap.restorePurchases();
      await Future<void>.delayed(const Duration(milliseconds: 2400));
    } catch (e, st) {
      debugPrint('PremiumService _tryLinkPlayPurchaseToCurrentUser: $e\n$st');
    }
    await syncPremiumFromFirestore();
    _userInitiatedRestore = false;
  }

  Future<void> _processPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          break;
        case PurchaseStatus.error:
          debugPrint('Purchase error: ${p.error}');
          if (p.error != null && _indicatesItemAlreadyOwned(p.error!)) {
            await _tryLinkPlayPurchaseToCurrentUser();
          }
          break;
        case PurchaseStatus.purchased:
          if (p.productID == PremiumConstants.productIdLifetime) {
            await _persistEntitlement(true, pushRemote: true);
          }
          break;
        case PurchaseStatus.restored:
          if (p.productID == PremiumConstants.productIdLifetime &&
              _userInitiatedRestore) {
            await _persistEntitlement(true, pushRemote: true);
          }
          break;
        case PurchaseStatus.canceled:
          break;
      }
      if (p.pendingCompletePurchase) {
        await _completeSafe(p);
      }
    }
    if (_restoreUiPending) {
      _restoreUiPending = false;
      _userInitiatedRestore = false;
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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _entitlement = value;
    if (uid != null && uid.isNotEmpty) {
      _entitlementUid = uid;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_entitlementPrefKey(uid), value);
      await prefs.remove(_prefEntitlement);
    }
    notifyListeners();
    if (value && pushRemote) {
      await _pushPremiumToFirestore(true);
    } else if (!value && pushRemote) {
      await _pushPremiumToFirestore(false);
    }
  }

  Future<void> _pushPremiumToFirestore(bool premium) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirestoreUserRepository.instance.saveUserProfile(uid, {
        'premiumLifetime': premium,
        if (premium)
          'premiumProductId': PremiumConstants.productIdLifetime
        else
          'premiumProductId': FieldValue.delete(),
      });
    } catch (e, st) {
      debugPrint('Premium Firestore push failed: $e\n$st');
    }
  }

  /// Garante perfil gratuito na nuvem (conta nova). Chamar só após registo.
  Future<void> markNewAccountFreeInCloud() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _persistEntitlement(false, pushRemote: true);
  }

  /// Lê `users/{uid}.premiumLifetime` — a nuvem manda no estado (não o cache local antigo).
  Future<void> syncPremiumFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_entitlementUid != uid) {
      await _loadEntitlementForUser(uid);
    }
    try {
      final data = await FirestoreUserRepository.instance.getUserProfile(uid);
      final remote = _firestoreSaysPremium(data);
      if (remote) {
        if (!_entitlement) {
          await _persistEntitlement(true, pushRemote: false);
        }
        return;
      }

      // Sem Premium na nuvem: alinhar com a Play antes de retirar o acesso local.
      final playOwnsLifetime = await _storeBillingShowsLifetimeSku();
      if (playOwnsLifetime) {
        await _persistEntitlement(true, pushRemote: true);
        return;
      }
      if (_entitlement) {
        await _persistEntitlement(false, pushRemote: false);
      }
      final orphanSku = data?['premiumProductId'];
      if (orphanSku != null && orphanSku.toString().trim().isNotEmpty) {
        await _pushPremiumToFirestore(false);
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
        'PremiumService purchaseLifetime: buyNonConsumable=false '
        '(pode ser ITEM_ALREADY_OWNED na Play — a tentar recuperar compra).',
      );
      await _tryLinkPlayPurchaseToCurrentUser();
      if (_entitlement) {
        return PurchaseLifetimeResult.billingFlowLaunched;
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (await _tryGrantFromAndroidPastPurchases()) {
        return PurchaseLifetimeResult.billingFlowLaunched;
      }
      debugPrint(
        'PremiumService purchaseLifetime: após fallback restore ainda sem entitlement. '
        'Verifique APK pela Play, conta de teste ou Billing.',
      );
      return PurchaseLifetimeResult.billingLaunchFailed;
    }
    return PurchaseLifetimeResult.billingFlowLaunched;
  }

  Future<void> restorePurchases() async {
    if (!premiumStoreSupported() || !_storeAvailable) return;
    _userInitiatedRestore = true;
    _restoreUiPending = true;
    notifyListeners();
    await _iap.restorePurchases();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await syncPremiumFromFirestore();
    if (_restoreUiPending) {
      _restoreUiPending = false;
      _userInitiatedRestore = false;
      notifyListeners();
    }
  }

  /// Testes: revoga entitlement local (não remove compra na loja).
  Future<void> debugClearEntitlement() async {
    assert(kDebugMode);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _entitlement = false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefEntitlement, false);
    if (uid != null) {
      await prefs.setBool(_entitlementPrefKey(uid), false);
    }
    notifyListeners();
  }

}
