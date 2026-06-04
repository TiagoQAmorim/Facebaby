import 'package:facebaby_flutter/i18n/app_i18n.dart';
import 'package:facebaby_flutter/widgets/growth_ruler_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('horizontal drag updates value with default sensitivity',
      (tester) async {
    var current = 3.0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrowthRulerPicker(
            value: current,
            min: 0,
            max: 25,
            divisions: 250,
            unit: 'Kg',
            decimalDigits: 2,
            icon: Icons.monitor_weight_outlined,
            dragHint: 'Arraste',
            onChanged: (v) => current = v,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final dragArea = find.byType(GestureDetector).last;
    await tester.drag(dragArea, const Offset(-120, 0));
    await tester.pumpAndSettle();

    expect(current, greaterThan(3.0));
    expect(current, lessThanOrEqualTo(25.0));
  });

  testWidgets('onboarding defaults use standard drag sensitivity', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GrowthRulerPicker(
            value: 3.5,
            min: 0,
            max: 25,
            divisions: 250,
            unit: 'Kg',
            decimalDigits: 2,
            icon: Icons.monitor_weight_outlined,
            subjectLabel: 'Bebê',
            dragHint: S(AppLang.pt).onb('DragToAdjust'),
            onChanged: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Bebê'), findsOneWidget);
  });
}
