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

  int _nextNonEmptyLineIndex(List<String> lines, int from) {
    for (var i = from; i < lines.length; i++) {
      if (lines[i].trim().isNotEmpty) return i;
    }
    return -1;
  }

  bool _nextLineStartsBullet(List<String> lines, int from) {
    final idx = _nextNonEmptyLineIndex(lines, from);
    if (idx < 0) return false;
    return legalLineLooksLikeBullet(lines[idx].trim());
  }

  bool _lineIsSubsectionTitle(List<String> lines, int index) {
    final line = lines[index].trim();
    if (!legalLineLooksLikeSubsectionTitle(line)) return false;
    return _nextLineStartsBullet(lines, index + 1);
  }

  @override
  Widget build(BuildContext context) {
    final lines = preprocessLegalPlainText(rawText).split('\n');

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
    final sectionTitleStyle = TextStyle(
      fontSize: portalSp(context, 16.5),
      fontWeight: FontWeight.w900,
      height: 1.35,
      color: AppTheme.textPrimary,
    );
    final subsectionTitleStyle = TextStyle(
      fontSize: portalSp(context, 15.5),
      fontWeight: FontWeight.w800,
      height: 1.35,
      color: AppTheme.textPrimary,
    );
    final bodyStyle = TextStyle(
      fontSize: portalSp(context, 15),
      fontWeight: FontWeight.w500,
      height: 1.55,
      color: AppTheme.textPrimary,
    );
    final bulletStyle = bodyStyle;

    final children = <Widget>[];

    void gap(double h) => children.add(SizedBox(height: portalSp(context, h)));

    Widget bulletLine(String line) {
      return Padding(
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
      );
    }

    var documentTitleDone = false;
    var metaDone = false;
    var sectionCount = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isEmpty) continue;

      if (!documentTitleDone) {
        children.add(SelectableText(line, style: titleStyle));
        documentTitleDone = true;
        gap(14);
        continue;
      }

      if (!metaDone && legalBlockLooksLikeMeta(line)) {
        children.add(SelectableText(line, style: metaStyle));
        metaDone = true;
        gap(18);
        continue;
      }

      if (legalLineLooksLikeNumberedSection(line)) {
        if (sectionCount > 0) gap(16);
        sectionCount++;
        children.add(SelectableText(line, style: sectionTitleStyle));
        gap(12);
        continue;
      }

      if (legalLineLooksLikeBullet(line)) {
        while (i < lines.length) {
          final bullet = lines[i].trim();
          if (bullet.isEmpty) {
            i++;
            continue;
          }
          if (!legalLineLooksLikeBullet(bullet)) break;
          children.add(bulletLine(bullet));
          i++;
        }
        i--;
        gap(12);
        continue;
      }

      if (_lineIsSubsectionTitle(lines, i)) {
        gap(10);
        children.add(SelectableText(line, style: subsectionTitleStyle));
        gap(10);
        continue;
      }

      final para = StringBuffer(line);
      while (i + 1 < lines.length) {
        final next = lines[i + 1].trim();
        if (next.isEmpty) break;
        if (legalLineLooksLikeNumberedSection(next)) break;
        if (legalLineLooksLikeBullet(next)) break;
        if (_lineIsSubsectionTitle(lines, i + 1)) break;
        i++;
        para.write(' ');
        para.write(lines[i].trim());
      }
      children.add(SelectableText(para.toString(), style: bodyStyle));
      gap(12);
    }

    return SelectionArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}
