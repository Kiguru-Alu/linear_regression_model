# Kenya Maize Farm Risk Score

## Mission and problem

My mission is to build Africa's capacity to make things, by starting and running technology companies on the continent.
This project builds one piece of that: digital infrastructure for farm insurance, because most smallholder maize farmers in Kenya farm uninsured, and one bad season can wipe them out and lock them out of credit.
It helps agricultural insurers judge each farm's risk at enrolment, so these farmers become insurable.
The app predicts a field's expected maize yield from its location, soil and planned inputs, and turns it into a low, medium or high risk band.

## Dataset

Field-level maize yield and management data from 7,258 smallholder fields in western Kenya (2016 to 2020), part of a 14,773-field survey run by One Acre Fund across Sub-Saharan Africa.
Yields were measured at harvest in two randomly placed 36 m² boxes per field, and each record also holds fertilizer rates, seed type, planting date, soil properties, elevation and growing-season climate.
The target is maize yield in kg/ha.

Source: Aramburu Merlos, F., Tenorio, F. A., Mashingaidze, N., Sananka, A., Aston, S., & Grassini, P. (2024). *Maize management and yield of smallholder farmers in Sub-Saharan Africa between 2016 and 2022* (Version 2) [Dataset]. Zenodo. https://doi.org/10.5281/zenodo.11122388 (CC BY 4.0)

## API

Swagger UI: to be added after deployment.

| Route | Method | What it does |
|---|---|---|
| `/predict` | POST | Takes a field's 11 inputs and returns its expected maize yield (kg/ha) and a high, medium or low risk band. Wrong types, missing values and out-of-range values return a validation error. |
| `/retrain` | POST | Takes a CSV with the same columns as `summative/API/train_data.csv`, refits the model on the original data plus the new rows, and starts using it straight away. `summative/API/new_data_uganda_2020.csv` is a sample file to try it with. |
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

To be added with the Flutter app.
