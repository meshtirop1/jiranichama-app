import 'package:jirani_domain/jirani_domain.dart';
import 'package:test/test.dart';

void main() {
  group('Kes', () {
    test('formats with grouping and only the cents it needs', () {
      expect(const Kes(128450000).format(), 'KES 1,284,500');
      expect(const Kes(128450050).format(), 'KES 1,284,500.50');
      expect(const Kes(-20000).format(), '−KES 200');
      expect(Kes.zero.format(), 'KES 0');
      expect(const Kes.shillings(1000).format(), 'KES 1,000');
    });

    test('adds and compares as cents', () {
      expect(const Kes(150) + const Kes(50), const Kes(200));
      expect(const Kes(100).compareTo(const Kes(99)), greaterThan(0));
    });
  });

  group('normalisePhone (same rules as the server)', () {
    for (final raw in ['0712345678', '+254712345678', '254712345678', '0712 345-678',
      '712345678']) {
      test('accepts $raw', () => expect(normalisePhone(raw), '+254712345678'));
    }
    for (final raw in ['', '0812345678', '+255712345678', '07123456']) {
      test('rejects "$raw"', () => expect(normalisePhone(raw), isNull));
    }
  });
}
