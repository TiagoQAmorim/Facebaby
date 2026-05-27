import 'package:facebaby_flutter/models/floating_message_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// Espelha o filtro em [FloatingMessageService.listActiveMessages].
bool passesResetBeforeFilter({
  required FloatingMessage msg,
  DateTime? resetBefore,
}) {
  if (resetBefore == null) return true;
  final created = msg.createdAt;
  if (created == null) return true;
  return !created.isBefore(resetBefore);
}

void main() {
  final resetBefore = DateTime(2025, 6, 1, 12);

  test('mensagens antigas antes de resetBefore não passam', () {
    const old = FloatingMessage(
      id: 'old',
      title: 'Campanha antiga',
      message: 'Teste',
      type: FloatingMessageType.adminNotice,
      createdAt: null,
    );
    final withDate = FloatingMessage(
      id: old.id,
      title: old.title,
      message: old.message,
      type: old.type,
      createdAt: DateTime(2025, 1, 15),
    );
    expect(
      passesResetBeforeFilter(msg: withDate, resetBefore: resetBefore),
      isFalse,
    );
  });

  test('mensagens após resetBefore passam', () {
    final recent = FloatingMessage(
      id: 'new',
      title: 'Nova',
      message: 'Ok',
      type: FloatingMessageType.adminNotice,
      createdAt: DateTime(2025, 7, 1),
    );
    expect(
      passesResetBeforeFilter(msg: recent, resetBefore: resetBefore),
      isTrue,
    );
  });

  test('sem resetBefore todas passam', () {
    final msg = FloatingMessage(
      id: 'x',
      title: 'T',
      message: 'M',
      type: FloatingMessageType.adminNotice,
      createdAt: DateTime(2020, 1, 1),
    );
    expect(passesResetBeforeFilter(msg: msg, resetBefore: null), isTrue);
  });
}
