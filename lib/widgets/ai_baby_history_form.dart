import 'package:flutter/material.dart';

import '../i18n/app_i18n.dart';
import '../models/ai/ai_profile_model.dart';
import '../services/ai/ai_profile_service.dart';
import '../theme/app_theme.dart';

/// Formulário reutilizável do histórico para a IA Babá.
class AiBabyHistoryForm extends StatefulWidget {
  const AiBabyHistoryForm({
    super.key,
    this.controller,
    this.initialText = '',
    this.embedded = false,
    this.showActions = true,
    this.showSubtitle = true,
    this.compact = false,
    this.onSaved,
    this.onCleared,
  });

  final TextEditingController? controller;
  final String initialText;

  /// Sem botões de salvar/limpar (ex.: onboarding salva ao avançar).
  final bool embedded;
  final bool showActions;
  final bool showSubtitle;
  final bool compact;
  final VoidCallback? onSaved;
  final VoidCallback? onCleared;

  @override
  State<AiBabyHistoryForm> createState() => _AiBabyHistoryFormState();
}

class _AiBabyHistoryFormState extends State<AiBabyHistoryForm> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController(text: widget.initialText);
  final _service = AiProfileService();
  bool _busy = false;
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    if (_ownsController && widget.initialText.isEmpty && !widget.embedded) {
      _loadFromServer();
    }
  }

  Future<void> _loadFromServer() async {
    try {
      final profile = await _service.load();
      if (!mounted || profile.aiHistory.isEmpty) return;
      _controller.text = profile.aiHistory;
      setState(() {});
    } catch (_) {}
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    super.dispose();
  }

  int get _length => _controller.text.length;

  Future<void> _save(S s) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.saveHistory(_controller.text);
      widget.onSaved?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.aiBabyHistorySaved)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.commonCouldNotSave)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _clear(S s) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.aiBabyHistoryClearConfirmTitle),
        content: Text(s.aiBabyHistoryClearConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.aiBabyHistoryClear),
          ),
        ],
      ),
    );
    if (ok != true || _busy) return;

    setState(() => _busy = true);
    try {
      await _service.clearHistory();
      _controller.clear();
      widget.onCleared?.call();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.aiBabyHistoryCleared)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(s.commonCouldNotSave)),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final max = AiProfile.maxHistoryLength;
    final overLimit = _length > max;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (!widget.embedded && widget.showSubtitle) ...[
          Text(
            s.aiBabyHistorySubtitle,
            style: TextStyle(
              fontSize: 14,
              height: 1.4,
              color: Colors.black.withAlpha(170),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Text(
          s.aiBabyHistoryFieldLabel,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontSize: 14,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _controller,
          maxLength: max,
          maxLines: widget.embedded
              ? 6
              : (widget.compact ? 8 : 10),
          minLines: widget.embedded
              ? 4
              : (widget.compact ? 5 : 6),
          enabled: !_busy,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: s.aiBabyHistoryPlaceholder,
            hintStyle: TextStyle(
              fontSize: 13,
              color: Colors.black.withAlpha(110),
              height: 1.35,
            ),
            filled: true,
            fillColor: Colors.white.withAlpha(230),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.black.withAlpha(30)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.black.withAlpha(30)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: const BorderSide(color: AppTheme.primaryPink, width: 1.5),
            ),
            counterText: '',
          ),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: Text(
                s.aiBabyHistoryCharCount(_length, max),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: overLimit
                      ? Theme.of(context).colorScheme.error
                      : Colors.black.withAlpha(120),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Text(
          s.aiBabyHistoryDisclaimer,
          style: TextStyle(
            fontSize: 11.5,
            height: 1.35,
            fontStyle: FontStyle.italic,
            color: Colors.black.withAlpha(110),
          ),
        ),
        if (widget.showActions && !widget.embedded) ...[
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _busy || overLimit ? null : () => _save(s),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.ctaPrimary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: _busy
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(s.aiBabyHistorySave),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _busy ? null : () => _clear(s),
            child: Text(s.aiBabyHistoryClear),
          ),
        ],
      ],
    );
  }
}
