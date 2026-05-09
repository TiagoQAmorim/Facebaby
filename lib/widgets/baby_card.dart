import 'package:flutter/material.dart';
import '../models/baby.dart';
import '../theme/app_theme.dart';
import '../utils/portal_layout.dart';
import 'card_box.dart';
import 'photo_avatar.dart';

class BabyCard extends StatelessWidget {
  final Baby baby;

  const BabyCard({super.key, required this.baby});

  @override
  Widget build(BuildContext context) {
    final bg = baby.sex == 'M' ? const Color(0xFFD6EBFF) : const Color(0xFFFFDCE8);
    return CardBox(
      child: Row(
        children: [
          PhotoAvatar(
            photoB64: baby.photoB64,
            photoUrl: baby.photoUrl,
            radius: 34,
            backgroundColor: bg,
            fallback: Text(baby.avatar, style: const TextStyle(fontSize: 30)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  baby.name,
                  maxLines: 3,
                  softWrap: true,
                  style: TextStyle(fontSize: portalSp(context, 20), fontWeight: FontWeight.w700, height: 1.2),
                ),
                Text(
                  baby.ageLabel,
                  maxLines: 2,
                  softWrap: true,
                  style: TextStyle(color: const Color(0xFF6D6476), fontSize: portalSp(context, 14)),
                ),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: .62,
                  minHeight: 8,
                  borderRadius: BorderRadius.circular(99),
                  color: AppTheme.secondary,
                  backgroundColor: bg,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
