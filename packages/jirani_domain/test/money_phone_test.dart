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
    for (final raw in ['', '0812345678', '07123456']) {
      test('rejects "$raw"', () => expect(normalisePhone(raw), isNull));
    }
    test('reads a number with another country code in that country',
        () => expect(normalisePhone('+255712345678'), '+255712345678'));
  });

  group('normalisePhoneIn (nine countries, same rules as the server)', () {
    final cases = {
      ('0772 123 456', 'UG'): '+256772123456',
      ('0754 123 456', 'TZ'): '+255754123456',
      ('0788123456', 'RW'): '+250788123456',
      ('79 123 456', 'BI'): '+25779123456',
      ('0812345678', 'CD'): '+243812345678',
      ('0912345678', 'SS'): '+211912345678',
      ('0911234567', 'ET'): '+251911234567',
      ('+252612345678', 'KE'): '+252612345678',
      ('+254712345678', 'UG'): '+254712345678',
    };
    cases.forEach((input, expected) {
      test('${input.$1} in ${input.$2}',
          () => expect(normalisePhoneIn(input.$1, input.$2), expected));
    });
    test('a wrong local number is refused', () => expect(normalisePhoneIn('0612', 'UG'), isNull));
  });

  group('currency', () {
    tearDown(() => Kes.currency = 'KES');
    test('amounts show in the open chama currency, without cents where none are used', () {
      Kes.currency = 'UGX';
      expect(const Kes(5000050).format(), 'UGX 50,000');
      Kes.currency = 'USD';
      expect(const Kes(1250).format(), 'USD 12.50');
      expect(Kes.currencyName, 'US dollars');
    });
  });
}
