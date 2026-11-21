# Hectare Africa

A one-page Flutter app for the Kenya maize farm risk score. An insurance agent enters a field's 11 inputs. The app sends them to the live API's `/predict` route and shows the expected maize yield (kg/ha) and a high, medium or low risk band. A missing, wrong-type or out-of-range value gets a readable message in the same result card.

## Run it

Needs Flutter 3.47 or newer, and an Android phone or emulator (or an iOS one).

```sh
flutter pub get
flutter run
```

The API address is set in `lib/risk_api.dart`.

## Code

- `lib/farm_fields.dart`: the 11 inputs, their labels and allowed ranges, and the validation messages
- `lib/risk_api.dart`: calls `/predict` and turns failures into readable messages
- `lib/prediction_page.dart`: the page, with the form, the Predict button and the result card
- `lib/widgets/result_card.dart`: the result card and its yield meter
- `lib/widgets/field_horizon.dart`: the painted hills behind the card
- `lib/theme.dart`: colours, the Geist font and input styles
- `test/widget_test.dart`: tests for the fields, error messages and predictions

The Geist font is included under the SIL Open Font License (`assets/fonts/OFL.txt`).
