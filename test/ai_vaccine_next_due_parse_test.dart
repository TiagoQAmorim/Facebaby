import 'package:facebaby_flutter/utils/ai_nanny_parse_normalize.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseVaccineNextDueInDays', () {
    expect(
      AiNannyParseNormalize.parseVaccineNextDueInDays(
        'próxima dose daqui a 30 dias',
      ),
      30,
    );
    expect(
      AiNannyParseNormalize.parseVaccineNextDueInDays(
        'a próxima é só daqui a 60 dias',
      ),
      60,
    );
    expect(
      AiNannyParseNormalize.parseVaccineNextDueInDays('tomou BCG hoje'),
      isNull,
    );
  });
}
