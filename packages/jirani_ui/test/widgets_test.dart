import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jirani_domain/jirani_domain.dart';
import 'package:jirani_ui/jirani_ui.dart';

Widget _host(Widget child) => MaterialApp(
      theme: JiraniTheme.light(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  testWidgets('PrimaryButton ignores taps while busy', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(PrimaryButton(label: 'Go', busy: true, onPressed: () => taps++)));
    await tester.tap(find.byType(FilledButton));
    expect(taps, 0);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('DigitsField keeps only digits up to its length', (tester) async {
    final c = TextEditingController();
    await tester.pumpWidget(_host(DigitsField(controller: c, label: 'Code')));
    await tester.enterText(find.byType(TextField), '12a34567');
    expect(c.text, '123456');
  });

  testWidgets('MoneyText reads out shillings', (tester) async {
    await tester.pumpWidget(_host(const MoneyText(Kes(100000))));
    expect(find.text('KES 1,000'), findsOneWidget);
    expect(find.bySemanticsLabel('Kenya shillings 1,000'), findsOneWidget);
  });

  testWidgets('both themes build', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: JiraniTheme.light(), darkTheme: JiraniTheme.dark(),
        home: const Scaffold(body: Notice('Hello', tone: NoticeTone.critical))));
    expect(find.text('Hello'), findsOneWidget);
  });
}
