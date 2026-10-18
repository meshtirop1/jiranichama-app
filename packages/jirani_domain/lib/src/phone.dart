// Kenyan mobile numbers, normalised the same way as the server
// (`apps/accounts/phones.py`): 07…, 01…, 2547…, +2547… all become +254XXXXXXXXX.

final RegExp _kenya = RegExp(r'^(?:\+?254|0)?([17]\d{8})$');
final RegExp _separators = RegExp(r'[\s\-()]');

/// Returns +254XXXXXXXXX, or null if [raw] is not a Kenyan mobile number.
String? normalisePhone(String raw) {
  final match = _kenya.firstMatch(raw.replaceAll(_separators, ''));
  return match == null ? null : '+254${match.group(1)}';
}
