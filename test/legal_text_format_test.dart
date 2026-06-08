import 'package:flutter_test/flutter_test.dart';
import 'package:facebaby_flutter/utils/legal_text_format.dart';

void main() {
  test('inserts breaks before numbered sections and subsection titles', () {
    const raw = '''
FaceBaby — Política de Privacidade

PT-BR - Última atualização: Maio de 2026

1. Introdução
Bem-vindo ao FaceBaby.
Privacidade.
2. Dados Coletados
Podemos coletar os seguintes dados:
Dados da Conta
• Nome
• E-mail
Dados do Bebê
• Nome do bebê
''';

    final processed = preprocessLegalPlainText(raw);

    expect(processed, contains('1. Introdução\n\nBem-vindo'));
    expect(processed, contains('Privacidade.\n\n2. Dados Coletados'));
    expect(processed, contains('Dados da Conta\n\n• Nome'));
    expect(processed, contains('• E-mail\n\nDados do Bebê'));
  });

  test('detects numbered sections and subsection titles', () {
    expect(legalLineLooksLikeNumberedSection('2. Dados Coletados'), isTrue);
    expect(legalLineLooksLikeNumberedSection('Bem-vindo'), isFalse);

    expect(legalLineLooksLikeSubsectionTitle('Dados da Conta'), isTrue);
    expect(
      legalLineLooksLikeSubsectionTitle('Podemos coletar os seguintes dados:'),
      isFalse,
    );
  });
}
