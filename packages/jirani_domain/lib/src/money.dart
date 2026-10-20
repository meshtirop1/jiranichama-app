/// An amount of money, held as integer hundredths ("cents"). Never a double.
///
/// The name is historical: amounts are in the currency of the chama being shown, which
/// is set in [Kes.currency] when a chama is opened (one chama is on screen at a time).
/// Storage is hundredths for every currency, like the server; only how an amount is shown
/// changes: Uganda, Tanzania, Rwanda and Burundi do not use cents.
class Kes implements Comparable<Kes> {
  const Kes(this.cents);
  const Kes.shillings(int shillings) : cents = shillings * 100;

  final int cents;

  static const zero = Kes(0);

  /// The currency amounts are shown in: the open chama's (KES until one is opened).
  static String currency = 'KES';

  static const _noCents = {'UGX', 'TZS', 'RWF', 'BIF'};

  /// The currency's name for screen readers.
  static String get currencyName => const {
        'KES': 'Kenya shillings', 'UGX': 'Uganda shillings', 'TZS': 'Tanzania shillings',
        'RWF': 'Rwanda francs', 'BIF': 'Burundi francs', 'CDF': 'Congolese francs',
        'SSP': 'South Sudanese pounds', 'ETB': 'Ethiopian birr', 'SOS': 'Somali shillings',
        'USD': 'US dollars',
      }[currency] ?? currency;

  Kes operator +(Kes other) => Kes(cents + other.cents);
  Kes operator -(Kes other) => Kes(cents - other.cents);
  Kes operator -() => Kes(-cents);
  bool get isNegative => cents < 0;

  @override
  int compareTo(Kes other) => cents.compareTo(other.cents);

  @override
  bool operator ==(Object other) => other is Kes && other.cents == cents;

  @override
  int get hashCode => cents.hashCode;

  /// "KES 1,284,500" or "KES 1,284,500.50", "UGX 50,000"; negative as "−KES 200".
  String format() {
    final abs = cents.abs();
    final whole = abs ~/ 100;
    final part = abs % 100;
    final digits = whole.toString();
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }
    final fraction = part == 0 || _noCents.contains(currency)
        ? '' : '.${part.toString().padLeft(2, '0')}';
    return '${cents < 0 ? '−' : ''}$currency $grouped$fraction';
  }

  @override
  String toString() => format();
}
