/// Resultado da Cloud Function `processVoiceRecord`.

class VoiceRecordResult {

  const VoiceRecordResult({

    required this.transcript,

    required this.interpretation,

  });



  final String transcript;

  final VoiceRecordInterpretation interpretation;



  factory VoiceRecordResult.fromMap(Map<String, dynamic> data) {

    final interpRaw = data['interpretation'];

    return VoiceRecordResult(

      transcript: '${data['transcript'] ?? ''}'.trim(),

      interpretation: interpRaw is Map

          ? VoiceRecordInterpretation.fromMap(

              Map<String, dynamic>.from(interpRaw),

            )

          : const VoiceRecordInterpretation.unknown(),

    );

  }

}



class VoiceRecordInterpretation {

  const VoiceRecordInterpretation({

    required this.type,

    required this.summary,

    this.feeding,

    this.sleep,

    this.diaper,

    this.weight,

    this.height,

    this.symptom,

    this.consultation,

    this.vaccine,

  });



  final String type;

  final String summary;

  final VoiceFeedingPayload? feeding;

  final VoiceSleepPayload? sleep;

  final VoiceDiaperPayload? diaper;

  final VoiceWeightPayload? weight;

  final VoiceHeightPayload? height;

  final VoiceSymptomPayload? symptom;

  final VoiceConsultationPayload? consultation;

  final VoiceVaccinePayload? vaccine;



  const VoiceRecordInterpretation.unknown()

      : type = 'unknown',

        summary = '',

        feeding = null,

        sleep = null,

        diaper = null,

        weight = null,

        height = null,

        symptom = null,

        consultation = null,

        vaccine = null;



  bool get isQuestion => type == 'question';



  bool get canRegister =>

      type == 'feeding' ||

      type == 'sleep' ||

      type == 'diaper' ||

      type == 'weight' ||

      type == 'height' ||

      type == 'symptom' ||

      type == 'consultation' ||

      type == 'vaccine';



  bool get isHealthRegister =>

      type == 'symptom' || type == 'consultation' || type == 'vaccine';



  /// Campos obrigatórios ainda faltando antes de salvar.

  bool get needsHealthFormFields {

    switch (type) {

      case 'symptom':

        final s = symptom;

        if (s == null) return true;

        if (s.fever && (s.tempCelsius == null || s.tempCelsius! <= 0)) {

          return true;

        }

        return !s.fever &&

            !s.crying &&

            !s.pain &&

            !s.colic &&

            !s.reflux &&

            (s.otherNote == null || s.otherNote!.trim().isEmpty);

      case 'consultation':

        return consultation?.title == null ||

            consultation!.title!.trim().isEmpty;

      case 'vaccine':

        return vaccine?.name == null || vaccine!.name!.trim().isEmpty;

      default:

        return false;

    }

  }



  VoiceRecordInterpretation copyWith({

    String? type,

    String? summary,

    VoiceFeedingPayload? feeding,

    VoiceSleepPayload? sleep,

    VoiceDiaperPayload? diaper,

    VoiceWeightPayload? weight,

    VoiceHeightPayload? height,

    VoiceSymptomPayload? symptom,

    VoiceConsultationPayload? consultation,

    VoiceVaccinePayload? vaccine,

  }) {

    return VoiceRecordInterpretation(

      type: type ?? this.type,

      summary: summary ?? this.summary,

      feeding: feeding ?? this.feeding,

      sleep: sleep ?? this.sleep,

      diaper: diaper ?? this.diaper,

      weight: weight ?? this.weight,

      height: height ?? this.height,

      symptom: symptom ?? this.symptom,

      consultation: consultation ?? this.consultation,

      vaccine: vaccine ?? this.vaccine,

    );

  }



