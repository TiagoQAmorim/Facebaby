import 'dart:async' show StreamSubscription;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../services/firebase/firestore_service.dart';
import '../services/home_prefs.dart';
import '../utils/weekly_photo_spotlight_visibility.dart';
import '../widgets/weekly_photo_crown_icon.dart';

/// Mostra um diálogo de parabéns à mãe cujo `userId` coincide com o vencedor em `spotlight_current`
/// (uma vez por `week_id`, guardado em [HomePrefs]).
class WeeklyPhotoWinnerCongratsHost extends StatefulWidget {
  const WeeklyPhotoWinnerCongratsHost({super.key});

  @override
  State<WeeklyPhotoWinnerCongratsHost> createState() => _WeeklyPhotoWinnerCongratsHostState();
}

class _WeeklyPhotoWinnerCongratsHostState extends State<WeeklyPhotoWinnerCongratsHost> {
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _sub;
  bool _dialogOpen = false;

  @override
  void initState() {
    super.initState();
    if (kIsWeb) return;
    _sub = FirestoreService.instance.weeklyPhotoSpotlightSnapshots().listen(_onSpotlight);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _onSpotlight(DocumentSnapshot<Map<String, dynamic>> snap) async {
    if (!mounted || _dialogOpen || kIsWeb) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final d = snap.data();
    if (d == null) return;

    final weekId = (d['week_id'] as String?)?.trim();
    if (weekId == null || weekId.isEmpty) return;

    final winnerUid = (d['winner_user_id'] as String?)?.trim();
    if (winnerUid == null || winnerUid.isEmpty || winnerUid != uid) return;

    final now = DateTime.now();
    if (!WeeklyPhotoSpotlightVisibility.shouldShowForBanner(d, now)) return;

    final acked = await HomePrefs.getWeeklyWinnerCongratsAckWeek();
    if (acked == weekId) return;

    if (!mounted) return;
    _dialogOpen = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        final s = S.of(ctx);
        return AlertDialog(
          title: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const WeeklyPhotoCrownIcon(size: 30),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  s.weeklyPhotoWinnerCongratsTitle,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Text(s.weeklyPhotoWinnerCongratsBody, style: const TextStyle(height: 1.4)),
          ),
          actions: [
            FilledButton(
              onPressed: () async {
                await HomePrefs.setWeeklyWinnerCongratsAckWeek(weekId);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(s.weeklyPhotoWinnerCongratsOk),
            ),
          ],
        );
      },
    );

    _dialogOpen = false;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
