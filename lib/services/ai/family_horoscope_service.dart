import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../controllers/current_baby_controller.dart';
import '../../utils/family_date_keys.dart';
import '../../i18n/app_i18n.dart';
import '../family_horoscope_read_prefs.dart';
import '../firebase/profile_cloud_sync.dart';
import '../premium/feature_access.dart';
import '../premium/premium_service.dart';

/// Garante horóscopo do dia em cache (uma chamada por vez; vários await compartilham o mesmo Future).
abstract final class FamilyHoroscopeBootstrap {
  FamilyHoroscopeBootstrap._();

  static Future<void>? _ensureFuture;

  static Future<void> ensureToday({required String languageCode}) {
    if (!FeatureAccess.canUseAiFamilyHoroscope) {
      return Future<void>.value();
    }
    return _ensureFuture ??=
        _runEnsureToday(languageCode: languageCode).whenComplete(() {
      _ensureFuture = null;
    });
  }

  static Future<void> _runEnsureToday({required String languageCode}) async {
    try {
      await FamilyHoroscopeReadPrefs.clearIfNewDay();
      final svc = FamilyHoroscopeService();
      final cached = await svc.loadTodayCached();
      if (cached != null) {
        await FamilyHoroscopeUnreadBadge.refresh();
        return;
      }
      await PremiumService.instance.syncPremiumFromFirestore();
      final motherId =
          CurrentBabyController.instance.currentMotherRow?['id'] as int?;
      if (motherId != null) {
        await ProfileCloudSync.pushMother(motherId);
      }
      await svc.generateToday(languageCode: languageCode);
      await FamilyHoroscopeUnreadBadge.refresh();
    } catch (_) {
      await FamilyHoroscopeUnreadBadge.refresh();
    }
  }
}

/// Horóscopo familiar diário via `generateDailyFamilyHoroscope` + cache Firestore.
class FamilyHoroscopeService {
  FamilyHoroscopeService({
    FirebaseFunctions? functions,
    FirebaseFirestore? firestore,
    FirebaseAuth? auth,
  })  : _functions = functions ??
            FirebaseFunctions.instanceFor(region: 'southamerica-east1'),
        _firestore = firestore ?? FirebaseFirestore.instance,
        _auth = auth ?? FirebaseAuth.instance;

  final FirebaseFunctions _functions;
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  String _todayKey() => FamilyDateKeys.todayCompact();

  DocumentReference<Map<String, dynamic>>? get _todayDoc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore
        .collection('family_horoscopes')
        .doc(uid)
        .collection('daily')
        .doc(_todayKey());
  }

  Future<FamilyDailyHoroscope?> loadTodayCached() async {
    final ref = _todayDoc;
    if (ref == null) return null;
    final snap = await ref.get();
    if (!snap.exists) return null;
    return FamilyDailyHoroscope.fromMap(snap.data() ?? {}, dateKey: _todayKey());
  }

  Stream<FamilyDailyHoroscope?> watchToday() {
    final ref = _todayDoc;
    if (ref == null) return Stream.value(null);
    return ref.snapshots().map((snap) {
      if (!snap.exists) return null;
      return FamilyDailyHoroscope.fromMap(snap.data() ?? {}, dateKey: _todayKey());
    });
  }

  /// Dados locais da Família (fallback se o perfil na nuvem estiver incompleto).
  Map<String, dynamic> buildProfilePayload() {
    final mother = CurrentBabyController.instance.currentMotherRow;
    final baby = CurrentBabyController.instance.currentBabyRow;
    final payload = <String, dynamic>{};

    if (mother != null) {
      final name = '${mother['name'] ?? ''}'.trim();
      if (name.isNotEmpty) payload['motherName'] = name;
      final mb = '${mother['birth_date'] ?? ''}'.trim();
      if (mb.isNotEmpty) payload['motherBirthDate'] = mb;
      final fn = '${mother['father_name'] ?? ''}'.trim();
      if (fn.isNotEmpty) payload['fatherName'] = fn;
      final fb = '${mother['father_birth_date'] ?? ''}'.trim();
      if (fb.isNotEmpty) payload['fatherBirthDate'] = fb;
      final regFather = (mother['register_father'] as num?)?.toInt() == 1;
      if (regFather || fn.isNotEmpty) payload['fatherRegistered'] = true;
    }

    if (baby != null) {
      final name = '${baby['name'] ?? ''}'.trim();
      if (name.isNotEmpty) payload['babyName'] = name;
      final bb = '${baby['birth_date'] ?? ''}'.trim();
      if (bb.isNotEmpty) payload['babyBirthDate'] = bb;
      final cloudId = '${baby['cloud_id'] ?? ''}'.trim();
      if (cloudId.isNotEmpty) payload['babyId'] = cloudId;
    }

    return payload;
  }

  Future<FamilyDailyHoroscope> generateToday({
    bool forceRefresh = false,
    required String languageCode,
  }) async {
    try {
      final profile = buildProfilePayload();
      final result = await _functions
          .httpsCallable('generateDailyFamilyHoroscope')
          .call<Map<String, dynamic>>({
        'forceRefresh': forceRefresh,
        'languageCode': languageCode,
        if (profile.isNotEmpty) 'profile': profile,
      });
      return FamilyDailyHoroscope.fromMap(
        Map<String, dynamic>.from(result.data),
        dateKey: _todayKey(),
      );
    } on FirebaseFunctionsException catch (e) {
      throw FamilyHoroscopeException(
        e.code,
        serverMessage: (e.message ?? '').trim(),
      );
    }
  }

  static String languageCodeFromApp(S strings) => switch (strings.lang) {
        AppLang.pt => 'pt',
        AppLang.en => 'en',
        AppLang.es => 'es',
        AppLang.fr => 'fr',
        AppLang.de => 'de',
        AppLang.it => 'it',
        _ => 'pt',
      };
}

class FamilyHoroscopeException implements Exception {
  const FamilyHoroscopeException(this.code, {this.serverMessage});

  final String code;
  final String? serverMessage;

  @override
  String toString() => code;
}

class FamilyDailyHoroscope {
  const FamilyDailyHoroscope({
    required this.dateKey,
    required this.motherSign,
    required this.fatherSign,
    required this.babySign,
    required this.motherText,
    required this.fatherText,
    required this.babyText,
    required this.familyCompatibilityText,
    required this.familyAdviceText,
    this.generatedByAi = true,
  });

  final String dateKey;
  final String motherSign;
  final String fatherSign;
  final String babySign;
  final String motherText;
  final String fatherText;
  final String babyText;
  final String familyCompatibilityText;
  final String familyAdviceText;
  final bool generatedByAi;

  bool get hasFather => fatherText.trim().isNotEmpty;

  factory FamilyDailyHoroscope.fromMap(Map<String, dynamic> data, {required String dateKey}) {
    return FamilyDailyHoroscope(
      dateKey: '${data['dateKey'] ?? dateKey}',
      motherSign: '${data['motherSign'] ?? ''}',
      fatherSign: '${data['fatherSign'] ?? ''}',
      babySign: '${data['babySign'] ?? ''}',
      motherText: '${data['motherText'] ?? ''}',
      fatherText: '${data['fatherText'] ?? ''}',
      babyText: '${data['babyText'] ?? ''}',
      familyCompatibilityText: '${data['familyCompatibilityText'] ?? ''}',
      familyAdviceText: '${data['familyAdviceText'] ?? ''}',
      generatedByAi: data['generatedByAi'] == true,
    );
  }
}
