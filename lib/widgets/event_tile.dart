import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'card_box.dart';

class EventTile extends StatelessWidget {
  final String title;
  final String subtitle;

  const EventTile({super.key, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: CardBox(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Color(0xFFEFE8FF),
              child: Icon(Icons.calendar_month, color: AppTheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, maxLines: 3, softWrap: true, style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text(subtitle, maxLines: 4, softWrap: true, style: const TextStyle(color: Color(0xFF6D6476))),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    );
  }
}
