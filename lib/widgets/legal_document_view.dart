import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../utils/legal_text_format.dart';
import '../utils/portal_layout.dart';

/// Apresenta texto legal com título, linhas meta, parágrafos e listas com marcadores.
class LegalDocumentView extends StatelessWidget {
  const LegalDocumentView({
    super.key,
    required this.rawText,
  });

  final String rawText;

  @override
  Widget build(BuildContext context) {
    final processed = preprocessLegalPlainText(rawText);
    final blocks = processed.split(RegExp(r'\n\s*\n')).map((s) => s.trim()).where((s) => s.isNotEmpty).toList();

    final titleStyle = TextStyle(
      fontSize: portalSp(context, 20),
      fontWeight: FontWeight.w900,
      height: 1.25,
      letterSpacing: -0.4,
      color: AppTheme.textPrimary,
    );
    final metaStyle = TextStyle(
      fontSize: portalSp(context, 13.5),
      fontWeight: FontWeight.w600,
      height: 1.35,
      color: AppTheme.textMuted.withAlpha(235),
    );
    final bodyStyle = TextStyle(
      fontSize: portalSp(context, 15),
      fontWeight: FontWeight.w500,
      height: 1.55,
      color: AppTheme.textPrimary,
    );
    final sectionLeadStyle = bodyStyle.copyWith(fontWeight: FontWeight.w800);
    final bulletStyle = bodyStyle;

    final children = <Widget>[];

    void gap(double h) => children.add(SizedBox(height: portalSp(context, h)));

    for (var i = 0; i < blocks.length; i++) {
      final block = blocks[i];
      if (i == 0) {
        children.add(SelectableText(block, style: titleStyle));
        gap(14);
        continue;
      }

      if (legalBlockLooksLikeMeta(block)) {
        children.add(SelectableText(block, style: metaStyle));
        gap(12);
        continue;
      }

      final rawLines = block.split('\n');
      final firstBulletIdx = rawLines.indexWhere(legalLineLooksLikeBullet);

      if (firstBulletIdx >= 0) {
        final header = rawLines.sublist(0, firstBulletIdx).join('\n').trim();
        final bulletLines = rawLines.sublist(firstBulletIdx).where((l) => l.trim().isNotEmpty).toList();

        if (header.isNotEmpty) {
          children.add(SelectableText(header, style: sectionLeadStyle));
          gap(8);
        }
        for (final line in bulletLines) {
          children.add(Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: EdgeInsets.only(top: portalSp(context, 6)),
                  child: Text('•', style: bulletStyle),
                ),
                SizedBox(width: portalSp(context, 8)),
                Expanded(
                  child: SelectableText(
                    line.replaceFirst(RegExp(r'^[-•·]\s*'), '').trim(),
                    style: bulletStyle,
                  ),
                ),
              ],
            ),
          ));
        }
        gap(10);
        continue;
      }

      children.add(SelectableText(block, style: bodyStyle));
      gap(14);
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
