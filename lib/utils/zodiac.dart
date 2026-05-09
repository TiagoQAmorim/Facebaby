String zodiacSignPtBr(DateTime date) {
  final m = date.month;
  final d = date.day;

  // Capricórnio: 22/12 - 19/01
  if ((m == 12 && d >= 22) || (m == 1 && d <= 19)) return 'Capricórnio';
  // Aquário: 20/01 - 18/02
  if ((m == 1 && d >= 20) || (m == 2 && d <= 18)) return 'Aquário';
  // Peixes: 19/02 - 20/03
  if ((m == 2 && d >= 19) || (m == 3 && d <= 20)) return 'Peixes';
  // Áries: 21/03 - 19/04
  if ((m == 3 && d >= 21) || (m == 4 && d <= 19)) return 'Áries';
  // Touro: 20/04 - 20/05
  if ((m == 4 && d >= 20) || (m == 5 && d <= 20)) return 'Touro';
  // Gêmeos: 21/05 - 20/06
  if ((m == 5 && d >= 21) || (m == 6 && d <= 20)) return 'Gêmeos';
  // Câncer: 21/06 - 22/07
  if ((m == 6 && d >= 21) || (m == 7 && d <= 22)) return 'Câncer';
  // Leão: 23/07 - 22/08
  if ((m == 7 && d >= 23) || (m == 8 && d <= 22)) return 'Leão';
  // Virgem: 23/08 - 22/09
  if ((m == 8 && d >= 23) || (m == 9 && d <= 22)) return 'Virgem';
  // Libra: 23/09 - 22/10
  if ((m == 9 && d >= 23) || (m == 10 && d <= 22)) return 'Libra';
  // Escorpião: 23/10 - 21/11
  if ((m == 10 && d >= 23) || (m == 11 && d <= 21)) return 'Escorpião';
  // Sagitário: 22/11 - 21/12
  return 'Sagitário';
}

