/// E-mail já tem conta Firebase; [signInMethods] vêm de [fetchSignInMethodsForEmail].
class EmailAlreadyRegisteredException implements Exception {
  EmailAlreadyRegisteredException(this.signInMethods);

  final List<String> signInMethods;
}
