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

enum PurchasePremiumResult {
  billingFlowLaunched,
  productNotFoundInStore,
  billingLaunchFailed,
  billingUnavailable,
  unsupportedPlatform,
}

typedef PurchaseLifetimeResult = PurchasePremiumResult;

/// Plano Plus ativo para a UI (paywall).
enum PremiumBillingPlan { free, monthly, annual, lifetime, plusUnknown }

/// FaceBaby Plus: mensal, anual e legado vitalício.
class PremiumService extends ChangeNotifier {
  PremiumService._();
  static final PremiumService instance = PremiumService._();

  static const _prefEntitlement = 'facebaby_premium_entitlement_v2';
  static const _prefActiveProduct = 'facebaby_premium_active_product_v1';
  static const _prefDebugPremium = 'facebaby_plus_debug_force';
  static const _kIapLog = 'FaceBaby IAP';

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;
  StreamSubscription<User?>? _authSub;

  bool _ready = false;
  bool _storeAvailable = false;
  ProductDetails? _monthlyProduct;
  ProductDetails? _annualProduct;
  bool _entitlement = false;
  String? _entitlementUid;
  String? _activeProductId;
  bool _debugPremium = false;

  bool _restoreUiPending = false;
  bool _userInitiatedRestore = false;
  List<String> _lastNotFoundIds = const [];
  bool _purchaseAwaitingStoreConfirmation = false;
  String? _lastPurchaseErrorMessage;
  String? _lastPurchaseProductId;

  void _log(String message) => debugPrint('[$_kIapLog] $message');

  static bool get qaToolsEnabled =>
      kDebugMode ||
      bool.fromEnvironment('FACEBABY_QA_TOOLS', defaultValue: false);

  String _entitlementPrefKey(String uid) => '${_prefEntitlement}_$uid';

  String _activeProductPrefKey(String uid) => '${_prefActiveProduct}_$uid';

  bool get isInitialized => _ready;
  bool get storeAvailable => _storeAvailable;
  ProductDetails? get monthlyProduct => _monthlyProduct;
  ProductDetails? get annualProduct => _annualProduct;
  ProductDetails? get lifetimeProduct => _monthlyProduct;

  bool get monthlySkuMissingFromStore =>
      _lastNotFoundIds.contains(PremiumConstants.productIdMonthly);

  bool get annualSkuMissingFromStore =>
      _lastNotFoundIds.contains(PremiumConstants.productIdAnnual);

  bool get lifetimeSkuMissingFromStore => monthlySkuMissingFromStore;

  List<String> get notFoundProductIds => List<String>.from(_lastNotFoundIds);

  bool get purchaseAwaitingStoreConfirmation => _purchaseAwaitingStoreConfirmation;

  String? get lastPurchaseErrorMessage => _lastPurchaseErrorMessage;

  String? get lastPurchaseProductId => _lastPurchaseProductId;

  bool get monthlyProductReady => _monthlyProduct != null;

  bool get annualProductReady => _annualProduct != null;

  /// Preço mensal para UI — rejeita valores de loja que parecem anuais.
  String get formattedLocalizedPriceMonthly {
    final amount = _productAmount(_monthlyProduct);
    if (amount == null ||
        amount > PremiumConstants.monthlyStorePriceSanityMaxBr) {
      return '';
    }
    final annualAmt = _productAmount(_annualProduct);
    if (annualAmt != null && (amount - annualAmt).abs() < 0.05) {
      return '';
    }
    return _formatStorePrice(_monthlyProduct);
  }

  PremiumBillingPlan get activeBillingPlan {
    if (!isPremium) return PremiumBillingPlan.free;
    final id = _activeProductId?.trim();
    if (id == null || id.isEmpty) return PremiumBillingPlan.plusUnknown;
    if (id == PremiumConstants.productIdMonthly) {
      return PremiumBillingPlan.monthly;
    }
    if (id == PremiumConstants.productIdAnnual) {
      return PremiumBillingPlan.annual;
    }
    if (id == PremiumConstants.productIdLifetimeLegacy) {
      return PremiumBillingPlan.lifetime;
    }
    return PremiumBillingPlan.plusUnknown;
  }

  /// Preço anual para UI — rejeita valores de loja que parecem mensais.
  String get formattedLocalizedPriceAnnual {
    final amount = _productAmount(_annualProduct);
    if (amount == null) return '';
    if (amount > 0 &&
        amount <= PremiumConstants.monthlyStorePriceSanityMaxBr) {
      return '';
    }
    return _formatStorePrice(_annualProduct);
  }

