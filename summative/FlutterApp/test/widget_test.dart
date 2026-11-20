import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:flutter/material.dart';
import 'package:hectare_africa/farm_fields.dart';
import 'package:hectare_africa/main.dart';
import 'package:hectare_africa/risk_api.dart';

Finder inResultCard(String text) =>
    find.descendant(of: find.byKey(const Key('result-card')), matching: find.textContaining(text));

Future<void> pumpApp(WidgetTester tester, http.Client client) async {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(HectareAfricaApp(api: RiskApi(client: client)));
}

Future<void> tapPredict(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('predict-button')));
  await tester.pumpAndSettle();
}

Future<void> fillExample(WidgetTester tester) async {
  await tester.tap(find.text('Fill in an example field'));
  await tester.pump();
}

void main() {
  final unused = MockClient((_) async => http.Response('{}', 500));

  testWidgets('has one labelled text field per model input and a Predict button', (tester) async {
    await pumpApp(tester, unused);

    expect(allFields, hasLength(11));
    expect(find.byType(TextField), findsNWidgets(11));
    for (final field in allFields) {
      expect(find.text(field.label), findsOneWidget);
    }
    expect(find.text('Predict'), findsOneWidget);
  });

  testWidgets('missing values are reported in the result card', (tester) async {
    await pumpApp(tester, unused);
    await tapPredict(tester);

    expect(inResultCard('Check 11 fields'), findsOneWidget);
    expect(inResultCard('Elevation (m) is missing.'), findsOneWidget);
  });

  testWidgets('wrong types and out-of-range values are reported in the result card', (tester) async {
    await pumpApp(tester, unused);
    await fillExample(tester);
    await tester.enterText(find.byKey(const Key('field-elev')), 'high');
    await tester.enterText(find.byKey(const Key('field-N_kg_ha')), '500');
    await tester.enterText(find.byKey(const Key('field-plant_date_dev')), '2.5');
    await tapPredict(tester);

    expect(inResultCard('Check 3 fields'), findsOneWidget);
    expect(inResultCard('Elevation (m) must be a number.'), findsOneWidget);
    expect(inResultCard('Nitrogen (kg/ha) must be between 0 and 350.'), findsOneWidget);
    expect(inResultCard('Planting date vs usual (days) must be a whole number.'), findsOneWidget);
  });

  testWidgets('scrolls back to the result card so the error is visible', (tester) async {
    await pumpApp(tester, unused);
    await fillExample(tester);
    await tester.enterText(find.byKey(const Key('field-seed_type')), '');
    await tester.ensureVisible(find.byKey(const Key('field-seed_type')));
    await tester.pumpAndSettle();
    await tapPredict(tester);

    final card = tester.getRect(find.byKey(const Key('result-card')));
    expect(card.top, greaterThanOrEqualTo(0));
    expect(inResultCard('Seed type is missing.'), findsOneWidget);
  });

  testWidgets('sends the inputs to /predict and shows the yield and risk band', (tester) async {
    late Map<String, dynamic> sent;
    final client = MockClient((request) async {
      expect(request.url.path, '/predict');
      sent = jsonDecode(request.body) as Map<String, dynamic>;
      return http.Response(jsonEncode({'predicted_yield_kg_ha': 2349.7, 'risk_band': 'high'}), 200);
    });
    await pumpApp(tester, client);
    await fillExample(tester);
    await tapPredict(tester);

    expect(sent['elev'], 1339.0);
    expect(sent['plant_date_dev'], -16);
    expect(sent['seed_type'], 'hybrid_late');
    expect(inResultCard('2,349'), findsOneWidget);
    expect(inResultCard('High risk'), findsOneWidget);
  });

  testWidgets("shows the API's own validation errors in the result card", (tester) async {
    final client = MockClient(
      (_) async => http.Response(
        jsonEncode({
          'detail': [
            {
              'loc': ['body', 'elev'],
              'msg': 'Input should be less than or equal to 3000',
            },
          ],
        }),
        422,
      ),
    );
    await pumpApp(tester, client);
    await fillExample(tester);
    await tapPredict(tester);

    expect(inResultCard("Couldn't get a prediction"), findsOneWidget);
    expect(inResultCard('Elevation (m): Input should be less than or equal to 3000.'), findsOneWidget);
  });

  test('field rules match the API ranges', () {
    final elevation = allFields.firstWhere((field) => field.key == 'elev');
    expect(elevation.validate(''), 'Elevation (m) is missing.');
    expect(elevation.validate('799'), 'Elevation (m) must be between 800 and 3,000.');
    expect(elevation.validate('1339'), isNull);

    final fertilizer = allFields.firstWhere((field) => field.key == 'fert_in_hole');
    expect(fertilizer.validate('2'), 'Fertilizer in planting hole must be 1 (yes) or 0 (no).');

    final seed = allFields.firstWhere((field) => field.key == 'seed_type');
    expect(seed.validate('hybrid_late'), isNull);
    expect(seed.validate('magic'), startsWith('Seed type must be one of:'));
  });
}
