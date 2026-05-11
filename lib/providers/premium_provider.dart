import 'package:flutter/widgets.dart';

import '../services/premium/premium_service.dart';

/// Expõe rebuild automático quando o estado Premium muda (sem pacote `provider`).
class PremiumScope extends StatelessWidget {
  const PremiumScope({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: PremiumService.instance,
      builder: (_, __) => child,
    );
  }
}
