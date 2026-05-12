/// Uma ocorrência de sintoma no relatório pediátrico (instante local).
class PediatricSymptomOccurrence {
  const PediatricSymptomOccurrence({
    required this.at,
    this.journalDayOnly = false,
    this.detail,
  });

  final DateTime at;

  /// Mencionado só no texto do diário desse dia civil (sem hora no registo).
  final bool journalDayOnly;

  /// Ex.: temperatura na febre, nota de medicamento ou "outro".
  final String? detail;
}
