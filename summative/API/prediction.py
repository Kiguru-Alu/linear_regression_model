import ctypes
import gc
import json
import threading
from io import BytesIO
from pathlib import Path
from typing import Literal

import joblib
import pandas as pd
from fastapi import FastAPI, File, HTTPException, UploadFile
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import RedirectResponse
from pydantic import BaseModel, ConfigDict, Field, ValidationError

import retrain

API_DIR = Path(__file__).resolve().parent
MODEL_PATH = API_DIR / "best_model.pkl"
RISK_BANDS_PATH = API_DIR / "risk_bands.json"

SeedType = Literal["local_or_opv", "hybrid_early", "hybrid_medium", "hybrid_late", "hybrid_unknown_maturity"]


class FarmInput(BaseModel):
    model_config = ConfigDict(
        strict=True,
        extra="forbid",
        json_schema_extra={
            "examples": [{
                "elev": 1339, "avg_season_ai": 0.92, "soil_rzpawhc": 120, "soil_clay": 32, "soil_pH": 6.2,
                "soil_orgC": 11.2, "soil_ECEC": 12.5, "N_kg_ha": 22.2, "plant_date_dev": -16,
                "fert_in_hole": 1, "seed_type": "hybrid_late",
            }]
        },
    )

    elev: float = Field(ge=800, le=3000, description="Field elevation in metres above sea level")
    avg_season_ai: float = Field(ge=0.5, le=2.0, description="Aridity index (long-term rain over evaporation)")
    soil_rzpawhc: float = Field(ge=0, le=200, description="Root-zone plant-available water capacity in mm")
    soil_clay: float = Field(ge=10, le=70, description="Clay content of the topsoil in %")
    soil_pH: float = Field(ge=4.0, le=8.5, description="Topsoil pH")
    soil_orgC: float = Field(ge=0, le=60, description="Topsoil organic carbon in g/kg")
    soil_ECEC: float = Field(ge=0, le=40, description="Topsoil effective cation exchange capacity in cmol/kg")
    N_kg_ha: float = Field(ge=0, le=350, description="Planned nitrogen fertilizer in kg per hectare")
    plant_date_dev: int = Field(ge=-120, le=120, description="Planned planting date, in days before (-) or after (+) the local average")
    fert_in_hole: int = Field(ge=0, le=1, description="Fertilizer placed in the planting hole: 1 = yes, 0 = no")
    seed_type: SeedType = Field(description="Seed planted")


class FarmRecord(FarmInput):
    yield_kg_ha: float = Field(ge=0, le=15000, description="Measured maize yield in kg per hectare")


class Prediction(BaseModel):
    predicted_yield_kg_ha: float
    risk_band: Literal["high", "medium", "low"]


class RetrainResult(BaseModel):
    retrained: bool
    rows_received: int
    rows_already_in_training_data: int
    rows_added: int
    training_rows: int
    test_mse_before: float
    test_mse_after: float
    risk_bands: dict[str, float]


def load_model(path=MODEL_PATH):
    return joblib.load(path)


# Same as predict_yield in the notebook, but the model is passed in so it is loaded once, at startup.
def predict_yield(row, model):
    return float(model.predict(row[retrain.FEATURES])[0])


def release_memory():
    gc.collect()
    # On Linux (Render), hand freed memory back to the system, so repeated retrains stay inside the free plan's 512 MB
    try:
        ctypes.CDLL("libc.so.6").malloc_trim(0)
    except OSError:
        pass


def risk_band(predicted_yield, bands):
    if predicted_yield < bands["high_risk_below"]:
        return "high"
    if predicted_yield < bands["low_risk_from"]:
        return "medium"
    return "low"


state = {
    "model": load_model(),
    "risk_bands": json.loads(RISK_BANDS_PATH.read_text()),
    "train_data": retrain.load_data(retrain.TRAIN_PATH),
    "test_data": retrain.load_data(retrain.TEST_PATH),
}
retrain_lock = threading.Lock()

app = FastAPI(
    title="Hectare Africa API",
    description="Predicts a Kenyan smallholder maize field's yield (kg/ha) from what an insurer knows at enrolment, "
                "and turns it into a high, medium or low risk band.",
    version="1.0.0",
)

