import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../utils/measurement_format.dart';

class MemoryMetadataRow extends StatelessWidget {
  final String? age;
  final double? weightKg;
  final double? heightCm;
  final String? mood;

  const MemoryMetadataRow({
    super.key,
    this.age,
    this.weightKg,
    this.heightCm,
    this.mood,
  });

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (age != null && age!.trim().isNotEmpty) parts.add(age!.trim());
    if (weightKg != null) parts.add(MeasurementFormat.weight(weightKg, decimalsKg: 2));
    if (heightCm != null) parts.add(MeasurementFormat.length(heightCm, decimalsCm: 0));
    if (mood != null && mood!.trim().isNotEmpty) parts.add(mood!.trim());

    if (parts.isEmpty) return const SizedBox.shrink();
    return Text(
      parts.join(' • '),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        color: AppTheme.textPrimary.withAlpha(150),
        fontWeight: FontWeight.w700,
        height: 1.15,
      ),
    );
  }
}

