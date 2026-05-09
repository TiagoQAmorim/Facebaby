/// Completed calendar months between [birth] (date only) and [now].
int babyCompletedMonths(DateTime birth, DateTime now) {
  final b = DateTime(birth.year, birth.month, birth.day);
  final n = DateTime(now.year, now.month, now.day);
  var months = (n.year - b.year) * 12 + (n.month - b.month);
  if (n.day < b.day) months -= 1;
  return months < 0 ? 0 : months;
}
