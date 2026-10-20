import 'countries.dart';

/// A Kenyan mobile number as +254XXXXXXXXX, or null. Kept for callers that only know
/// Kenya; new code uses [normalisePhoneIn] with the person's country.
String? normalisePhone(String raw) => normalisePhoneIn(raw, 'KE');
