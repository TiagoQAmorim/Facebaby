import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

const _rulerInk = Color(0xFF163B68);

/// Arrasto horizontal (px) para percorrer min→max. Valor maior = régua mais lenta.
const _rulerDragPixelsPerFullRange = 1450.0;

/// Ruler for weight/height used in onboarding and in the portal (growth, etc.).
class GrowthRulerPicker extends StatefulWidget {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final String unit;
  final int decimalDigits;
  final IconData icon;
  final String? subjectLabel;
  final String dragHint;
  final List<String> unitOptions;
  final String? selectedUnit;
  final ValueChanged<String>? onUnitSelected;
  final ValueChanged<double> onChanged;

  /// When `true`, opening at the maximum snaps to [min] (onboarding newborn weight).
  final bool snapStartToZeroWhenAtMax;

  const GrowthRulerPicker({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.unit,
    required this.decimalDigits,
    required this.icon,
    this.subjectLabel,
    required this.dragHint,
    this.unitOptions = const [],
    this.selectedUnit,
    this.onUnitSelected,
    required this.onChanged,
    this.snapStartToZeroWhenAtMax = true,
  });

  @override
  State<GrowthRulerPicker> createState() => _GrowthRulerPickerState();
}

class _GrowthRulerUnitBar extends StatelessWidget {
  final List<String> options;
  final String selected;
  final ValueChanged<String>? onSelected;

  const _GrowthRulerUnitBar({
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F1F8),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final option in options)
            GestureDetector(
              onTap: onSelected == null ? null : () => onSelected!(option),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOutCubic,
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: selected == option ? Colors.white : Colors.transparent,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: selected == option
                      ? [
                          BoxShadow(
                            color: Colors.black.withAlpha(14),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  option,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                    color: selected == option
                        ? AppTheme.ctaPrimary
                        : _rulerInk,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GrowthRulerPickerState extends State<GrowthRulerPicker> {
  late double _liveValue;

  @override
  void initState() {
    super.initState();
    _liveValue = _initialValue(widget.value);
    if (_liveValue != widget.value) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) widget.onChanged(_liveValue);
      });
    }
  }

  @override
  void didUpdateWidget(covariant GrowthRulerPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _liveValue = widget.snapStartToZeroWhenAtMax
          ? _initialValue(widget.value)
          : widget.value.clamp(widget.min, widget.max).toDouble();
    }
  }

  bool get _usesMetersLabel => widget.unit == 'cm' && _liveValue >= 100;

  String get _label {
    if (_usesMetersLabel) {
      final centimeters = _liveValue.round();
      final meters = centimeters ~/ 100;
      final remainingCm = centimeters % 100;
      return remainingCm == 0 ? '$meters m' : '$meters m $remainingCm cm';
    }
    return _liveValue.toStringAsFixed(widget.decimalDigits);
  }

  double _initialValue(double value) {
    final clamped = value.clamp(widget.min, widget.max).toDouble();
    if (!widget.snapStartToZeroWhenAtMax) return clamped;
    final step = widget.divisions <= 0
        ? 0.0
        : (widget.max - widget.min) / widget.divisions;
    final isAtMax = (clamped - widget.max).abs() <= step;
    if (widget.min == 0 && isAtMax) return widget.min;
    return clamped;
  }

  void _commit(double value) {
    final step = widget.divisions <= 0
        ? 0.0
        : (widget.max - widget.min) / widget.divisions;
    final rounded = step <= 0
        ? value
        : widget.min + ((value - widget.min) / step).round() * step;
    final next = rounded.clamp(widget.min, widget.max).toDouble();
    setState(() => _liveValue = next);
    widget.onChanged(next);
  }

  void _dragBy(double deltaDx) {
    final sensitivity =
        (widget.max - widget.min) / _rulerDragPixelsPerFullRange;
    final next = (_liveValue - deltaDx * sensitivity)
        .clamp(widget.min, widget.max)
        .toDouble();
    setState(() => _liveValue = next);
  }

  String? get _subjectTrimmed {
    final t = widget.subjectLabel?.trim();
    return (t == null || t.isEmpty) ? null : t;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        children: [
          if (widget.unitOptions.isNotEmpty)
            Center(
              child: _GrowthRulerUnitBar(
                options: widget.unitOptions,
                selected: widget.selectedUnit ?? widget.unit,
                onSelected: widget.onUnitSelected,
              ),
            ),
          const SizedBox(height: 28),
          Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(left: 16),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (_subjectTrimmed != null) ...[
                            Text(
                              _subjectTrimmed!.toLowerCase(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFE15A72),
                              ),
                            ),
                            const SizedBox(height: 2),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                _label,
                                style: TextStyle(
                                  fontSize: _usesMetersLabel ? 34 : 44,
                                  height: 0.95,
                                  letterSpacing:
                                      _usesMetersLabel ? -0.8 : -1.6,
                                  fontWeight: FontWeight.w900,
                                  color: _rulerInk,
                                ),
                              ),
                              if (!_usesMetersLabel) ...[
                                const SizedBox(width: 8),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 5),
                                  child: Text(
                                    widget.unit,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      color: _rulerInk,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onHorizontalDragUpdate: (details) =>
                        _dragBy(details.delta.dx),
                    onHorizontalDragEnd: (_) {
                      _commit(_liveValue);
                    },
                    child: SizedBox(
                      height: 112,
                      child: CustomPaint(
                        painter: _GrowthRulerTicksPainter(
                          value: _liveValue,
                          min: widget.min,
                          max: widget.max,
                          divisions: widget.divisions,
                          color: _rulerInk.withAlpha(105),
                          decimalDigits: widget.decimalDigits,
                        ),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  ),
                ],
              ),
              Positioned(
                left: 0,
                top: 0,
                bottom: 8,
                child: IgnorePointer(
                  child: Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF5C72),
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Text(
            widget.dragHint,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _rulerInk,
            ),
          ),
        ],
      ),
    );
  }
}