  factory VoiceRecordInterpretation.fromMap(Map<String, dynamic> m) {

    return VoiceRecordInterpretation(

      type: '${m['type'] ?? 'unknown'}'.trim().toLowerCase(),

      summary: '${m['summary'] ?? ''}'.trim(),

      feeding: VoiceFeedingPayload.fromMap(m['feeding']),

      sleep: VoiceSleepPayload.fromMap(m['sleep']),

      diaper: VoiceDiaperPayload.fromMap(m['diaper']),

      weight: VoiceWeightPayload.fromMap(m['weight']),

      height: VoiceHeightPayload.fromMap(m['height']),

      symptom: VoiceSymptomPayload.fromMap(m['symptom']),

      consultation: VoiceConsultationPayload.fromMap(m['consultation']),

      vaccine: VoiceVaccinePayload.fromMap(m['vaccine']),

    );

  }

}



class VoiceFeedingPayload {

  const VoiceFeedingPayload({

    this.subtype,

    this.side,

    this.quantityMl,

    this.note,

    this.eventTime,

  });



  final String? subtype;

  /// Peito: `E` ou `D`.
  final String? side;

  final double? quantityMl;

  final String? note;

  final DateTime? eventTime;



  static VoiceFeedingPayload? fromMap(dynamic raw) {

    if (raw is! Map) return null;

    final m = Map<String, dynamic>.from(raw);

    return VoiceFeedingPayload(

      subtype: _str(m['subtype']),

      side: _str(m['side']),

      quantityMl: _dbl(m['quantityMl']),

      note: _str(m['note']),

      eventTime: _dt(m['eventTime']),

    );

  }

}



class VoiceSleepPayload {

  const VoiceSleepPayload({

    this.action,

    this.startedAt,

    this.endedAt,

    this.durationMinutes,

    this.note,

  });



  /// `start` | `end` | `complete`

  final String? action;

  final DateTime? startedAt;

  final DateTime? endedAt;

  final int? durationMinutes;

  final String? note;



  static VoiceSleepPayload? fromMap(dynamic raw) {

    if (raw is! Map) return null;

    final m = Map<String, dynamic>.from(raw);

    return VoiceSleepPayload(

      action: _str(m['action'] ?? m['phase']),

      startedAt: _dt(m['startedAt']),

      endedAt: _dt(m['endedAt']),

      durationMinutes: _int(m['durationMinutes']),

      note: _str(m['note']),

    );

  }

}



/// Resultado ao salvar registro por voz (mensagem opcional na UI).

enum VoiceRecordSaveKind {

  saved,

  sleepStarted,

  sleepEnded,

}



class VoiceDiaperPayload {

  const VoiceDiaperPayload({this.kind, this.changedAt});



  final String? kind;

  final DateTime? changedAt;



  static VoiceDiaperPayload? fromMap(dynamic raw) {

    if (raw is! Map) return null;

    final m = Map<String, dynamic>.from(raw);

    return VoiceDiaperPayload(

      kind: _str(m['kind']),

      changedAt: _dt(m['changedAt']),

    );

  }

}



class VoiceWeightPayload {

  const VoiceWeightPayload({
    this.weightKg,
    this.weightDeltaGrams,
    this.measuredAt,
  });



  final double? weightKg;

  /// Ganho/perda em gramas (soma ao último peso no app).
  final double? weightDeltaGrams;

  final DateTime? measuredAt;



  static VoiceWeightPayload? fromMap(dynamic raw) {

    if (raw is! Map) return null;

    final m = Map<String, dynamic>.from(raw);

    return VoiceWeightPayload(

      weightKg: _dbl(m['weightKg'] ?? m['kg']),

      weightDeltaGrams: _dbl(m['weightDeltaGrams'] ?? m['deltaGrams']),

      measuredAt: _dt(m['measuredAt']),

    );

  }

}



class VoiceHeightPayload {

  const VoiceHeightPayload({

    this.heightCm,

    this.heightDeltaCm,

    this.measuredAt,

  });



  final double? heightCm;

  final double? heightDeltaCm;

