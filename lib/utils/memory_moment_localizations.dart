import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Data/hora longa para detalhe e cartão de partilha de memórias (respeita o locale da app).
String formatMemoryMomentDateTime(BuildContext context, DateTime dt) {
  final tag = Localizations.localeOf(context).toLanguageTag();
  try {
    final dateFmt = DateFormat.yMMMMd(tag);
    final timeFmt = DateFormat.Hm(tag);
    return '${dateFmt.format(dt)} • ${timeFmt.format(dt)}';
  } catch (_) {
    final dateFmt = DateFormat.yMMMMd('en_US');
    final timeFmt = DateFormat.Hm('en_US');
    return '${dateFmt.format(dt)} • ${timeFmt.format(dt)}';
  }
}
