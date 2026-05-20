import 'package:flutter/material.dart';

import '../../utils/portal_time_of_day.dart';

/// Fundo dos relatórios: branco no modo noturno; transparente de dia (portal).
Color? reportScaffoldBackground([DateTime? at]) {
  return PortalTimeOfDay.isNight(at ?? DateTime.now()) ? Colors.white : null;
}
