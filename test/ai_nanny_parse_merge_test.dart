import 'package:facebaby_flutter/models/ai/ai_nanny_parsed_message.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_local_message_parser.dart';
import 'package:facebaby_flutter/services/ai/ai_nanny_parse_merge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('merge cloud parcial + local completo mantém sono e altura', () {
    const msg =
        'a bebe acordou feliz agora, parece estar com fome, ah e cresceu 1 cm';
    final local = AiNannyLocalMessageParser.parse(msg);
    final cloud = AiNannyParseResult(
      classification: 'create_records',
      records: [
        AiNannyStructuredRecord(
          type: 'growth_height',
          fields: {
            'measurementType': 'height',
            'value': 1,
            'unit': 'cm',
            'mode': 'delta',
          },
        ),
      ],
      needsConfirmation: true,
    );

    final merged = AiNannyParseMerge.merge(cloud, local, msg);
    expect(merged.records.length, 2);
    expect(
      merged.records.map((r) => r.type).toSet(),
      containsAll(['sleep', 'growth_height']),
    );
  });
}
