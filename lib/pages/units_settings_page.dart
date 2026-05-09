import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';

import '../i18n/app_i18n.dart';
import '../services/measurement_units_prefs.dart';
import '../theme/app_theme.dart';
import '../utils/portal_layout.dart';

class UnitsSettingsPage extends StatelessWidget {
  const UnitsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(s.unitsTitle)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(AppTheme.pageHPadding, 16, AppTheme.pageHPadding, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                s.unitsIntro,
                style: TextStyle(fontSize: 13.5, height: 1.35, fontWeight: FontWeight.w600, color: Colors.black.withAlpha(150)),
              ),
              const SizedBox(height: 14),
              _UnitsCard<LengthUnit>(
                icon: Icons.straighten_rounded,
                title: s.unitsLengthTitle,
                subtitle: s.unitsLengthSubtitle,
                valueListenable: MeasurementUnitsPrefs.length,
                options: const [
                  _UnitOption(value: LengthUnit.cm, labelKey: _UnitsLabelKey.cm),
                  _UnitOption(value: LengthUnit.inch, labelKey: _UnitsLabelKey.inch),
                ],
                onChanged: MeasurementUnitsPrefs.setLength,
              ),
              _UnitsCard<WeightUnit>(
                icon: Icons.monitor_weight_outlined,
                title: s.unitsWeightTitle,
                subtitle: s.unitsWeightSubtitle,
                valueListenable: MeasurementUnitsPrefs.weight,
                options: const [
                  _UnitOption(value: WeightUnit.kg, labelKey: _UnitsLabelKey.kg),
                  _UnitOption(value: WeightUnit.lb, labelKey: _UnitsLabelKey.lb),
                  _UnitOption(value: WeightUnit.st, labelKey: _UnitsLabelKey.st),
                ],
                onChanged: MeasurementUnitsPrefs.setWeight,
              ),
              _UnitsCard<LiquidUnit>(
                icon: Icons.local_drink_rounded,
                title: s.unitsLiquidTitle,
                subtitle: s.unitsLiquidSubtitle,
                valueListenable: MeasurementUnitsPrefs.liquid,
                options: const [
                  _UnitOption(value: LiquidUnit.ml, labelKey: _UnitsLabelKey.ml),
                  _UnitOption(value: LiquidUnit.ukFloz, labelKey: _UnitsLabelKey.ukFloz),
                  _UnitOption(value: LiquidUnit.usFloz, labelKey: _UnitsLabelKey.usFloz),
                ],
                onChanged: MeasurementUnitsPrefs.setLiquid,
              ),
              _UnitsCard<TemperatureUnit>(
                icon: Icons.thermostat_rounded,
                title: s.unitsTempTitle,
                subtitle: s.unitsTempSubtitle,
                valueListenable: MeasurementUnitsPrefs.temperature,
                options: const [
                  _UnitOption(value: TemperatureUnit.c, labelKey: _UnitsLabelKey.c),
                  _UnitOption(value: TemperatureUnit.f, labelKey: _UnitsLabelKey.f),
                ],
                onChanged: MeasurementUnitsPrefs.setTemperature,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

enum _UnitsLabelKey { cm, inch, kg, lb, st, ml, ukFloz, usFloz, c, f }

class _UnitOption<T> {
  final T value;
  final _UnitsLabelKey labelKey;
  const _UnitOption({required this.value, required this.labelKey});
}

class _UnitsCard<T> extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final ValueListenable<T> valueListenable;
  final List<_UnitOption<T>> options;
  final Future<void> Function(T) onChanged;

  const _UnitsCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.valueListenable,
    required this.options,
    required this.onChanged,
  });

  String _label(S s, _UnitsLabelKey k) {
    return switch (k) {
      _UnitsLabelKey.cm => s.unitsOptCm,
      _UnitsLabelKey.inch => s.unitsOptInch,
      _UnitsLabelKey.kg => s.unitsOptKg,
      _UnitsLabelKey.lb => s.unitsOptLb,
      _UnitsLabelKey.st => s.unitsOptSt,
      _UnitsLabelKey.ml => s.unitsOptMl,
      _UnitsLabelKey.ukFloz => s.unitsOptUkFloz,
      _UnitsLabelKey.usFloz => s.unitsOptUsFloz,
      _UnitsLabelKey.c => s.unitsOptC,
      _UnitsLabelKey.f => s.unitsOptF,
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final accent = Color.lerp(AppTheme.primaryPurple, AppTheme.primaryPink, 0.35)!;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withAlpha(35)),
        boxShadow: [BoxShadow(color: Colors.black.withAlpha(8), blurRadius: 14, offset: const Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: Color.lerp(Colors.white, accent, 0.10),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: accent.withAlpha(45)),
                ),
                child: Icon(icon, color: accent.withAlpha(235)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: portalSp(context, 15.5))),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontWeight: FontWeight.w600, height: 1.25, color: Colors.black.withAlpha(135))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ValueListenableBuilder<T>(
            valueListenable: valueListenable,
            builder: (context, cur, _) {
              return Column(
                children: [
                  for (final opt in options)
                    RadioListTile<T>(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                      activeColor: accent,
                      value: opt.value,
                      groupValue: cur,
                      title: Text(_label(s, opt.labelKey), style: const TextStyle(fontWeight: FontWeight.w800)),
                      onChanged: (v) async {
                        if (v == null) return;
                        await onChanged(v);
                      },
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

