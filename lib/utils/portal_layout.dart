import 'package:flutter/material.dart';

/// Multiplier for typography: ~1.0 on tablets/wide phones, down to ~0.68 on very narrow screens.
double portalWidthFactor(BuildContext context) {
  final w = MediaQuery.sizeOf(context).width;
  const minW = 260.0;
  const maxW = 560.0;
  const minF = 0.68;
  const maxF = 1.0;
  if (w <= minW) return minF;
  if (w >= maxW) return maxF;
  return minF + (w - minW) / (maxW - minW) * (maxF - minF);
}

/// Base logical font size (clamped). Actual rendering uses [portalTypographyScaler]:
/// narrower screen ⇒ smaller effective size (before OS accessibility scaling).
double portalSp(BuildContext context, double base) => base.clamp(10.0, 120.0);

/// Applies OS text scaling with sane bounds, after shrinking by screen width.
TextScaler portalTypographyScaler(BuildContext context) {
  final wf = portalWidthFactor(context);
  final inner = MediaQuery.textScalerOf(context).clamp(
        minScaleFactor: 0.82,
        maxScaleFactor: 1.22,
      );
  return _WidthFirstTextScaler(widthFactor: wf, inner: inner);
}

/// Multiplies the developer `fontSize` by screen [widthFactor], then applies [inner] (a11y) scaling.
final class _WidthFirstTextScaler extends TextScaler {
  // ignore: prefer_const_constructors_in_immutables — [inner] comes from MediaQuery at runtime.
  _WidthFirstTextScaler({required this.widthFactor, required this.inner});

  final double widthFactor;
  final TextScaler inner;

  @override
  double scale(double fontSize) {
    assert(fontSize >= 0);
    assert(fontSize.isFinite);
    return inner.scale(fontSize * widthFactor);
  }

  @override
  // Required by [TextScaler]; estimate ok for our compose scaler.
  // ignore: deprecated_member_use
  double get textScaleFactor => inner.textScaleFactor * widthFactor;

  @override
  bool operator ==(Object other) =>
      other is _WidthFirstTextScaler && other.widthFactor == widthFactor && other.inner == inner;

  @override
  int get hashCode => Object.hash(widthFactor, inner);

  @override
  String toString() => 'width($widthFactor) -> $inner';
}
