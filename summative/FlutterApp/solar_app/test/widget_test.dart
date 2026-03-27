import 'package:flutter_test/flutter_test.dart';

import 'package:solar_app/main.dart';

void main() {
  test('normalizes a Swagger docs URL into the predict endpoint', () {
    expect(
      resolvePredictApiUri(
        'https://linearregressionmodel-production-31a6.up.railway.app/docs#/default/predict_predict_post',
      ).toString(),
      defaultPredictApiUrl,
    );
  });

  testWidgets('renders prediction form and action button', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const SolarPredictorApp());

    expect(find.text('Solar AC Power Prediction'), findsOneWidget);
    expect(find.text('Predict'), findsOneWidget);
    expect(find.text('DC_POWER'), findsOneWidget);
    expect(find.text('DAILY_YIELD'), findsOneWidget);
    expect(find.text('TOTAL_YIELD'), findsOneWidget);
  });
}
