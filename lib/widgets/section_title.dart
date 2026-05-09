import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/portal_layout.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;

  const SectionTitle({super.key, required this.title, this.action});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 2,
            softWrap: true,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: portalSp(context, 22),
              fontWeight: FontWeight.w800,
              color: AppTheme.textSecondary.withAlpha(235),
              height: 1.2,
            ),
          ),
        ),
        const SizedBox(width: 10),
        if (action != null) Align(alignment: Alignment.centerRight, child: action!),
      ],
    );
  }
}
