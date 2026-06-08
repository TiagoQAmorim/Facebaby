import 'package:flutter/foundation.dart';

/// Signals [MainShell] to replay the in-app tour (Settings › Help).
class AppTourController extends ChangeNotifier {
  AppTourController._();

  static final AppTourController instance = AppTourController._();

  bool _replayRequested = false;

  void requestReplay() {
    _replayRequested = true;
    notifyListeners();
  }

  bool consumeReplayRequest() {
    final v = _replayRequested;
    _replayRequested = false;
    return v;
  }
}
