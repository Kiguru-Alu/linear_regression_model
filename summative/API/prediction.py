import json
from pathlib import Path
from typing import Literal

import joblib
import pandas as pd
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, ConfigDict, Field

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


class Prediction(BaseModel):
    predicted_yield_kg_ha: float
    risk_band: Literal["high", "medium", "low"]


def load_model(path=MODEL_PATH):
    return joblib.load(path)


# Same as predict_yield in the notebook, but the model is passed in so it is loaded once, at startup.
def predict_yield(row, model):
    return float(model.predict(row[retrain.FEATURES])[0])


def risk_band(predicted_yield, bands):
    if predicted_yield < bands["high_risk_below"]:
        return "high"
    if predicted_yield < bands["low_risk_from"]:
        return "medium"
    return "low"


state = {
    "model": load_model(),
    "risk_bands": json.loads(RISK_BANDS_PATH.read_text()),
}

app = FastAPI(
    title="Kenya Maize Farm Risk API",
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


@app.post("/predict", response_model=Prediction)
def predict(farm: FarmInput):
    row = pd.DataFrame([farm.model_dump()])
    predicted = predict_yield(row, state["model"])
    return Prediction(predicted_yield_kg_ha=round(predicted, 1), risk_band=risk_band(predicted, state["risk_bands"]))
