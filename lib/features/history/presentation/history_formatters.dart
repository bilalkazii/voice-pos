import 'package:intl/intl.dart';

/// Date-only (noon-normalized) of a local DateTime.
DateTime _dateOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}

/// Human-friendly, device-local date/time labels for History.
///
/// Stored timestamps stay `DateTime` (never strings); formatting is a
/// presentation concern. Relative labels for the last two days keep the
/// list scannable; older entries fall back to a full date.
String formatHistoryDateTime(DateTime value, {DateTime? now}) {
  final local = value.toLocal();
  final reference = (now ?? DateTime.now()).toLocal();
  final day = _dateOnly(local);
  final today = _dateOnly(reference);
  final yesterday = today.subtract(const Duration(days: 1));

  if (day == today) {
    return 'Today, ${DateFormat('h:mm a').format(local)}';
  }
  if (day == yesterday) {
    return 'Yesterday, ${DateFormat('h:mm a').format(local)}';
  }
  return DateFormat('d MMM yyyy, h:mm a').format(local);
}

/// Date header used when a filter collapses to a single day or for the
/// summary card: `7 Sep 2026`.
String formatFullDate(DateTime value) {
  return DateFormat('d MMM yyyy').format(value.toLocal());
}
