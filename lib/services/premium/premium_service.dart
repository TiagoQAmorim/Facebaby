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

  String get formattedLocalizedPriceMonthly {
    if (_monthlyPriceLooksMisconfigured(_monthlyProduct)) {
      return PremiumConstants.priceDisplayMonthlyBr;
    }
    return _formatProductPrice(
      _monthlyProduct,
      PremiumConstants.priceDisplayMonthlyBr,
      perMonth: true,
    );
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

  static bool _monthlyPriceLooksMisconfigured(ProductDetails? p) {
    if (p == null) return false;
    if (p.currencyCode.toUpperCase() != 'BRL') return false;
    return p.rawPrice > PremiumConstants.monthlyStorePriceSanityMaxBr;
  }

  String get formattedLocalizedPriceAnnual =>
      _formatProductPrice(_annualProduct, PremiumConstants.priceDisplayAnnualBr, perMonth: false);

  String get formattedLocalizedPrice => formattedLocalizedPriceMonthly;

  String get storeCurrencyCode =>
      _monthlyProduct?.currencyCode ?? _annualProduct?.currencyCode ?? '';

  String _formatProductPrice(
    ProductDetails? p,
    String fallback, {
    required bool perMonth,
  }) {
    if (p != null) {
      final store = p.price.trim();
      if (store.isNotEmpty) {
        final lower = store.toLowerCase();
        if (perMonth &&
            !lower.contains('/mês') &&
            !lower.contains('/mes') &&
            !lower.contains('/month')) {
          return '$store/mês';
        }
        return store;
      }
      final raw = _formatRawWithCurrency(p);
      if (raw != null) {
        return perMonth ? '$raw/mês' : raw;
      }
    }
    return fallback;
  }

  String? _formatRawWithCurrency(ProductDetails p) {
    if (p.rawPrice <= 0 || p.currencyCode.isEmpty) return null;
    try {
      return NumberFormat.simpleCurrency(name: p.currencyCode).format(p.rawPrice);
    } catch (_) {
      return null;
    }
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
        onError: (Object e) => debugPrint('IAP stream error: $e'),
      );

      await _queryProducts();
    } catch (e, st) {
      debugPrint('PremiumService.initialize: $e\n$st');
    }

    _ready = true;
    notifyListeners();
  }

  Future<void> _queryProducts() async {
    final ids = PremiumConstants.allPremiumProductIds;
    final response = await _iap.queryProductDetails(ids);
    _lastNotFoundIds = List<String>.from(response.notFoundIDs);

    if (response.error != null) {
      debugPrint('PremiumService queryProductDetails IAPError: ${response.error}');
    }

    _monthlyProduct = null;
    _annualProduct = null;
    for (final p in response.productDetails) {
      if (p.id == PremiumConstants.productIdMonthly) {
        _monthlyProduct = p;
      } else if (p.id == PremiumConstants.productIdAnnual) {
        _annualProduct = p;
      }
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

  Future<Set<String>> _ownedPremiumSkusFromStore() async {
    final owned = <String>{};
    if (!premiumStoreSupported() || !_storeAvailable) return owned;
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
          if (_isPremiumProductId(p.productID)) {
            await _persistEntitlement(true, pushRemote: true, productId: p.productID);
          }
          break;
        case PurchaseStatus.restored:
          if (_isPremiumProductId(p.productID) && _userInitiatedRestore) {
            await _persistEntitlement(true, pushRemote: true, productId: p.productID);
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

      if (await _storeGrantsPremiumAccess()) {
        await _resolveActiveProductFromStore();
        await _persistEntitlement(
          true,
          pushRemote: true,
          productId: _activeProductId,
        );
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

    var details = product;
    if (details == null) {
      await _queryProducts();
      if (sku == PremiumConstants.productIdAnnual) {
        details = _annualProduct;
      } else {
        details = _monthlyProduct;
      }
    }
    if (details == null) {
      return PurchasePremiumResult.productNotFoundInStore;
    }

    final PurchaseParam param;
    if (details is GooglePlayProductDetails) {
      param = GooglePlayPurchaseParam(productDetails: details);
    } else {
      param = PurchaseParam(productDetails: details);
    }

    final ok = await _iap.buyNonConsumable(purchaseParam: param);
    if (!ok) {
      await _tryLinkPlayPurchaseToCurrentUser();
      if (_entitlement) {
        return PurchasePremiumResult.billingFlowLaunched;
      }
      await Future<void>.delayed(const Duration(milliseconds: 600));
      if (await _tryGrantFromAndroidPastPurchases()) {
        return PurchasePremiumResult.billingFlowLaunched;
      }
      return PurchasePremiumResult.billingLaunchFailed;
    }
    return PurchasePremiumResult.billingFlowLaunched;
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
    await _iap.restorePurchases();
    await Future<void>.delayed(const Duration(milliseconds: 900));
    await syncPremiumFromFirestore();
    if (_restoreUiPending) {
      _restoreUiPending = false;
      _userInitiatedRestore = false;
      notifyListeners();
    }
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
