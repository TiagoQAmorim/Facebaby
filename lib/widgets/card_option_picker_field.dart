import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Opção para [CardOptionPickerField].
class CardOption<T> {
  final T value;
  final String label;

  const CardOption({required this.value, required this.label});
}

/// Campo que abre bottom sheet opaco (evita dropdown transparente no portal noturno).
class CardOptionPickerField<T> extends StatelessWidget {
  const CardOptionPickerField({
    super.key,
    required this.label,
    required this.sheetTitle,
    required this.options,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String sheetTitle;
  final List<CardOption<T>> options;
  final T? value;
  final ValueChanged<T> onChanged;

  static const TextStyle _valueStyle = TextStyle(
    color: AppTheme.textPrimary,
    fontWeight: FontWeight.w600,
    fontSize: 16,
  );

  String? _labelFor(T? v) {
    if (v == null) return null;
    for (final o in options) {
      if (o.value == v) return o.label;
    }
    return null;
  }

  Future<void> _openSheet(BuildContext context) async {
    final picked = await showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppTheme.card,
      barrierColor: Colors.black54,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) {
        final maxH = MediaQuery.sizeOf(sheetCtx).height * 0.5;
        return SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                child: Text(
                  sheetTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 17,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              Flexible(
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxH),
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: options.length,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.black.withAlpha(18),
                    ),
                    itemBuilder: (_, index) {
                      final o = options[index];
                      final selected = value == o.value;
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(horizontal: 16),
                        title: Text(
                          o.label,
                          style: TextStyle(
                            fontWeight:
                                selected ? FontWeight.w900 : FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        trailing: selected
                            ? const Icon(Icons.check_circle,
                                color: AppTheme.ctaPrimary)
                            : null,
                        onTap: () => Navigator.of(sheetCtx).pop(o.value),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final selectedLabel = _labelFor(value);
    return Material(
      color: AppTheme.card,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _openSheet(context),
        child: InputDecorator(
          decoration: InputDecoration(
            filled: true,
            fillColor: AppTheme.card,
            labelText: label,
            labelStyle: const TextStyle(color: AppTheme.textSecondary),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.black.withAlpha(28)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: Colors.black.withAlpha(28)),
            ),
            focusedBorder: const OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(14)),
              borderSide: BorderSide(color: AppTheme.primary, width: 2),
            ),
          ),
          isEmpty: selectedLabel == null,
          child: Row(
            children: [
              Expanded(
                child: selectedLabel == null
                    ? const SizedBox.shrink()
                    : Text(
                        selectedLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: _valueStyle,
                      ),
              ),
              const Icon(Icons.arrow_drop_down,
                  color: AppTheme.textSecondary),
            ],
          ),
        ),
      ),
    );
  }
}
