import 'package:facebaby_flutter/models/floating_message_model.dart';
import 'package:facebaby_flutter/utils/floating_message_eligibility.dart';
import 'package:flutter_test/flutter_test.dart';

FloatingMessage _msg({DateTime? createdAt}) => FloatingMessage(
      id: 'x',
      title: 'T',
      message: 'M',
      type: FloatingMessageType.adminNotice,
      createdAt: createdAt,
    );

void main() {
  test('hides message before user account day', () {
    final userDay = DateTime(2026, 5, 30);
    expect(
      FloatingMessageEligibility.isVisibleToUser(
        message: _msg(createdAt: DateTime(2026, 5, 29)),
        userAccountSince: userDay,
      ),
      isFalse,
    );
    expect(
      FloatingMessageEligibility.isVisibleToUser(
        message: _msg(createdAt: DateTime(2026, 5, 30, 23)),
        userAccountSince: userDay,
      ),
      isTrue,
    );
  });

  test('hides legacy without createdAt when reset or user since set', () {
    expect(
      FloatingMessageEligibility.isVisibleToUser(
        message: _msg(),
        userAccountSince: DateTime(2026, 5, 30),
      ),
      isFalse,
    );
    expect(
      FloatingMessageEligibility.isVisibleToUser(
        message: _msg(),
        resetBefore: DateTime(2026, 5, 1),
      ),
      isFalse,
    );
  });

  test('resetBefore filters older campaigns', () {
    final reset = DateTime(2026, 5, 28, 12);
    expect(
      FloatingMessageEligibility.isVisibleToUser(
        message: _msg(createdAt: DateTime(2026, 5, 27)),
        resetBefore: reset,
      ),
      isFalse,
    );
    expect(
      FloatingMessageEligibility.isVisibleToUser(
        message: _msg(createdAt: DateTime(2026, 5, 28, 13)),
        resetBefore: reset,
      ),
      isTrue,
    );
  });
}
