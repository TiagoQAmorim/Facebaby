import '../models/floating_message_model.dart';

/// Regras de visibilidade do balão (reset global + utilizador novo).
abstract final class FloatingMessageEligibility {
  FloatingMessageEligibility._();

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// `false` = mensagem legada / anterior ao registo / antes do reset admin.
  static bool isVisibleToUser({
    required FloatingMessage message,
    DateTime? userAccountSince,
    DateTime? resetBefore,
  }) {
    final created = message.createdAt;

    if (resetBefore != null) {
      if (created == null) return false;
      if (created.isBefore(resetBefore)) return false;
    }

    if (userAccountSince != null) {
      if (created == null) return false;
      final sinceDay = dateOnly(userAccountSince);
      final msgDay = dateOnly(created);
      if (msgDay.isBefore(sinceDay)) return false;
    }

    return true;
  }
}