  String get formattedLocalizedPrice => formattedLocalizedPriceMonthly;

  String get storeCurrencyCode =>
      _monthlyProduct?.currencyCode ?? _annualProduct?.currencyCode ?? '';

  String _formatStorePrice(ProductDetails? p) {
    if (p == null) return '';
    final store = p.price.trim();
    if (store.isNotEmpty) return store;
    if (p.rawPrice > 0 && p.currencyCode.isNotEmpty) {
      try {
        return NumberFormat.simpleCurrency(name: p.currencyCode)
            .format(p.rawPrice);
      } catch (_) {
        return '';
      }
    }
    return '';
  }

  /// Valor numérico do produto (rawPrice ou parse da string localizada).
  static double? _productAmount(ProductDetails? p) {
    if (p == null) return null;
    if (p.rawPrice > 0) return p.rawPrice;
    return _parseLocalizedPriceAmount(p.price);
  }

  @visibleForTesting
  static double? parseLocalizedPriceAmountForTest(String raw) =>
      _parseLocalizedPriceAmount(raw);

  static double? _parseLocalizedPriceAmount(String raw) {
    final text = raw.trim();
    if (text.isEmpty) return null;
    // Mantém dígitos, vírgula e ponto (ex.: "R$ 129,00", "US$15.90").
    final cleaned = text.replaceAll(RegExp(r'[^\d.,]'), '');
    if (cleaned.isEmpty) return null;
    if (cleaned.contains(',') && cleaned.contains('.')) {
      // 1.234,56 → 1234.56
      return double.tryParse(cleaned.replaceAll('.', '').replaceAll(',', '.'));
    }
    if (cleaned.contains(',')) {
      return double.tryParse(cleaned.replaceAll(',', '.'));
    }
    return double.tryParse(cleaned);
  }

  static bool _isPremiumProductId(String? id) {
    if (id == null || id.isEmpty) return false;
    return PremiumConstants.allPremiumProductIds.contains(id);
  }

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

  bool get isPremium {
    if (qaToolsEnabled && _debugPremium) return true;
    return _entitlement;
  }

  bool get isDebugPremiumForced => qaToolsEnabled && _debugPremium;
  bool get isPlus => isPremium;

