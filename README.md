# Hectare Africa: Kenya maize farm risk score

## About me

Brian Mahui.
My personal mission is to build Africa's capacity to make things, by starting and running technology companies on the continent.

## Model mission and problem

Most smallholder maize farmers in Kenya farm uninsured, so one bad season can wipe them out and keep them locked out of credit.
My mission is to make them insurable by helping agricultural insurers judge each farm's risk at enrolment.
The app predicts a field's expected maize yield from its location, soil and planned inputs, and turns it into a low, medium or high risk band.

## Dataset

Field-level maize yield and management data from 7,258 smallholder fields in western Kenya (2016 to 2020), part of a 14,773-field survey run by One Acre Fund across Sub-Saharan Africa.
Yields were measured at harvest in two randomly placed 36 m² boxes per field, and each record also holds fertilizer rates, seed type, planting date, soil properties, elevation and growing-season climate.
The target is maize yield in kg/ha.

Source: Aramburu Merlos, F., Tenorio, F. A., Mashingaidze, N., Sananka, A., Aston, S., & Grassini, P. (2024). *Maize management and yield of smallholder farmers in Sub-Saharan Africa between 2016 and 2022* (Version 2) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.11122388 (CC BY 4.0)

## API

Swagger UI: https://kenya-maize-risk-api.onrender.com/docs

The service runs on Render's free plan, so after 15 minutes without traffic it sleeps and can take up to a minute to wake up on the first request.

| Route | Method | What it does |
|---|---|---|
| `/predict` | POST | Takes a field's 11 inputs and returns its expected maize yield (kg/ha) and a high, medium or low risk band. Wrong types, missing values and out-of-range values return a validation error. |
| `/retrain` | POST | Takes a CSV with the same columns as `summative/API/train_data.csv`, refits the model on the original data plus the new rows, and starts using it straight away. The retrained model is kept in memory, so when the service restarts (after sleeping or on a redeploy) it goes back to the saved model. `summative/API/new_data_uganda_2020.csv` is a sample file to try it with. |
| `/docs` | GET | Swagger UI. |

To run it locally (needs [uv](https://docs.astral.sh/uv/)):

```sh
cd summative/API
uv sync
uv run uvicorn prediction:app --reload
```

Then open http://127.0.0.1:8000/docs.

## Video demo

YouTube: to be added after recording.

## How to run the mobile app

The app, Hectare Africa, is a one-page Flutter app in `summative/FlutterApp`. It sends a field's 11 inputs to the live API's `/predict` route and shows the expected maize yield and risk band, or a readable error in the same place.

1. Install [Flutter](https://docs.flutter.dev/get-started/install) 3.47 or newer, and check it with `flutter doctor`.
2. Connect an Android phone with USB debugging turned on, or start an Android or iOS emulator. Check that `flutter devices` lists it.
3. Run the app:

   ```sh
   cd summative/FlutterApp
   flutter pub get
   flutter run
   ```

4. Tap **Fill in an example field**, then **Predict**. The first request can take up to a minute while the free Render service wakes up.

To run the app's tests: `flutter test` in the same folder.
