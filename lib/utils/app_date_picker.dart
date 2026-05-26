import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import 'input_formatters.dart';

/// Calendário Material com digitação `dd/mm/aaaa` (barras automáticas no modo texto).
Future<DateTime?> showAppDatePicker({
  required BuildContext context,
  DateTime? initialDate,
  required DateTime firstDate,
  required DateTime lastDate,
  String? helpText,
  DatePickerEntryMode initialEntryMode = DatePickerEntryMode.calendar,
  SelectableDayPredicate? selectableDayPredicate,
}) {
  final first = DateTime(firstDate.year, firstDate.month, firstDate.day);
  final last = DateTime(lastDate.year, lastDate.month, lastDate.day);
  var initial = initialDate != null
      ? DateTime(initialDate.year, initialDate.month, initialDate.day)
      : first;
  if (initial.isBefore(first)) initial = first;
  if (initial.isAfter(last)) initial = last;

  return showDialog<DateTime>(
    context: context,
    builder: (dialogContext) {
      return Localizations.override(
        context: dialogContext,
        locale: const Locale('pt', 'BR'),
        child: _AppDatePickerDialog(
          initialDate: initial,
          firstDate: first,
          lastDate: last,
          helpText: helpText,
          initialEntryMode: initialEntryMode,
          selectableDayPredicate: selectableDayPredicate,
        ),
      );
    },
  );
}

class _AppDatePickerDialog extends StatefulWidget {
  const _AppDatePickerDialog({
    required this.initialDate,
    required this.firstDate,
    required this.lastDate,
    this.helpText,
    required this.initialEntryMode,
    this.selectableDayPredicate,
  });

  final DateTime initialDate;
  final DateTime firstDate;
  final DateTime lastDate;
  final String? helpText;
  final DatePickerEntryMode initialEntryMode;
  final SelectableDayPredicate? selectableDayPredicate;

  @override
  State<_AppDatePickerDialog> createState() => _AppDatePickerDialogState();
}

class _AppDatePickerDialogState extends State<_AppDatePickerDialog> {
  late DateTime _selected;
  late DatePickerEntryMode _entryMode;
  late final TextEditingController _inputCtrl;
  final _formKey = GlobalKey<FormState>();
  String? _inputError;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDate;
    _entryMode = widget.initialEntryMode;
    _inputCtrl = TextEditingController(text: formatBrDate(_selected));
  }

  @override
  void dispose() {
    _inputCtrl.dispose();
    super.dispose();
  }

  bool _isSelectable(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    if (d.isBefore(widget.firstDate) || d.isAfter(widget.lastDate)) {
      return false;
    }
    final p = widget.selectableDayPredicate;
    return p == null || p(d);
  }

  void _syncInputFromSelected() {
    _inputCtrl.text = formatBrDate(_selected);
    _inputError = null;
  }

  void _toggleEntryMode() {
    setState(() {
      if (_entryMode == DatePickerEntryMode.calendar) {
        final parsed = parseBrDateString(_inputCtrl.text);
        if (parsed != null && _isSelectable(parsed)) {
          _selected = DateTime(parsed.year, parsed.month, parsed.day);
        }
        _entryMode = DatePickerEntryMode.input;
      } else {
        _entryMode = DatePickerEntryMode.calendar;
        _syncInputFromSelected();
      }
    });
  }

  String? _validateInput(String? _) {
    final parsed = parseBrDateString(_inputCtrl.text);
    if (parsed == null) {
      return S.of(context).valBirthDateInvalid;
    }
    final day = DateTime(parsed.year, parsed.month, parsed.day);
    if (!_isSelectable(day)) {
      return S.of(context).valBirthDateInvalid;
    }
    return null;
  }

  void _submit() {
    if (_entryMode == DatePickerEntryMode.input) {
      final err = _validateInput(_inputCtrl.text);
      if (err != null) {
        setState(() => _inputError = err);
        return;
      }
      final parsed = parseBrDateString(_inputCtrl.text)!;
      Navigator.pop(
        context,
        DateTime(parsed.year, parsed.month, parsed.day),
      );
      return;
    }
    Navigator.pop(context, _selected);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final datePickerTheme = theme.datePickerTheme;
    final colorScheme = theme.colorScheme;
    final localizations = MaterialLocalizations.of(context);

    final headerBg = datePickerTheme.headerBackgroundColor ?? colorScheme.primary;
    final headerFg = datePickerTheme.headerForegroundColor ?? colorScheme.onPrimary;

    return Dialog(
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: headerBg,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 8, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (widget.helpText != null &&
                              widget.helpText!.isNotEmpty)
                            Text(
                              widget.helpText!,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: headerFg.withValues(alpha: 0.85),
                              ),
                            ),
                          const SizedBox(height: 8),
                          Text(
                            formatBrDate(_selected),
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: headerFg,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: _toggleEntryMode,
                      icon: Icon(
                        _entryMode == DatePickerEntryMode.calendar
                            ? Icons.edit_outlined
                            : Icons.calendar_month_outlined,
                        color: headerFg,
                      ),
                      tooltip: _entryMode == DatePickerEntryMode.calendar
                          ? localizations.inputDateModeButtonLabel
                          : localizations.calendarModeButtonLabel,
                    ),
                  ],
                ),
              ),
            ),
            if (_entryMode == DatePickerEntryMode.calendar)
              CalendarDatePicker(
                initialDate: _selected,
                firstDate: widget.firstDate,
                lastDate: widget.lastDate,
                currentDate: DateTime.now(),
                selectableDayPredicate: widget.selectableDayPredicate,
                onDateChanged: (d) => setState(() {
                  _selected = DateTime(d.year, d.month, d.day);
                  _syncInputFromSelected();
                }),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 8),
                child: Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _inputCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: const [DateBrMaskFormatter()],
                    decoration: InputDecoration(
                      labelText: S.of(context).brDateHint,
                      hintText: 'dd/mm/aaaa',
                      errorText: _inputError,
                      prefixIcon: const Icon(Icons.event_outlined),
                    ),
                    validator: _validateInput,
                    onFieldSubmitted: (_) => _submit(),
                    onChanged: (_) {
                      if (_inputError != null) {
                        setState(() => _inputError = null);
                      }
                    },
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text(localizations.cancelButtonLabel),
                  ),
                  TextButton(
                    onPressed: _submit,
                    child: Text(localizations.okButtonLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
