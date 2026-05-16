import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/portal_layout.dart';

class SectionTitle extends StatelessWidget {
  final String title;
  final Widget? action;
  final Color? titleColor;

  const SectionTitle({
    super.key,
    required this.title,
    this.action,
    this.titleColor,
  });

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
              color: titleColor ?? AppTheme.textSecondary,
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