# CORS only controls which websites may call this API from a browser. The Flutter app on a phone is not a
# browser, so CORS does not affect it.
# Allowed: our own Render site, and the Flutter web debug server on http://localhost:8080.
# Restricted: every other website; any method except GET and POST, the only ones the API uses; any header
# except Content-Type and Accept; and credentials (cookies and auth headers), because the API has no login
# and should never receive them.
app.add_middleware(
    CORSMiddleware,
    allow_origins=["https://kenya-maize-risk-api.onrender.com", "http://localhost:8080"],
    allow_methods=["GET", "POST"],
    allow_headers=["Content-Type", "Accept"],
    allow_credentials=False,
)


# The bare service URL has no page of its own, so send visitors to Swagger UI
@app.get("/", include_in_schema=False)
def home():
    return RedirectResponse(url="/docs")


@app.post("/predict", response_model=Prediction)
def predict(farm: FarmInput):
    row = pd.DataFrame([farm.model_dump()])
    predicted = predict_yield(row, state["model"])
    return Prediction(predicted_yield_kg_ha=round(predicted, 1), risk_band=risk_band(predicted, state["risk_bands"]))


def read_new_data(content):
    try:
        data = pd.read_csv(BytesIO(content))
    except Exception as error:
        raise HTTPException(status_code=422, detail="The file could not be read as a CSV.") from error

    expected = retrain.FEATURES + [retrain.TARGET]
    missing = [column for column in expected if column not in data.columns]
    unexpected = [column for column in data.columns if column not in expected]
    if missing or unexpected:
        raise HTTPException(status_code=422, detail={
            "message": "The CSV must have exactly the training data's columns.",
            "missing_columns": missing, "unexpected_columns": unexpected, "expected_columns": expected,
        })
    if data.empty:
        raise HTTPException(status_code=422, detail="The CSV has no data rows.")

    problems = []
    # CSV line numbers: line 1 is the header
    for line, record in enumerate(data[expected].to_dict("records"), start=2):
        blanks = [column for column, value in record.items() if pd.isna(value)]
        if blanks:
            problems.append({"line": line, "error": f"Missing values in: {', '.join(blanks)}"})
            continue
        try:
            FarmRecord.model_validate(record, strict=False)
        except ValidationError as error:
            problems.append({"line": line, "error": "; ".join(
                f"{issue['loc'][0]}: {issue['msg']}" for issue in error.errors())})
    if problems:
        raise HTTPException(status_code=422, detail={
            "message": f"{len(problems)} row(s) failed validation. Nothing was retrained.",
            "rows": problems[:10],
        })
    return data[expected]


@app.post("/retrain", response_model=RetrainResult)
def retrain_model(file: UploadFile = File(description="CSV with the same columns as the training data")):
    uploaded = read_new_data(file.file.read())

    with retrain_lock:
        new_rows = retrain.drop_known_rows(uploaded, state["train_data"])
        if new_rows.empty:
            mse_now = round(retrain.test_mse(state["model"], state["test_data"]), 1)
            return RetrainResult(
                retrained=False, rows_received=len(uploaded), rows_already_in_training_data=len(uploaded),
                rows_added=0, training_rows=len(state["train_data"]), test_mse_before=mse_now,
                test_mse_after=mse_now, risk_bands=state["risk_bands"],
            )

        result = retrain.retrain(state["model"], state["train_data"], new_rows, state["test_data"])
        state["model"] = result["model"]
        state["train_data"] = result["train_data"]
        if result["risk_bands"] is not None:
            state["risk_bands"] = result["risk_bands"]
        mse_before, mse_after = result["test_mse_before"], result["test_mse_after"]
        del result
        release_memory()

    return RetrainResult(
        retrained=True,
        rows_received=len(uploaded),
        rows_already_in_training_data=len(uploaded) - len(new_rows),
        rows_added=len(new_rows),
        training_rows=len(state["train_data"]),
        test_mse_before=round(mse_before, 1),
        test_mse_after=round(mse_after, 1),
        risk_bands=state["risk_bands"],
    )
