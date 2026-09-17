//==============================================================================
// SPOCART — Formatting helpers (no intl dependency)
//==============================================================================

/// Indian-rupee formatting with lakh/crore grouping: 245000 → "₹2,45,000".
String formatInr(num amount, {bool showSign = true}) {
  final int rounded = amount.round();
  final String digits = rounded.abs().toString();
  final int len = digits.length;

  String grouped;
  if (len <= 3) {
    grouped = digits;
  } else {
    final String last3 = digits.substring(len - 3);
    final List<String> groups = <String>[];
    String rest = digits.substring(0, len - 3);
    while (rest.length > 2) {
      groups.insert(0, rest.substring(rest.length - 2));
      rest = rest.substring(0, rest.length - 2);
    }
    if (rest.isNotEmpty) groups.insert(0, rest);
    grouped = '${groups.join(',')},$last3';
  }

  final String sign = rounded < 0 ? '-' : '';
  return showSign ? '₹$sign$grouped' : '$sign$grouped';
}

/// "₹1,200 - ₹1,800" or a single value when both ends match.
String formatInrRange(num low, num high) {
  if (low.round() == high.round()) return formatInr(low);
  return '${formatInr(low)} - ${formatInr(high)}';
}

const List<String> _months = <String>[
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

/// "12 Apr 2025"
String formatDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';

/// "12 Apr" (year omitted)
String formatShortDate(DateTime d) => '${d.day} ${_months[d.month - 1]}';

/// "12 Apr 2025, 5:42 pm"
String formatDateTime(DateTime d) {
  final int hour12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  final String minute = d.minute.toString().padLeft(2, '0');
  final String period = d.hour >= 12 ? 'pm' : 'am';
  return '${formatDate(d)}, $hour12:$minute $period';
}

/// "12 Apr 2025 - 16 Apr 2025"
String formatDateRange(DateTime start, DateTime end) =>
    '${formatDate(start)} - ${formatDate(end)}';

/// Human relative time for notification lists: "2m ago", "3h ago", "2d ago".
String formatRelative(DateTime time, {DateTime? now}) {
  final DateTime reference = now ?? DateTime.now();
  final Duration diff = reference.difference(time);
  if (diff.inSeconds < 60) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return formatShortDate(time);
}

/// "+91 98765 43210" from a 10-digit Indian mobile number.
String formatIndianMobile(String digits) {
  final String clean = digits.replaceAll(RegExp(r'\D'), '');
  if (clean.length != 10) return clean.isEmpty ? '' : '+91 $clean';
  return '+91 ${clean.substring(0, 5)} ${clean.substring(5)}';
}

/// Two-letter initials from a name: "Rohit Kumar" → "RK".
String initialsOf(String name) {
  final List<String> parts = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((p) => p.isNotEmpty)
      .toList();
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first[0].toUpperCase();
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

/// "5 items" / "1 item"
String pluralize(int count, String singular, [String? plural]) =>
    '$count ${count == 1 ? singular : (plural ?? '${singular}s')}';
