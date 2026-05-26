import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../theme/app_theme.dart';
import 'app_date_picker.dart';
import 'input_formatters.dart';

/// Limite superior do calendário de nascimento do bebé (parto previsto / gestação).
DateTime babyBirthDateLastAllowed([DateTime? reference]) {
  final now = reference ?? DateTime.now();
  return DateTime(now.year + 2, now.month, now.day);
}

Future<DateTime?> _showBrCalendar(
  BuildContext context, {
  required DateTime initial,
  required DateTime first,
  required DateTime last,
  String? helpText,
}) {
  return showAppDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first,
    lastDate: last,
    initialEntryMode: DatePickerEntryMode.calendar,
    helpText: helpText,
  );
}

/// Seletor de data com digitação `dd/mm/aaaa` (barras automáticas) + calendário.
///
/// Com [calendarFirst], abre o calendário Material de imediato; se o utilizador
/// cancelar, mostra o painel de digitação manual como alternativa.
Future<DateTime?> showBrDatePicker(
  BuildContext context, {
  required DateTime initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? title,
  bool calendarFirst = false,
}) async {
  final s = S.of(context);
  final first = DateTime(firstDate.year, firstDate.month, firstDate.day);
  final last = DateTime(lastDate.year, lastDate.month, lastDate.day);
  var initial = DateTime(initialDate.year, initialDate.month, initialDate.day);
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;

  if (calendarFirst) {
    final cal = await _showBrCalendar(
      context,
      initial: initial,
      first: first,
      last: last,
      helpText: title,
    );
    if (cal != null) {
      return DateTime(cal.year, cal.month, cal.day);
    }
    if (!context.mounted) return null;
  }

  final ctrl = TextEditingController(text: formatBrDate(initial));

  final picked = await showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) {
      final bottom = MediaQuery.viewInsetsOf(ctx).bottom;
      return Padding(
        padding: EdgeInsets.fromLTRB(20, 8, 20, 20 + bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black26,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            if (title != null && title.isNotEmpty)
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF163B68),
                ),
              ),
            if (title != null && title.isNotEmpty) const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              autofocus: !calendarFirst,
              keyboardType: TextInputType.number,
              inputFormatters: const [DateBrMaskFormatter()],
              decoration: InputDecoration(
                labelText: s.brDateHint,
                hintText: 'dd/mm/aaaa',
                prefixIcon: const Icon(Icons.calendar_today_outlined),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () async {
                  final cal = await _showBrCalendar(
                    ctx,
                    initial: parseBrDateString(ctrl.text) ?? initial,
                    first: first,
                    last: last,
                    helpText: title,
                  );
                  if (cal != null) {
                    ctrl.text = formatBrDate(cal);
                  }
                },
                icon: const Icon(Icons.event_outlined),
                label: Text(s.brDateOpenCalendar),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () {
                final parsed = parseBrDateString(ctrl.text);
                if (parsed == null) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(s.valBirthDateInvalid)),
                  );
                  return;
                }
                final day = DateTime(parsed.year, parsed.month, parsed.day);
                if (day.isBefore(first) || day.isAfter(last)) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text(s.valBirthDateInvalid)),
                  );
                  return;
                }
                Navigator.pop(ctx, day);
              },
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.ctaPrimary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
              ),
              child: Text(s.onb('Continue')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel),
            ),
          ],
        ),
      );
    },
  );

  ctrl.dispose();
  return picked;
}
