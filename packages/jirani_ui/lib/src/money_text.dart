import 'package:flutter/material.dart';
import 'package:jirani_domain/jirani_domain.dart';

/// Shows an amount the same way everywhere, in the open chama's currency:
/// "KES 1,284,500", "UGX 50,000". Read out in words ("Uganda shillings").
class MoneyText extends StatelessWidget {
  const MoneyText(this.amount, {super.key, this.style});

  final Kes amount;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final base = style ?? Theme.of(context).textTheme.bodyLarge;
    return Text(
      amount.format(),
      style: base?.copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      semanticsLabel: amount.format().replaceAll(Kes.currency, Kes.currencyName),
    );
  }
}