  final DateTime? measuredAt;



  static VoiceHeightPayload? fromMap(dynamic raw) {

    if (raw is! Map) return null;

    final m = Map<String, dynamic>.from(raw);

    return VoiceHeightPayload(

      heightCm: _dbl(m['heightCm'] ?? m['cm']),

      heightDeltaCm: _dbl(m['heightDeltaCm'] ?? m['deltaCm']),

      measuredAt: _dt(m['measuredAt']),

    );

  }

}



class VoiceSymptomPayload {

  const VoiceSymptomPayload({

    this.fever = false,

    this.tempCelsius,

    this.occurredAt,

    this.otherNote,

    this.crying = false,

    this.pain = false,

    this.colic = false,

    this.reflux = false,

  });



  final bool fever;

  final double? tempCelsius;

  final DateTime? occurredAt;

  final String? otherNote;

  final bool crying;

  final bool pain;

  final bool colic;

  final bool reflux;



  static VoiceSymptomPayload? fromMap(dynamic raw) {

    if (raw is! Map) return null;

    final m = Map<String, dynamic>.from(raw);

    return VoiceSymptomPayload(

      fever: _bool(m['fever']),

      tempCelsius: _dbl(m['tempCelsius'] ?? m['temp_celsius']),

      occurredAt: _dt(m['occurredAt'] ?? m['occurred_at']),

      otherNote: _str(m['otherNote'] ?? m['other_note']),

      crying: _bool(m['crying']),

      pain: _bool(m['pain']),

      colic: _bool(m['colic']),

      reflux: _bool(m['reflux']),

    );

  }

}



class VoiceConsultationPayload {

  const VoiceConsultationPayload({

    this.title,

    this.occurredAt,

    this.notes,

    this.phone,

    this.address,

  });



  final String? title;

  final DateTime? occurredAt;

  final String? notes;

  final String? phone;

  final String? address;



  static VoiceConsultationPayload? fromMap(dynamic raw) {

    if (raw is! Map) return null;

    final m = Map<String, dynamic>.from(raw);

    return VoiceConsultationPayload(

      title: _str(m['title']),

      occurredAt: _dt(m['occurredAt'] ?? m['occurred_at']),

      notes: _str(m['notes']),

      phone: _str(m['phone']),

      address: _str(m['address']),

    );

  }

}



class VoiceVaccinePayload {

  const VoiceVaccinePayload({

    this.name,

    this.dose,

    this.appliedAt,

    this.nextDueAt,

    this.notes,

  });



  final String? name;

  final String? dose;

  final DateTime? appliedAt;

  final DateTime? nextDueAt;

  final String? notes;



  static VoiceVaccinePayload? fromMap(dynamic raw) {

    if (raw is! Map) return null;

    final m = Map<String, dynamic>.from(raw);

    return VoiceVaccinePayload(

      name: _str(m['name']),

      dose: _str(m['dose']),

      appliedAt: _dt(m['appliedAt'] ?? m['applied_at']),

      nextDueAt: _dt(m['nextDueAt'] ?? m['next_due_at']),

      notes: _str(m['notes']),

    );

  }

}



bool _bool(dynamic v) {

  if (v is bool) return v;

  if (v is num) return v != 0;

  final s = '$v'.trim().toLowerCase();

  return s == 'true' || s == '1' || s == 'sim' || s == 'yes';

}



String? _str(dynamic v) {

  final s = '$v'.trim();

  return s.isEmpty ? null : s;

}



double? _dbl(dynamic v) {

  if (v == null) return null;

  if (v is num) return v.toDouble();

  return double.tryParse('$v'.replaceAll(',', '.'));

}



int? _int(dynamic v) {

  if (v == null) return null;

  if (v is num) return v.toInt();

  return int.tryParse('$v');

}



DateTime? _dt(dynamic v) {

  if (v == null) return null;

  return DateTime.tryParse('$v');

}


