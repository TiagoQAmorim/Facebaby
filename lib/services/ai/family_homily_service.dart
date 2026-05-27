import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../controllers/current_baby_controller.dart';
import '../../i18n/app_i18n.dart';
import '../family_homily_read_prefs.dart';
import '../firebase/profile_cloud_sync.dart';
import '../premium/feature_access.dart';
import '../premium/premium_service.dart';

/// Garante homilia do dia em cache (uma chamada por vez).
abstract final class FamilyHomilyBootstrap {
  FamilyHomilyBootstrap._();

  static Future<void>? _ensureFuture;

  static Future<void> ensureToday({required String languageCode}) {
    if (!FeatureAccess.canUseAiFamilyHomily) {
      return Future<void>.value();
    }
    return _ensureFuture ??= _runEnsureToday(languageCode: languageCode)
        .whenComplete(() {
      _ensureFuture = null;
    });
  }

  static Future<void> _runEnsureToday({required String languageCode}) async {
    try {
      await FamilyHomilyReadPrefs.clearIfNewDay();
      final svc = FamilyHomilyService();
      final cached = await svc.loadTodayCached();
      if (cached != null && cached.homilyText.trim().isNotEmpty) {
        await FamilyHomilyUnreadBadge.refresh();
        return;
      }
      await PremiumService.instance.syncPremiumFromFirestore();
      final motherId =
          CurrentBabyController.instance.currentMotherRow?['id'] as int?;
      if (motherId != null) {
        await ProfileCloudSync.pushMother(motherId);
      }
      await svc.generateToday(languageCode: languageCode);
      await FamilyHomilyUnreadBadge.refresh();
    } catch (_) {
      await FamilyHomilyUnreadBadge.refresh();
    }
  }
}

/// Homilia diária via `generateDailyFamilyHomily` + cache Firestore.
class FamilyHomilyService {
  FamilyHomilyService({
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

  String _todayKey() => DateFormat('yyyyMMdd').format(DateTime.now());

  DocumentReference<Map<String, dynamic>>? get _todayDoc {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return null;
    return _firestore
        .collection('family_homilies')
        .doc(uid)
        .collection('daily')
        .doc(_todayKey());
  }

  Future<FamilyDailyHomily?> loadTodayCached() async {
    final ref = _todayDoc;
    if (ref == null) return null;
    final snap = await ref.get();
    if (!snap.exists) return null;
    return FamilyDailyHomily.fromMap(snap.data() ?? {}, dateKey: _todayKey());
  }

  Stream<FamilyDailyHomily?> watchToday() {
    final ref = _todayDoc;
    if (ref == null) return Stream.value(null);
    return ref.snapshots().map((snap) {
      if (!snap.exists) return null;
      return FamilyDailyHomily.fromMap(snap.data() ?? {}, dateKey: _todayKey());
    });
  }

  Map<String, dynamic> buildProfilePayload() {
    final mother = CurrentBabyController.instance.currentMotherRow;
    final baby = CurrentBabyController.instance.currentBabyRow;
    final payload = <String, dynamic>{};

    if (mother != null) {
      final name = '${mother['name'] ?? ''}'.trim();
      if (name.isNotEmpty) payload['motherName'] = name;
    }

    if (baby != null) {
      final name = '${baby['name'] ?? ''}'.trim();
      if (name.isNotEmpty) payload['babyName'] = name;
    }

    return payload;
  }

  Future<FamilyDailyHomily> generateToday({
    bool forceRefresh = false,
    required String languageCode,
  }) async {
    try {
      final profile = buildProfilePayload();
      final result = await _functions
          .httpsCallable('generateDailyFamilyHomily')
          .call<Map<String, dynamic>>({
        'forceRefresh': forceRefresh,
        'languageCode': languageCode,
        if (profile.isNotEmpty) 'profile': profile,
      });
      return FamilyDailyHomily.fromMap(
        Map<String, dynamic>.from(result.data),
        dateKey: _todayKey(),
      );
    } on FirebaseFunctionsException catch (e) {
      throw FamilyHomilyException(
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

class FamilyHomilyException implements Exception {
  const FamilyHomilyException(this.code, {this.serverMessage});

  final String code;
  final String? serverMessage;

  @override
  String toString() => code;
}

class FamilyDailyHomily {
  const FamilyDailyHomily({
    required this.dateKey,
    required this.liturgicalDay,
    required this.feastOrMemorial,
    required this.gospelReference,
    required this.homilyText,
    required this.familyReflection,
    this.generatedByAi = true,
  });

  final String dateKey;
  final String liturgicalDay;
  final String feastOrMemorial;
  final String gospelReference;
  final String homilyText;
  final String familyReflection;
  final bool generatedByAi;

  factory FamilyDailyHomily.fromMap(
    Map<String, dynamic> data, {
    required String dateKey,
  }) {
    return FamilyDailyHomily(
      dateKey: '${data['dateKey'] ?? dateKey}',
      liturgicalDay: '${data['liturgicalDay'] ?? ''}',
      feastOrMemorial: '${data['feastOrMemorial'] ?? ''}',
      gospelReference: '${data['gospelReference'] ?? ''}',
      homilyText: '${data['homilyText'] ?? ''}',
      familyReflection: '${data['familyReflection'] ?? ''}',
      generatedByAi: data['generatedByAi'] == true,
    );
  }
}
