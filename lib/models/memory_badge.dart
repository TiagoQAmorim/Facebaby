import 'package:flutter/material.dart';

class MemoryBadge {
  final String id;
  final String title;
  final String category; // e.g. "moment", "monthly", "birthday"
  /// Asset icon file name (without path). Prefer this over [icon] when provided by designer.
  final String iconName;
  final IconData? icon;
  final Color defaultColor;
  final int sortOrder;
  final bool isMonthlyBadge;
  final int? monthNumber; // 1..23
  final int? yearNumber; // 1..2 (birthday)

  const MemoryBadge({
    required this.id,
    required this.title,
    required this.category,
    required this.iconName,
    required this.icon,
    required this.defaultColor,
    required this.sortOrder,
    this.isMonthlyBadge = false,
    this.monthNumber,
    this.yearNumber,
  });
}

