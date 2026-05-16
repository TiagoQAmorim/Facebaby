import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../family_tree_page.dart';

/// Ative com `flutter run -d chrome --dart-define=SHOW_MIRROR=true` ou em modo debug.
const bool _kMirrorFromDefine = bool.fromEnvironment(
  'SHOW_MIRROR',
  defaultValue: false,
);

bool showLoggedOutScreenMirrors() => kDebugMode || _kMirrorFromDefine;

/// Pré-visualização da aba Família a partir do fluxo deslogado (ex.: Chrome).
class LoggedOutMirrorFamilyPage extends StatelessWidget {
  const LoggedOutMirrorFamilyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const FamilyTreePage();
  }
}

void pushLoggedOutMirrorFamily(BuildContext context) {
  Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      builder: (_) => const LoggedOutMirrorFamilyPage(),
    ),
  );
}
