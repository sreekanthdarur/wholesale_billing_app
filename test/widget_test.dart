import 'package:flutter_test/flutter_test.dart';
import 'package:wholesale_billing_app/app/app.dart';

void main() {
  testWidgets('app renders home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const WholesaleBillingApp());
    expect(find.text('Wholesale Billing App'), findsOneWidget);
  });
}
