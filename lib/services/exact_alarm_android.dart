import 'dart:io';

import 'package:flutter/services.dart';

/// Android 12+ (API 31): lembretes na hora dependem de permissão de **alarmas exactos**.
/// Sem isto o sistema pode atrasar ou não disparar [scheduleZoned].
abstract final class ExactAlarmAndroid {
  ExactAlarmAndroid._();

  static const MethodChannel _ch = MethodChannel('facebaby/alarm');

  /// `true` quando vale a pena mostrar atalho para Definições (alarmas exactos desligados).
  static Future<bool> needsExactAlarmFix() async {
    if (!Platform.isAndroid) return false;
    try {
      final v = await _ch.invokeMethod<bool>('needsExactAlarmFix');
      return v == true;
    } catch (_) {
      return false;
    }
  }

  static Future<void> openExactAlarmSettings() async {
    if (!Platform.isAndroid) return;
    try {
      await _ch.invokeMethod<void>('openExactAlarmSettings');
    } catch (_) {}
  }
}
