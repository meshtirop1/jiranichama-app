/// An amount in Kenya shillings, held as integer cents. Never a double.
class Kes implements Comparable<Kes> {
  const Kes(this.cents);
  const Kes.shillings(int shillings) : cents = shillings * 100;

  final int cents;

  static const zero = Kes(0);

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

  /// "KES 1,284,500" or "KES 1,284,500.50"; negative as "−KES 200".
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
    final fraction = part == 0 ? '' : '.${part.toString().padLeft(2, '0')}';
    return '${cents < 0 ? '−' : ''}KES $grouped$fraction';
  }

  @override
  String toString() => format();
}