  Future<void> _purgeLegacyGlobalEntitlementPref() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefEntitlement);
  }

  static bool _firestoreSaysPremium(Map<String, dynamic>? data) {
    if (data == null) return false;
    return data['premiumLifetime'] == true;
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
    _activeProductId = prefs.getString(_activeProductPrefKey(uid));
  }

  Future<void> _cacheActiveProductId(String? productId) async {
    _activeProductId = productId?.trim();
    final uid = _entitlementUid ?? FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final id = _activeProductId;
    if (id == null || id.isEmpty) {
      await prefs.remove(_activeProductPrefKey(uid));
    } else {
      await prefs.setString(_activeProductPrefKey(uid), id);
    }
  }

  Future<void> _resolveActiveProductFromStore() async {
    final owned = await _ownedPremiumSkusFromStore();
    if (owned.contains(PremiumConstants.productIdAnnual)) {
      await _cacheActiveProductId(PremiumConstants.productIdAnnual);
    } else if (owned.contains(PremiumConstants.productIdMonthly)) {
      await _cacheActiveProductId(PremiumConstants.productIdMonthly);
    } else if (owned.contains(PremiumConstants.productIdLifetimeLegacy)) {
      await _cacheActiveProductId(PremiumConstants.productIdLifetimeLegacy);
    }
  }

  Future<void> _onAuthUserChanged(User? user) async {
    // Evita flash de Plus do utilizador anterior enquanto carrega o perfil novo.
    _entitlement = false;
    _activeProductId = null;
    notifyListeners();
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
    if (qaToolsEnabled) {
      _debugPremium = prefs.getBool(_prefDebugPremium) ?? false;
    }

    _authSub = FirebaseAuth.instance.authStateChanges().listen((user) {
      unawaited(_onAuthUserChanged(user));
    });

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
        onError: (Object e, StackTrace st) {
          _log('purchase stream error: $e');
          debugPrint('[$_kIapLog] purchase stream stack: $st');
          _purchaseAwaitingStoreConfirmation = false;
          _lastPurchaseErrorMessage = e.toString();
          notifyListeners();
        },
      );

      await _queryProducts();
    } catch (e, st) {
      debugPrint('PremiumService.initialize: $e\n$st');
    }

    _ready = true;
    notifyListeners();
  }

  Future<void> _queryProducts() async {
    final ids = PremiumConstants.subscriptionProductIds;
    _log('product query start ids=${ids.join(', ')}');
    final response = await _iap.queryProductDetails(ids);
    _lastNotFoundIds = List<String>.from(response.notFoundIDs);

    if (response.error != null) {
      _log(
        'product query IAPError code=${response.error!.code} '
        'message=${response.error!.message} details=${response.error!.details}',
      );
    }

    if (_lastNotFoundIds.isEmpty) {
      _log('products not found: (none)');
    } else {
      for (final missing in _lastNotFoundIds) {
        _log('products not found: $missing');
      }
    }

    _monthlyProduct = null;
    _annualProduct = null;
    for (final p in response.productDetails) {
      _log(
        'products found: id=${p.id} price=${p.price} '
        'rawPrice=${p.rawPrice} currency=${p.currencyCode}',
      );
      if (p.id == PremiumConstants.productIdMonthly) {
        _monthlyProduct = p;
      } else if (p.id == PremiumConstants.productIdAnnual) {
        _annualProduct = p;
      }
    }

    // Se a loja devolveu preços invertidos (mensal > anual), troca a atribuição
    // para a UI e a compra seguirem o preço esperado de cada plano.
    final monthly = _monthlyProduct;
    final annual = _annualProduct;
    final monthlyAmt = _productAmount(monthly);
    final annualAmt = _productAmount(annual);
    if (monthly != null &&
        annual != null &&
        monthlyAmt != null &&
        annualAmt != null &&
        monthlyAmt > annualAmt) {
      _log(
        'price sanity swap: monthly amt=$monthlyAmt '
        '(${monthly.id}) > annual amt=$annualAmt (${annual.id})',
      );
      _monthlyProduct = annual;
      _annualProduct = monthly;
    } else if (monthly != null &&
        annual == null &&
        monthlyAmt != null &&
        monthlyAmt > PremiumConstants.monthlyStorePriceSanityMaxBr) {
      // Só veio o SKU "mensal", mas o preço é de plano anual.
      _log(
        'price sanity: lone monthly looks annual-sized amt=$monthlyAmt '
        '→ treat as annual product',
      );
      _annualProduct = monthly;
      _monthlyProduct = null;
    } else if (annual != null &&
        monthly == null &&
        annualAmt != null &&
        annualAmt > 0 &&
        annualAmt <= PremiumConstants.monthlyStorePriceSanityMaxBr) {
      // Só veio o SKU "anual", mas o preço é de plano mensal.
      _log(
        'price sanity: lone annual looks monthly-sized amt=$annualAmt '
        '→ treat as monthly product',
      );
      _monthlyProduct = annual;
      _annualProduct = null;
    } else if (monthlyAmt != null &&
        monthlyAmt > PremiumConstants.monthlyStorePriceSanityMaxBr) {
      _log(
        'price sanity warn: monthly product price looks annual-sized '
        'amt=$monthlyAmt id=${monthly?.id} — UI will use fallback R\$ 15,90',
      );
    }

    if (_monthlyProduct == null) {
      _log('monthly product missing after query (${PremiumConstants.productIdMonthly})');
    }
    if (_annualProduct == null) {
      _log('annual product missing after query (${PremiumConstants.productIdAnnual})');
    }

    notifyListeners();
  }

  void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    unawaited(_processPurchaseUpdates(purchases));
  }

  Future<Set<String>> _ownedPremiumSkusFromStore() async {
    final owned = <String>{};
    if (!premiumStoreSupported() || !_storeAvailable) return owned;
    if (!premiumOnAndroid()) {
      // iOS: compras anteriores chegam via restorePurchases + purchaseStream.
      return owned;
    }
    try {
      final addition = InAppPurchase.instance
          .getPlatformAddition<InAppPurchaseAndroidPlatformAddition>();
      final q = await addition.queryPastPurchases();
      if (q.error != null) {
        debugPrint('queryPastPurchases error: ${q.error}');
        return owned;
      }
      for (final d in q.pastPurchases) {
        if (_isPremiumProductId(d.productID)) {
          owned.add(d.productID);
        }
      }
    } catch (e) {
      debugPrint('_ownedPremiumSkusFromStore: $e');
    }
    return owned;
  }

  Future<bool> _storeOwnsLegacyLifetime() async {
    final owned = await _ownedPremiumSkusFromStore();
    return owned.contains(PremiumConstants.productIdLifetimeLegacy);
  }

  Future<bool> _storeOwnsActiveSubscription() async {
    final owned = await _ownedPremiumSkusFromStore();
    return owned.contains(PremiumConstants.productIdMonthly) ||
        owned.contains(PremiumConstants.productIdAnnual);
  }

  Future<bool> _storeGrantsPremiumAccess() async {
    if (await _storeOwnsLegacyLifetime()) return true;
    return _storeOwnsActiveSubscription();
  }

  Future<bool> _tryGrantFromAndroidPastPurchases() async {
    final grants = await _storeGrantsPremiumAccess();
    if (!grants) return false;
    await _persistEntitlement(true, pushRemote: true);
    return true;
  }

  Future<void> _processPurchaseUpdates(List<PurchaseDetails> purchases) async {
    for (final p in purchases) {
      switch (p.status) {
        case PurchaseStatus.pending:
          _log('purchase pending product=${p.productID}');
          _purchaseAwaitingStoreConfirmation = true;
          _lastPurchaseErrorMessage = null;
          break;
        case PurchaseStatus.error:
          _log(
            'purchase error product=${p.productID} '
            'code=${p.error?.code} message=${p.error?.message} details=${p.error?.details}',
          );
          _purchaseAwaitingStoreConfirmation = false;
          _lastPurchaseErrorMessage =
              p.error?.message ?? p.error?.code ?? 'purchase_error';
          break;
        case PurchaseStatus.purchased:
          _log('purchase completed product=${p.productID}');
          _purchaseAwaitingStoreConfirmation = false;
          _lastPurchaseErrorMessage = null;
          if (_isPremiumProductId(p.productID)) {
            await _persistEntitlement(true, pushRemote: true, productId: p.productID);
          }
          break;
        case PurchaseStatus.restored:
          _log('purchase restored product=${p.productID}');
          _purchaseAwaitingStoreConfirmation = false;
          _lastPurchaseErrorMessage = null;
          if (_isPremiumProductId(p.productID) && _userInitiatedRestore) {
            await _persistEntitlement(true, pushRemote: true, productId: p.productID);
          }
          break;
        case PurchaseStatus.canceled:
          _log('purchase canceled product=${p.productID}');
          _purchaseAwaitingStoreConfirmation = false;
          _lastPurchaseErrorMessage = 'purchase_canceled';
          break;
      }
      if (p.pendingCompletePurchase) {
        await _completeSafe(p);
      }
    }
    if (_restoreUiPending) {
      _restoreUiPending = false;
      _userInitiatedRestore = false;
    }
    notifyListeners();
  }

  Future<void> _completeSafe(PurchaseDetails p) async {
    try {
      await _iap.completePurchase(p);
      _log('purchase acknowledged product=${p.productID}');
    } catch (e) {
      _log('completePurchase failed product=${p.productID} error=$e');
    }
  }

  Future<void> _persistEntitlement(
    bool value, {
    bool pushRemote = true,
    String? productId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    _entitlement = value;
    if (uid != null && uid.isNotEmpty) {
      _entitlementUid = uid;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_entitlementPrefKey(uid), value);
      await prefs.remove(_prefEntitlement);
    }
    if (value && productId != null && productId.trim().isNotEmpty) {
      await _cacheActiveProductId(productId);
    } else if (!value) {
      await _cacheActiveProductId(null);
    }
    notifyListeners();
    if (value && pushRemote) {
      await _pushPremiumToFirestore(
        true,
        productId: productId ?? PremiumConstants.productIdAnnual,
      );
    } else if (!value && pushRemote) {
      await _pushPremiumToFirestore(false);
    }
  }

  Future<void> _pushPremiumToFirestore(
    bool premium, {
    String? productId,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirestoreUserRepository.instance.saveUserProfile(uid, {
        'premiumLifetime': premium,
        if (premium)
          'premiumProductId': productId ?? PremiumConstants.productIdAnnual
        else
          'premiumProductId': FieldValue.delete(),
      });
    } catch (e, st) {
      debugPrint('Premium Firestore push failed: $e\n$st');
    }
  }

  Future<void> markNewAccountFreeInCloud() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _persistEntitlement(false, pushRemote: true);
  }

  /// Sincroniza Plus a partir do perfil cloud do utilizador atual.
  ///
  /// Compras na loja do dispositivo **não** concedem Plus automaticamente no login
  /// (evita que outra conta FaceBaby no mesmo aparelho herde a assinatura).
  /// Use [restorePurchases] para associar compras da loja à conta atual.
  Future<void> syncPremiumFromFirestore() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    if (_entitlementUid != uid) {
      await _loadEntitlementForUser(uid);
    }
    try {
      final data = await FirestoreUserRepository.instance.getUserProfile(uid);
      final remote = _firestoreSaysPremium(data);
      final remoteProduct = '${data?['premiumProductId'] ?? ''}'.trim();
      if (remoteProduct.isNotEmpty) {
        await _cacheActiveProductId(remoteProduct);
      }
      if (remote) {
        if (!_entitlement) {
          await _persistEntitlement(
            true,
            pushRemote: false,
            productId: remoteProduct.isNotEmpty
                ? remoteProduct
                : _activeProductId,
          );
        }
        if (_activeProductId == null || _activeProductId!.isEmpty) {
          await _resolveActiveProductFromStore();
        }
        return;
      }

      if (_entitlement) {
        await _cacheActiveProductId(null);
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

  Future<PurchasePremiumResult> _purchaseProduct(ProductDetails? product, String sku) async {
    if (!premiumStoreSupported()) {
      return PurchasePremiumResult.unsupportedPlatform;
    }
    if (!_storeAvailable) return PurchasePremiumResult.billingUnavailable;

    _lastPurchaseErrorMessage = null;
    _lastPurchaseProductId = sku;

    var details = product;
    if (details == null) {
      await _queryProducts();
      details = sku == PremiumConstants.productIdAnnual
          ? _annualProduct
          : _monthlyProduct;
    }
    if (details == null) {
      _log('purchase blocked: product not found in store sku=$sku');
      if (_lastNotFoundIds.contains(sku)) {
        _log('missing product ID confirmed: $sku');
      }
      return PurchasePremiumResult.productNotFoundInStore;
    }

    final PurchaseParam param;
    if (details is GooglePlayProductDetails) {
      param = GooglePlayPurchaseParam(productDetails: details);
    } else {
      param = PurchaseParam(productDetails: details);
    }

    _log(
      'purchase start sku=$sku storePrice=${details.price} '
      'method=buyNonConsumable',
    );
    _purchaseAwaitingStoreConfirmation = true;
    notifyListeners();

    try {
      final ok = await _iap.buyNonConsumable(purchaseParam: param);
      if (!ok) {
        _log('purchase start failed sku=$sku buyNonConsumable returned false');
        _purchaseAwaitingStoreConfirmation = false;
        notifyListeners();
        return PurchasePremiumResult.billingLaunchFailed;
      }
      _log('purchase sheet launched sku=$sku awaiting store confirmation');
      return PurchasePremiumResult.billingFlowLaunched;
    } catch (e, st) {
      _log('purchase start exception sku=$sku error=$e');
      debugPrint('[$_kIapLog] purchase start stack: $st');
      _purchaseAwaitingStoreConfirmation = false;
      _lastPurchaseErrorMessage = e.toString();
      notifyListeners();
      return PurchasePremiumResult.billingLaunchFailed;
    }
  }

  Future<PurchasePremiumResult> purchaseMonthly() => _purchaseProduct(
        _monthlyProduct,
        PremiumConstants.productIdMonthly,
      );

  Future<PurchasePremiumResult> purchaseAnnual() => _purchaseProduct(
        _annualProduct,
        PremiumConstants.productIdAnnual,
      );

  Future<PurchasePremiumResult> purchaseLifetime() => purchaseAnnual();

  Future<void> restorePurchases() async {
    if (!premiumStoreSupported() || !_storeAvailable) return;
    _userInitiatedRestore = true;
    _restoreUiPending = true;
    notifyListeners();
    if (await _tryGrantFromAndroidPastPurchases()) {
      _restoreUiPending = false;
      _userInitiatedRestore = false;
      notifyListeners();
      return;
    }
    await _iap.restorePurchases();
    await Future<void>.delayed(const Duration(milliseconds: 2400));
    if (premiumOnAndroid()) {
      await _tryGrantFromAndroidPastPurchases();
    }
    _restoreUiPending = false;
    _userInitiatedRestore = false;
    notifyListeners();
  }

  Future<void> setDebugPremiumForced(bool value) async {
    if (!qaToolsEnabled) return;
    _debugPremium = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefDebugPremium, value);
    notifyListeners();
  }

  Future<void> grantLifetimePremiumForCurrentUser() async {
    if (!qaToolsEnabled) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('QA_PREMIUM_NO_USER');
    }
    await _persistEntitlement(true, pushRemote: true);
  }

  Future<void> debugClearEntitlement() async {
    assert(qaToolsEnabled);
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
