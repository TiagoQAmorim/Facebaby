import 'package:flutter/foundation.dart';

enum AiState { off, listening, answering }

class AiController extends ChangeNotifier {
  AiState _state = AiState.off;

  AiState get state => _state;
  bool get isActive => _state != AiState.off;

  void toggle() {
    _state = switch (_state) {
      AiState.off => AiState.listening,
      AiState.listening => AiState.answering,
      AiState.answering => AiState.off,
    };
    notifyListeners();
  }

  void close() {
    _state = AiState.off;
    notifyListeners();
  }
}
