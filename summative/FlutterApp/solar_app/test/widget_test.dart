import 'package:flutter_test/flutter_test.dart';

import 'package:solar_app/main.dart';

void main() {
  testWidgets('renders prediction form and action button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SolarPredictorApp());

    expect(
      find.text('Predict solar AC power with a clean one-screen experience.'),
      findsOneWidget,
    );
    expect(find.text('Predict'), findsOneWidget);
    expect(find.text('DC_POWER'), findsOneWidget);
    expect(find.text('DAILY_YIELD'), findsOneWidget);
    expect(find.text('TOTAL_YIELD'), findsOneWidget);
  });
}