class _GrowthRulerTicksPainter extends CustomPainter {
  final double value;
  final double min;
  final double max;
  final int divisions;
  final Color color;
  final int decimalDigits;

  const _GrowthRulerTicksPainter({
    required this.value,
    required this.min,
    required this.max,
    required this.divisions,
    required this.color,
    required this.decimalDigits,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final tickPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = color
      ..strokeWidth = 1.1;
    final majorPaint = Paint()
      ..strokeCap = StrokeCap.round
      ..color = _rulerInk.withAlpha(145)
      ..strokeWidth = 1.4;
    final range = max - min;
    if (range <= 0 || size.width <= 0) return;
    final safeDivisions = divisions <= 0 ? 1 : divisions;
    final minorStep = range / safeDivisions;
    final pixelsPerUnit = range <= 10
        ? 72.0
        : range <= 25
            ? 36.0
            : range <= 100
                ? 8.0
                : 2.8;
    final majorInterval = range <= 10
        ? 1.0
        : range <= 25
            ? 2.0
            : range <= 100
                ? 10.0
                : 50.0;

    /// Poucas marcas pequenas entre os números grandes (ilustrativo).
    const maxMinorTicks = 32;
    final minorStride = safeDivisions <= maxMinorTicks
        ? 1
        : math.max(1, (safeDivisions / maxMinorTicks).ceil());

    for (var i = 0; i <= safeDivisions; i++) {
      final tickValue = min + minorStep * i;
      final x = (tickValue - value) * pixelsPerUnit;
      if (x < -10 || x > size.width + 10) continue;
      final majorRatio = tickValue / majorInterval;
      final isMajor = (majorRatio - majorRatio.round()).abs() < 0.01;
      if (!isMajor) {
        if (i % minorStride != 0) continue;
      }
      final h = isMajor ? 38.0 : 22.0;
      canvas.drawLine(
        Offset(x, size.height - h),
        Offset(x, size.height - 8),
        isMajor ? majorPaint : tickPaint,
      );
      if (isMajor) {
        final label = tickValue.toStringAsFixed(0);
        final tp = TextPainter(
          text: TextSpan(
            text: label,
            style: TextStyle(
              color: _rulerInk.withAlpha(160),
              fontSize: 14,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final labelX = (x - tp.width / 2).clamp(0.0, size.width - tp.width);
        tp.paint(canvas, Offset(labelX, size.height - h - 27));
      }
    }
  }

  @override
  bool shouldRepaint(covariant _GrowthRulerTicksPainter oldDelegate) {
    return oldDelegate.value != value ||
        oldDelegate.min != min ||
        oldDelegate.max != max ||
        oldDelegate.divisions != divisions ||
        oldDelegate.color != color ||
        oldDelegate.decimalDigits != decimalDigits;
  }
}
